import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/providers/meeting_provider.dart';
import 'package:rdr/repositories/report_storage_repository.dart';
import 'package:rdr/repositories/wol_repository.dart';
import 'package:rdr/services/meeting_timer_service.dart';
import 'package:rdr/services/report_builder.dart';
import 'package:rdr/services/schedule_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caminho do documento da apostila na fixture da página da semana.
const String documentPath = '/pt/wol/d/r5/lp-t/202026244';

/// HTML real capturado do wol.jw.org, servido em bytes para o repositório
/// decodificar como UTF-8 igual faria com a resposta verdadeira.
Uint8List loadFixtureBytes(String name) =>
    File('test/fixtures/$name').readAsBytesSync();

/// Cliente que responde as duas páginas da semana 2026/31 a partir das
/// fixtures. Nenhum teste toca a rede: qualquer outra URL vira 404.
MockClient clienteDasFixtures({List<Uri>? registro}) {
  final weekPage = loadFixtureBytes('meetings_week_2026_31.html');
  final document = loadFixtureBytes('mwb_2026_31.html');
  return MockClient((request) async {
    registro?.add(request.url);
    switch (request.url.path) {
      case WolRepository.currentWeekPath:
        return http.Response.bytes(weekPage, 200);
      case documentPath:
        return http.Response.bytes(document, 200);
      default:
        return http.Response('não encontrado', 404);
    }
  });
}

/// O caminho inteiro que o app percorre ao baixar a programação: HTTP →
/// parser da página da semana → HTTP do documento → parser do documento →
/// montagem do relatório.
Future<MeetingReport> baixarEMontarRelatorio(WolRepository repository) async {
  const parser = ScheduleParser();
  final semana = parser.parseWeekPage(await repository.fetchCurrentWeekPage());
  final secoes = parser.parseDocument(
    await repository.fetchDocument(semana.documentPath),
  );
  return const ReportBuilder().build(
    weekLabel: semana.weekLabel,
    sections: secoes,
  );
}

/// Relógio sob controle do teste: nenhum service enxerga o `DateTime.now()`
/// real, então a reunião inteira acontece em tempo simulado.
class RelogioFalso {
  RelogioFalso(this.agora);

  DateTime agora;

  /// O [Clock] injetado no service.
  DateTime ler() => agora;

  void avancar(Duration passo) => agora = agora.add(passo);
}

/// Instante em que a reunião simulada começa: uma quinta-feira à noite.
final DateTime inicioDaReuniao = DateTime(2026, 7, 30, 19, 30);

/// Uma duração distinta para cada posição da ordem canônica, para que trocar
/// dois itens de lugar quebre a asserção.
Duration duracaoDoItem(int indice) => Duration(seconds: 23 + indice * 7);

/// Quanto tempo cada item deve acumular numa reunião cronometrada do começo
/// ao fim, por id.
Map<String, Duration> duracoesPorId(MeetingReport report) {
  final itens = report.orderedItems;
  return {for (var i = 0; i < itens.length; i++) itens[i].id: duracaoDoItem(i)};
}

/// Tempo acumulado por item, por id — o que o relatório impresso mostraria.
Map<String, Duration> tempoPorId(MeetingReport report) => {
  for (final item in report.orderedItems) item.id: item.elapsed,
};

/// Roda a reunião inteira: arranca no primeiro item e dá um Próximo por item,
/// avançando o relógio falso enquanto cada um corre.
MeetingReport cronometrarReuniaoInteira(
  MeetingTimerService timer,
  RelogioFalso relogio,
  MeetingReport inicial,
) {
  final duracoes = duracoesPorId(inicial);
  var report = timer.start(timer.startMeeting(inicial));
  for (final item in inicial.orderedItems) {
    relogio.avancar(duracoes[item.id]!);
    report = timer.next(report);
  }
  return report;
}

void main() {
  // O `shared_preferences` da persistência precisa do binding de teste.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MeetingReport relatorioDaSemana;

  setUpAll(() async {
    relatorioDaSemana = await baixarEMontarRelatorio(
      WolRepository(client: clienteDasFixtures()),
    );
  });

  group('Fluxo completo — das fixtures ao relatório montado', () {
    test('monta os itens na ordem canônica da semana 2026/31', () {
      expect(
        relatorioDaSemana.orderedItems.map((item) => item.label).toList(),
        [
          'Comentários iniciais',
          '1. Ele pregou com coragem',
          'Presidente',
          '2. Joias espirituais',
          'Presidente',
          '3. Leitura da Bíblia',
          'Conselho',
          'Transição',
          '4. Iniciando conversas',
          'Conselho',
          'Transição',
          '5. Cultivando o interesse',
          'Conselho',
          'Transição',
          '6. Explicando suas crenças',
          'Conselho',
          'Transição',
          'Presidente',
          '7. Seja adaptável — mostre interesse pessoal',
          'Presidente',
          '8. Estudo bíblico de congregação',
          'Comentários finais',
        ],
      );
    });

    test('aplica a regra de sub-itens de cada seção às partes reais', () {
      // Tesouros: Presidente em cada parte, exceto a Leitura da Bíblia, que
      // troca o Presidente por Conselho + Transição.
      expect(descreverItens(relatorioDaSemana.sections[0]), [
        ('1. Ele pregou com coragem', parte),
        ('Presidente', subItem),
        ('2. Joias espirituais', parte),
        ('Presidente', subItem),
        ('3. Leitura da Bíblia', parte),
        ('Conselho', subItem),
        ('Transição', subItem),
      ]);
      // Faça Seu Melhor: Conselho + Transição em toda parte.
      expect(descreverItens(relatorioDaSemana.sections[1]), [
        ('4. Iniciando conversas', parte),
        ('Conselho', subItem),
        ('Transição', subItem),
        ('5. Cultivando o interesse', parte),
        ('Conselho', subItem),
        ('Transição', subItem),
        ('6. Explicando suas crenças', parte),
        ('Conselho', subItem),
        ('Transição', subItem),
      ]);
      // Nossa Vida Cristã: abre com o Presidente avulso (que não é sub-item) e
      // a última parte fica sem nenhum sub-item.
      expect(descreverItens(relatorioDaSemana.sections[2]), [
        ('Presidente', parte),
        ('7. Seja adaptável — mostre interesse pessoal', parte),
        ('Presidente', subItem),
        ('8. Estudo bíblico de congregação', parte),
      ]);
    });

    test('as três seções vêm com o tipo e o título do wol', () {
      expect(
        relatorioDaSemana.sections.map((section) => section.kind).toList(),
        [
          SectionKind.treasures,
          SectionKind.ministry,
          SectionKind.christianLife,
        ],
      );
      expect(
        relatorioDaSemana.sections.map((section) => section.title).toList(),
        [
          'TESOUROS DA PALAVRA DE DEUS',
          'FAÇA SEU MELHOR NO MINISTÉRIO',
          'NOSSA VIDA CRISTÃ',
        ],
      );
    });

    test(
      'herda o rótulo da semana e nasce zerado, pronto para cronometrar',
      () {
        expect(relatorioDaSemana.weekLabel, '27 de julho–2 de agosto');
        expect(relatorioDaSemana.startedAt, isNull);
        expect(relatorioDaSemana.endedAt, isNull);
        expect(relatorioDaSemana.runningItemId, isNull);
        expect(relatorioDaSemana.selectedItemId, isNull);
        expect(
          relatorioDaSemana.orderedItems.map((item) => item.elapsed).toSet(),
          {Duration.zero},
        );
        expect(
          relatorioDaSemana.orderedItems.every(
            (item) => item.runningSince == null,
          ),
          isTrue,
        );
        expect(
          relatorioDaSemana.orderedItems.map((item) => item.id).toSet(),
          hasLength(relatorioDaSemana.orderedItems.length),
        );
      },
    );

    test(
      'busca só a página da semana e a apostila, nunca A Sentinela',
      () async {
        final requisitadas = <Uri>[];
        final repository = WolRepository(
          client: clienteDasFixtures(registro: requisitadas),
        );

        await baixarEMontarRelatorio(repository);

        expect(requisitadas.map((url) => url.toString()).toList(), [
          'https://wol.jw.org${WolRepository.currentWeekPath}',
          'https://wol.jw.org$documentPath',
        ]);
      },
    );
  });

  group('Fluxo completo — cronometrando a reunião inteira', () {
    late RelogioFalso relogio;
    late MeetingTimerService timer;

    setUp(() {
      relogio = RelogioFalso(inicioDaReuniao);
      timer = MeetingTimerService(clock: relogio.ler);
    });

    test('cada item fica com exatamente o tempo que correu no relógio', () {
      final report = cronometrarReuniaoInteira(
        timer,
        relogio,
        relatorioDaSemana,
      );

      expect(tempoPorId(report), duracoesPorId(relatorioDaSemana));
    });

    test('a soma dos itens bate com o tempo total decorrido da reunião', () {
      final report = cronometrarReuniaoInteira(
        timer,
        relogio,
        relatorioDaSemana,
      );

      final somaDosItens = report.orderedItems.fold(
        Duration.zero,
        (total, item) => total + item.elapsed,
      );
      expect(somaDosItens, relogio.agora.difference(report.startedAt!));
    });

    test('o Próximo no último item para o cronômetro sem estourar a lista', () {
      final report = cronometrarReuniaoInteira(
        timer,
        relogio,
        relatorioDaSemana,
      );

      expect(report.runningItemId, isNull);
      expect(
        report.orderedItems.every((item) => item.runningSince == null),
        isTrue,
      );
      expect(
        report.orderedItems,
        hasLength(relatorioDaSemana.orderedItems.length),
      );
      expect(report.selectedItemId, relatorioDaSemana.orderedItems.last.id);
    });
  });

  group('Fluxo completo — setas no meio da reunião', () {
    late RelogioFalso relogio;
    late MeetingTimerService timer;

    /// A reunião parada na terceira parte de Tesouros, que corre há 20s.
    MeetingReport reuniaoNaLeituraDaBiblia() {
      var report = timer.start(timer.startMeeting(relatorioDaSemana));
      for (var i = 0; i < 5; i++) {
        relogio.avancar(const Duration(minutes: 1));
        report = timer.next(report);
      }
      relogio.avancar(const Duration(seconds: 20));
      return report;
    }

    setUp(() {
      relogio = RelogioFalso(inicioDaReuniao);
      timer = MeetingTimerService(clock: relogio.ler);
    });

    test('mudam a seleção sem tocar no item que está correndo', () {
      final antes = reuniaoNaLeituraDaBiblia();
      final correndo = antes.itemById(antes.runningItemId!)!;

      final depois = timer.selectNext(timer.selectNext(antes));

      expect(depois.runningItemId, antes.runningItemId);
      expect(depois.itemById(correndo.id)!.runningSince, correndo.runningSince);
      expect(depois.itemById(correndo.id)!.elapsed, correndo.elapsed);
      expect(depois.selectedItemId, isNot(antes.selectedItemId));
      expect(
        depois.selectedItemId,
        depois.orderedItems[depois.orderedItems.indexOf(correndo) + 2].id,
      );
    });

    test('a seta para cima também não interrompe a contagem', () {
      final antes = reuniaoNaLeituraDaBiblia();
      final correndo = antes.itemById(antes.runningItemId!)!;

      final depois = timer.selectPrevious(antes);

      expect(depois.runningItemId, correndo.id);
      expect(depois.itemById(correndo.id)!.runningSince, correndo.runningSince);
      expect(
        depois.orderedItems.indexWhere(
          (item) => item.id == depois.selectedItemId,
        ),
        depois.orderedItems.indexOf(correndo) - 1,
      );
    });

    test('o item corrente segue acumulando por cima do uso das setas', () {
      var report = reuniaoNaLeituraDaBiblia();
      final correndoId = report.runningItemId!;

      report = timer.selectNext(timer.selectPrevious(timer.selectNext(report)));
      relogio.avancar(const Duration(seconds: 40));
      report = timer.pause(report);

      // Os 20s antes das setas mais os 40s depois: nenhum trecho se perdeu nem
      // foi contado duas vezes.
      expect(report.itemById(correndoId)!.elapsed, const Duration(minutes: 1));
    });
  });

  group('Fluxo completo — encerrando a reunião', () {
    late RelogioFalso relogio;
    late MeetingTimerService timer;

    setUp(() {
      relogio = RelogioFalso(inicioDaReuniao);
      timer = MeetingTimerService(clock: relogio.ler);
    });

    test('startedAt e endedAt são os instantes do relógio falso', () {
      var report = timer.start(timer.startMeeting(relatorioDaSemana));
      for (var i = 0; i < 4; i++) {
        relogio.avancar(const Duration(minutes: 3));
        report = timer.next(report);
      }
      relogio.avancar(const Duration(minutes: 2, seconds: 30));

      report = timer.endMeeting(report);

      expect(report.startedAt, inicioDaReuniao);
      expect(report.endedAt, DateTime(2026, 7, 30, 19, 44, 30));
      expect(
        report.endedAt!.difference(report.startedAt!),
        const Duration(minutes: 14, seconds: 30),
      );
    });

    test('nenhum item continua correndo depois de encerrar', () {
      var report = timer.start(timer.startMeeting(relatorioDaSemana));
      relogio.avancar(const Duration(minutes: 5));
      report = timer.next(report);
      relogio.avancar(const Duration(minutes: 5));

      report = timer.endMeeting(report);

      expect(report.runningItemId, isNull);
      expect(
        report.orderedItems.where((item) => item.runningSince != null),
        isEmpty,
      );
      // O trecho aberto no encerramento não se perde: entra no acumulado.
      expect(report.orderedItems[1].elapsed, const Duration(minutes: 5));
    });
  });

  group('Fluxo completo — salvar e restaurar no meio da reunião', () {
    late RelogioFalso relogio;
    late MeetingTimerService timer;
    late ReportStorageRepository storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      relogio = RelogioFalso(inicioDaReuniao);
      timer = MeetingTimerService(clock: relogio.ler);
      storage = ReportStorageRepository();
    });

    /// A reunião na segunda parte, correndo há 20s, com a primeira já fechada.
    MeetingReport reuniaoEmAndamento() {
      var report = timer.start(timer.startMeeting(relatorioDaSemana));
      relogio.avancar(const Duration(minutes: 1));
      report = timer.next(report);
      relogio.avancar(const Duration(seconds: 20));
      return report;
    }

    test('recarregar devolve um relatório equivalente ao salvo', () async {
      final original = reuniaoEmAndamento();

      await storage.save(original);
      final restaurado = await storage.load();

      expect(restaurado, equals(original));
    });

    test('o item que corria volta correndo, do mesmo instante', () async {
      final original = reuniaoEmAndamento();
      await storage.save(original);

      final restaurado = (await storage.load())!;

      final correndo = restaurado.itemById(original.runningItemId!)!;
      expect(restaurado.runningItemId, original.runningItemId);
      expect(restaurado.selectedItemId, original.selectedItemId);
      expect(restaurado.startedAt, inicioDaReuniao);
      expect(restaurado.endedAt, isNull);
      expect(correndo.runningSince, DateTime(2026, 7, 30, 19, 31));
      expect(correndo.elapsed, Duration.zero);
      expect(restaurado.orderedItems.first.elapsed, const Duration(minutes: 1));
      expect(restaurado.weekLabel, '27 de julho–2 de agosto');
    });

    test(
      'o cronômetro continua contando a partir do relatório restaurado',
      () async {
        final original = reuniaoEmAndamento();
        final correndoId = original.runningItemId!;
        await storage.save(original);
        var report = (await storage.load())!;

        relogio.avancar(const Duration(seconds: 40));

        // Antes mesmo de fechar o trecho, o tempo mostrado já soma os 20s de
        // antes do reload com os 40s de depois.
        expect(
          report.itemById(correndoId)!.effectiveElapsed(relogio.agora),
          const Duration(minutes: 1),
        );

        report = timer.next(report);

        expect(
          report.itemById(correndoId)!.elapsed,
          const Duration(minutes: 1),
        );
        expect(report.runningItemId, relatorioDaSemana.orderedItems[2].id);
        expect(
          report.itemById(report.runningItemId!)!.runningSince,
          relogio.agora,
        );
      },
    );

    test(
      'a reunião terminada depois do reload fecha com os tempos certos',
      () async {
        await storage.save(reuniaoEmAndamento());
        var report = (await storage.load())!;

        relogio.avancar(const Duration(seconds: 40));
        report = timer.next(report);
        relogio.avancar(const Duration(minutes: 2));
        report = timer.endMeeting(report);

        expect(report.startedAt, inicioDaReuniao);
        expect(report.endedAt, DateTime(2026, 7, 30, 19, 34));
        expect(
          report.orderedItems.where((item) => item.runningSince != null),
          isEmpty,
        );
        final somaDosItens = report.orderedItems.fold(
          Duration.zero,
          (total, item) => total + item.elapsed,
        );
        expect(somaDosItens, report.endedAt!.difference(report.startedAt!));
      },
    );
  });

  group('Fluxo completo — reiniciar tudo', () {
    test('apaga o relatório da memória e do disco', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ReportStorageRepository();
      final notifier = MeetingNotifier(
        timer: MeetingTimerService(clock: DateTime.now),
        builder: const ReportBuilder(),
        parser: const ScheduleParser(),
        wol: WolRepository(client: clienteDasFixtures()),
        storage: storage,
        fetchStatus: ScheduleFetchNotifier(),
      );
      await notifier.restored;
      await notifier.downloadSchedule();
      expect(notifier.state, isNotNull);
      expect(await storage.load(), isNotNull);

      await notifier.resetAll();

      // Some das duas pontas: a tela volta ao estado vazio e o app não
      // restaura nada no próximo boot.
      expect(notifier.state, isNull);
      expect(await storage.load(), isNull);
    });
  });
}

/// Marcadores de leitura para os pares `(label, isSubItem)`.
const bool subItem = true;
const bool parte = false;

/// Os itens da seção como pares `(label, isSubItem)`, que é o que a regra de
/// sub-itens do `CLAUDE.md` descreve.
List<(String, bool)> descreverItens(MeetingSection section) => [
  for (final item in section.items) (item.label, item.isSubItem),
];
