import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/models/timed_item.dart';
import 'package:rdr/services/meeting_timer_service.dart';

/// Relógio controlado pelo teste, no lugar de `DateTime.now()`.
class RelogioFalso {
  RelogioFalso(this.agora);

  DateTime agora;

  DateTime call() => agora;

  void avancar(Duration quanto) => agora = agora.add(quanto);
}

/// Instante base de todos os testes: uma quinta-feira às 19:30.
final DateTime inicio = DateTime(2026, 7, 30, 19, 30);

/// Relatório completo e zerado, na ordem canônica:
///
/// `abertura`, `t1`, `t1p`, `t2`, `t2p`, `m4`, `m4c`, `m4t`, `cl0`, `cl7`,
/// `cl8`, `fechamento`.
MeetingReport relatorio() => MeetingReport(
  weekLabel: '27 de julho–2 de agosto',
  openingComments: const TimedItem(
    id: 'abertura',
    label: 'Comentários iniciais',
  ),
  sections: const [
    MeetingSection(
      kind: SectionKind.treasures,
      title: 'TESOUROS DA PALAVRA DE DEUS',
      items: [
        TimedItem(id: 't1', label: '1. Ele pregou com coragem'),
        TimedItem(id: 't1p', label: 'Presidente', isSubItem: true),
        TimedItem(id: 't2', label: '2. Joias espirituais'),
        TimedItem(id: 't2p', label: 'Presidente', isSubItem: true),
      ],
    ),
    MeetingSection(
      kind: SectionKind.ministry,
      title: 'FAÇA SEU MELHOR NO MINISTÉRIO',
      items: [
        TimedItem(id: 'm4', label: '4. Iniciando conversas'),
        TimedItem(id: 'm4c', label: 'Conselho', isSubItem: true),
        TimedItem(id: 'm4t', label: 'Transição', isSubItem: true),
      ],
    ),
    MeetingSection(
      kind: SectionKind.christianLife,
      title: 'NOSSA VIDA CRISTÃ',
      items: [
        TimedItem(id: 'cl0', label: 'Presidente'),
        TimedItem(
          id: 'cl7',
          label: '7. Seja adaptável — mostre interesse pessoal',
        ),
        TimedItem(id: 'cl8', label: '8. Estudo bíblico de congregação'),
      ],
    ),
  ],
  closingComments: const TimedItem(
    id: 'fechamento',
    label: 'Comentários finais',
  ),
);

/// Os ids na ordem canônica, para os testes de navegação.
const List<String> ordemCanonica = [
  'abertura',
  't1',
  't1p',
  't2',
  't2p',
  'm4',
  'm4c',
  'm4t',
  'cl0',
  'cl7',
  'cl8',
  'fechamento',
];

/// Atalho para o item de [id] — falha o teste se ele não existir.
TimedItem item(MeetingReport report, String id) {
  final encontrado = report.itemById(id);
  expect(encontrado, isNotNull, reason: 'item "$id" não existe no relatório');
  return encontrado!;
}

void main() {
  late RelogioFalso relogio;
  late MeetingTimerService service;

  setUp(() {
    relogio = RelogioFalso(inicio);
    service = MeetingTimerService(clock: relogio.call);
  });

  group('start', () {
    test('arranca o primeiro item quando nada está selecionado', () {
      final depois = service.start(relatorio());

      expect(depois.runningItemId, 'abertura');
      expect(depois.selectedItemId, 'abertura');
      expect(item(depois, 'abertura').runningSince, inicio);
    });

    test('não grava o início da reunião: isso é papel do startMeeting', () {
      final depois = service.start(relatorio());

      expect(depois.startedAt, isNull);
    });

    test('arranca o item selecionado, e não o primeiro da ordem', () {
      final antes = relatorio().copyWith(selectedItemId: 'm4c');

      final depois = service.start(antes);

      expect(depois.runningItemId, 'm4c');
      expect(depois.selectedItemId, 'm4c');
      expect(item(depois, 'm4c').runningSince, inicio);
      expect(item(depois, 'abertura').runningSince, isNull);
    });

    test('não altera um início de reunião já gravado', () {
      final primeiro = service.start(service.startMeeting(relatorio()));
      relogio.avancar(const Duration(minutes: 12));

      final segundo = service.start(primeiro);

      expect(segundo.startedAt, inicio);
    });

    test('com outro item correndo, fecha o trecho dele antes de arrancar', () {
      final correndo = service.start(relatorio());
      relogio.avancar(const Duration(minutes: 2));

      final depois = service.start(correndo.copyWith(selectedItemId: 't1'));

      expect(item(depois, 'abertura').elapsed, const Duration(minutes: 2));
      expect(item(depois, 'abertura').runningSince, isNull);
      expect(depois.runningItemId, 't1');
      expect(item(depois, 't1').runningSince, relogio.agora);
    });
  });

  group('pause', () {
    test('soma o trecho aberto ao elapsed e para o cronômetro', () {
      final correndo = service.start(
        relatorio().copyWith(selectedItemId: 't1'),
      );
      relogio.avancar(const Duration(minutes: 9, seconds: 40));

      final depois = service.pause(correndo);

      expect(
        item(depois, 't1').elapsed,
        const Duration(minutes: 9, seconds: 40),
      );
      expect(item(depois, 't1').runningSince, isNull);
      expect(depois.runningItemId, isNull);
      expect(depois.selectedItemId, 't1');
    });

    test('sem nada correndo devolve o próprio relatório, sem reconstruir', () {
      final parado = service.pause(service.start(relatorio()));
      relogio.avancar(const Duration(minutes: 5));

      expect(service.pause(parado), same(parado));
    });

    test('dois trechos separados do mesmo item somam no elapsed', () {
      var report = relatorio().copyWith(selectedItemId: 't2');

      report = service.start(report);
      relogio.avancar(const Duration(minutes: 3, seconds: 15));
      report = service.pause(report);

      relogio.avancar(const Duration(minutes: 20));

      report = service.start(report);
      relogio.avancar(const Duration(minutes: 1, seconds: 45));
      report = service.pause(report);

      expect(item(report, 't2').elapsed, const Duration(minutes: 5));
    });
  });

  group('advance', () {
    test('fecha o trecho do item corrente sem arrancar o próximo', () {
      final correndo = service.start(relatorio().copyWith(selectedItemId: 't1'));
      relogio.avancar(const Duration(minutes: 11, seconds: 51));

      final depois = service.advance(correndo);

      expect(
        item(depois, 't1').elapsed,
        const Duration(minutes: 11, seconds: 51),
      );
      expect(item(depois, 't1').runningSince, isNull);
      expect(depois.runningItemId, isNull);
    });

    test('move a seleção para o próximo item da ordem canônica', () {
      final correndo = service.start(relatorio().copyWith(selectedItemId: 't1'));

      final depois = service.advance(correndo);

      expect(depois.selectedItemId, 't1p');
    });

    test('não arranca o próximo item: nada fica correndo', () {
      final correndo = service.start(relatorio().copyWith(selectedItemId: 't1'));

      final depois = service.advance(correndo);

      expect(depois.runningItemId, isNull);
      expect(item(depois, 't1p').runningSince, isNull);
      expect(
        depois.orderedItems.where((i) => i.runningSince != null),
        isEmpty,
      );
    });

    test('no último item fecha o trecho e a seleção não se move', () {
      final correndo = service.start(
        relatorio().copyWith(selectedItemId: 'fechamento'),
      );
      relogio.avancar(const Duration(minutes: 5, seconds: 38));

      final depois = service.advance(correndo);

      expect(depois.selectedItemId, 'fechamento');
      expect(
        item(depois, 'fechamento').elapsed,
        const Duration(minutes: 5, seconds: 38),
      );
      expect(depois.runningItemId, isNull);
    });

    test('sem nada correndo apenas move a seleção, sem mexer nos tempos', () {
      final parado = relatorio().copyWith(selectedItemId: 'm4');

      final depois = service.advance(parado);

      expect(depois.selectedItemId, 'm4c');
      expect(item(depois, 'm4').elapsed, Duration.zero);
      expect(depois.runningItemId, isNull);
    });
  });

  group('startMeeting', () {
    test('grava o horário de início da reunião pelo relógio', () {
      final depois = service.startMeeting(relatorio());

      expect(depois.startedAt, inicio);
    });

    test('não arranca cronômetro nenhum e não mexe na seleção', () {
      final antes = relatorio().copyWith(selectedItemId: 'm4');

      final depois = service.startMeeting(antes);

      expect(depois.runningItemId, isNull);
      expect(depois.selectedItemId, 'm4');
      expect(
        depois.orderedItems.where((i) => i.runningSince != null),
        isEmpty,
      );
    });

    test('chamado duas vezes não sobrescreve o início já gravado', () {
      final primeiro = service.startMeeting(relatorio());
      relogio.avancar(const Duration(minutes: 20));

      final segundo = service.startMeeting(primeiro);

      expect(segundo.startedAt, inicio);
    });
  });

  group('resetItem', () {
    test('zera o elapsed do item indicado', () {
      var report = service.start(relatorio().copyWith(selectedItemId: 't2'));
      relogio.avancar(const Duration(minutes: 9, seconds: 51));
      report = service.pause(report);

      final depois = service.resetItem(report, 't2');

      expect(item(depois, 't2').elapsed, Duration.zero);
    });

    test('item parado continua parado depois de zerado', () {
      var report = service.start(relatorio().copyWith(selectedItemId: 't2'));
      relogio.avancar(const Duration(minutes: 4));
      report = service.pause(report);

      final depois = service.resetItem(report, 't2');

      expect(item(depois, 't2').runningSince, isNull);
      expect(depois.runningItemId, isNull);
    });

    test('item correndo continua correndo, mas contando do zero', () {
      final correndo = service.start(relatorio().copyWith(selectedItemId: 't1'));
      relogio.avancar(const Duration(minutes: 7));

      final depois = service.resetItem(correndo, 't1');

      expect(item(depois, 't1').elapsed, Duration.zero);
      expect(item(depois, 't1').runningSince, relogio.agora);
      expect(depois.runningItemId, 't1');

      relogio.avancar(const Duration(seconds: 30));
      expect(
        item(depois, 't1').effectiveElapsed(relogio.agora),
        const Duration(seconds: 30),
      );
    });

    test('não mexe no tempo de nenhum outro item', () {
      var report = service.start(relatorio().copyWith(selectedItemId: 't1'));
      relogio.avancar(const Duration(minutes: 3));
      report = service.next(report);
      relogio.avancar(const Duration(minutes: 2));
      report = service.pause(report);

      final depois = service.resetItem(report, 't1p');

      expect(item(depois, 't1').elapsed, const Duration(minutes: 3));
      expect(item(depois, 't1p').elapsed, Duration.zero);
    });

    test('não toca nos horários de início e fim da reunião', () {
      final report = service
          .startMeeting(relatorio())
          .copyWith(endedAt: inicio.add(const Duration(hours: 1)));

      final depois = service.resetItem(report, 't1');

      expect(depois.startedAt, inicio);
      expect(depois.endedAt, inicio.add(const Duration(hours: 1)));
    });

    test('id inexistente devolve o relatório sem alteração', () {
      var report = service.start(relatorio().copyWith(selectedItemId: 't1'));
      relogio.avancar(const Duration(minutes: 6));
      report = service.pause(report);

      final depois = service.resetItem(report, 'nao-existe');

      expect(item(depois, 't1').elapsed, const Duration(minutes: 6));
    });
  });

  group('next', () {
    test(
      'fecha o trecho do item corrente e arranca o próximo, levando a seleção',
      () {
        final correndo = service.start(
          relatorio().copyWith(selectedItemId: 't1'),
        );
        relogio.avancar(const Duration(minutes: 10));

        final depois = service.next(correndo);

        expect(item(depois, 't1').elapsed, const Duration(minutes: 10));
        expect(item(depois, 't1').runningSince, isNull);
        expect(depois.runningItemId, 't1p');
        expect(depois.selectedItemId, 't1p');
        expect(item(depois, 't1p').runningSince, relogio.agora);
      },
    );

    test('no último item fecha o trecho, para, e não encerra a reunião', () {
      final correndo = service.start(
        relatorio().copyWith(selectedItemId: 'fechamento'),
      );
      relogio.avancar(const Duration(minutes: 4));

      final depois = service.next(correndo);

      expect(item(depois, 'fechamento').elapsed, const Duration(minutes: 4));
      expect(item(depois, 'fechamento').runningSince, isNull);
      expect(depois.runningItemId, isNull);
      expect(depois.selectedItemId, 'fechamento');
      expect(depois.endedAt, isNull);
    });

    test('sem nada correndo, arranca o item seguinte ao selecionado', () {
      final parado = relatorio().copyWith(selectedItemId: 'm4');

      final depois = service.next(parado);

      expect(depois.runningItemId, 'm4c');
      expect(depois.selectedItemId, 'm4c');
      expect(item(depois, 'm4').runningSince, isNull);
      expect(item(depois, 'm4').elapsed, Duration.zero);
    });

    test('sem nada correndo e sem seleção, arranca o primeiro item', () {
      final depois = service.next(relatorio());

      expect(depois.runningItemId, 'abertura');
      expect(depois.selectedItemId, 'abertura');
      expect(item(depois, 'abertura').runningSince, inicio);
    });

    test('parado no último item selecionado não arranca nada', () {
      final parado = relatorio().copyWith(selectedItemId: 'fechamento');

      final depois = service.next(parado);

      expect(depois.runningItemId, isNull);
      expect(depois.selectedItemId, 'fechamento');
      expect(item(depois, 'fechamento').elapsed, Duration.zero);
    });
  });

  group('selectNext / selectPrevious', () {
    test('selectNext anda um passo na ordem sem parar o item que corre', () {
      final correndo = service.start(
        relatorio().copyWith(selectedItemId: 't1'),
      );
      relogio.avancar(const Duration(minutes: 6));

      final depois = service.selectNext(correndo);

      expect(depois.selectedItemId, 't1p');
      expect(depois.runningItemId, 't1');
      expect(item(depois, 't1').runningSince, inicio);
      expect(item(depois, 't1').elapsed, Duration.zero);
      expect(item(depois, 't1p').runningSince, isNull);
    });

    test('selectNext no último item não move a seleção', () {
      final antes = relatorio().copyWith(selectedItemId: 'fechamento');

      expect(service.selectNext(antes).selectedItemId, 'fechamento');
    });

    test('selectNext sem seleção nenhuma seleciona o primeiro item', () {
      expect(service.selectNext(relatorio()).selectedItemId, 'abertura');
    });

    test(
      'selectPrevious anda um passo para trás sem parar o item que corre',
      () {
        final correndo = service.start(
          relatorio().copyWith(selectedItemId: 'cl7'),
        );
        relogio.avancar(const Duration(minutes: 3));

        final depois = service.selectPrevious(correndo);

        expect(depois.selectedItemId, 'cl0');
        expect(depois.runningItemId, 'cl7');
        expect(item(depois, 'cl7').runningSince, inicio);
      },
    );

    test('selectPrevious no primeiro item não move a seleção', () {
      final antes = relatorio().copyWith(selectedItemId: 'abertura');

      expect(service.selectPrevious(antes).selectedItemId, 'abertura');
    });

    test('selectPrevious sem seleção nenhuma seleciona o primeiro item', () {
      expect(service.selectPrevious(relatorio()).selectedItemId, 'abertura');
    });

    test('as setas percorrem a ordem canônica inteira, ida e volta', () {
      var report = relatorio();
      final descida = <String>[];
      for (var i = 0; i < ordemCanonica.length; i++) {
        report = service.selectNext(report);
        descida.add(report.selectedItemId!);
      }
      final subida = <String>[];
      for (var i = 0; i < ordemCanonica.length; i++) {
        subida.add(report.selectedItemId!);
        report = service.selectPrevious(report);
      }

      expect(descida, ordemCanonica);
      expect(subida, ordemCanonica.reversed.toList());
    });
  });

  group('endMeeting', () {
    test('fecha o trecho corrente e grava endedAt', () {
      final correndo = service.start(
        service
            .startMeeting(relatorio())
            .copyWith(selectedItemId: 'fechamento'),
      );
      relogio.avancar(const Duration(minutes: 3));

      final depois = service.endMeeting(correndo);

      expect(depois.endedAt, relogio.agora);
      expect(item(depois, 'fechamento').elapsed, const Duration(minutes: 3));
      expect(item(depois, 'fechamento').runningSince, isNull);
      expect(depois.runningItemId, isNull);
      expect(depois.startedAt, inicio);
    });

    test('chamado duas vezes não altera o endedAt já gravado', () {
      final encerrada = service.endMeeting(service.start(relatorio()));
      relogio.avancar(const Duration(minutes: 30));

      expect(service.endMeeting(encerrada).endedAt, inicio);
    });
  });

  group('setStartedAt e setEndedAt', () {
    final DateTime vinteHoras = DateTime(2026, 7, 30, 20, 0);

    test('setStartedAt define o horário de início informado', () {
      final depois = service.setStartedAt(relatorio(), vinteHoras);

      expect(depois.startedAt, vinteHoras);
    });

    test('setStartedAt com null limpa o horário de início', () {
      final comInicio = service.startMeeting(relatorio());

      final depois = service.setStartedAt(comInicio, null);

      expect(depois.startedAt, isNull);
    });

    test('setStartedAt sobrescreve um início já gravado', () {
      final comInicio = service.startMeeting(relatorio());

      final depois = service.setStartedAt(comInicio, vinteHoras);

      expect(depois.startedAt, vinteHoras);
    });

    test('setEndedAt define o horário de fim informado', () {
      final depois = service.setEndedAt(relatorio(), vinteHoras);

      expect(depois.endedAt, vinteHoras);
    });

    test('setEndedAt com null limpa o horário de fim', () {
      final encerrada = service.endMeeting(relatorio());

      final depois = service.setEndedAt(encerrada, null);

      expect(depois.endedAt, isNull);
    });

    test('nenhum dos dois mexe no cronômetro das partes', () {
      final correndo = service.start(relatorio().copyWith(selectedItemId: 't1'));
      relogio.avancar(const Duration(minutes: 3));

      final depois = service.setEndedAt(
        service.setStartedAt(correndo, vinteHoras),
        vinteHoras,
      );

      expect(depois.runningItemId, 't1');
      expect(item(depois, 't1').runningSince, inicio);
      expect(item(depois, 't1').elapsed, Duration.zero);
    });
  });

  group('rename', () {
    test('troca o label de um sub-item sem tocar nos tempos', () {
      final correndo = service.start(
        relatorio().copyWith(selectedItemId: 'm4c'),
      );
      relogio.avancar(const Duration(minutes: 2));

      final depois = service.rename(correndo, 'm4c', 'Conselho do presidente');

      expect(item(depois, 'm4c').label, 'Conselho do presidente');
      expect(item(depois, 'm4c').elapsed, Duration.zero);
      expect(item(depois, 'm4c').runningSince, inicio);
      expect(item(depois, 'm4c').isSubItem, isTrue);
      expect(depois.runningItemId, 'm4c');
    });

    test('troca o label de um item fixo', () {
      final depois = service.rename(relatorio(), 'abertura', 'Abertura');

      expect(depois.openingComments.label, 'Abertura');
    });

    test('com id inexistente devolve o relatório inalterado', () {
      final antes = relatorio();

      expect(service.rename(antes, 'nao-existe', 'X'), antes);
    });
  });

  group('setElapsed', () {
    test('define o tempo de um item parado sem mexer no cronômetro', () {
      final depois = service.setElapsed(
        relatorio(),
        't2',
        const Duration(minutes: 8, seconds: 30),
      );

      expect(
        item(depois, 't2').elapsed,
        const Duration(minutes: 8, seconds: 30),
      );
      expect(item(depois, 't2').runningSince, isNull);
      expect(depois.runningItemId, isNull);
    });

    test('no item que corre, a contagem segue a partir do novo valor', () {
      final correndo = service.start(
        relatorio().copyWith(selectedItemId: 't1'),
      );
      relogio.avancar(const Duration(minutes: 7));

      final corrigido = service.setElapsed(
        correndo,
        't1',
        const Duration(minutes: 2),
      );

      expect(item(corrigido, 't1').elapsed, const Duration(minutes: 2));
      expect(item(corrigido, 't1').runningSince, relogio.agora);
      expect(
        item(corrigido, 't1').effectiveElapsed(relogio.agora),
        const Duration(minutes: 2),
      );
      expect(corrigido.runningItemId, 't1');

      relogio.avancar(const Duration(minutes: 1));
      final parado = service.pause(corrigido);

      expect(item(parado, 't1').elapsed, const Duration(minutes: 3));
    });
  });

  group('addItem', () {
    test('insere um item zerado logo depois do indicado, na mesma seção', () {
      final antes = relatorio();

      final depois = service.addItem(antes, 't1', 'Leitor');

      final novo = depois.sections.first.items[1];
      expect(novo.label, 'Leitor');
      expect(novo.elapsed, Duration.zero);
      expect(novo.runningSince, isNull);
      expect(novo.isSubItem, isFalse);
      expect(depois.sections.first.items.map((i) => i.id), [
        't1',
        novo.id,
        't1p',
        't2',
        't2p',
      ]);
      expect(
        antes.orderedItems.map((i) => i.id),
        isNot(contains(novo.id)),
        reason: 'o id do novo item precisa ser único no relatório',
      );
    });

    test('inserções sucessivas geram ids diferentes', () {
      var report = service.addItem(relatorio(), 't1', 'Primeiro');
      report = service.addItem(report, 't1', 'Segundo');
      report = service.addItem(report, 'm4', 'Terceiro');

      final ids = report.orderedItems.map((i) => i.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(report.orderedItems, hasLength(ordemCanonica.length + 3));
    });

    test('marca o item novo como sub-item quando pedido', () {
      final depois = service.addItem(
        relatorio(),
        'm4',
        'Conselho extra',
        isSubItem: true,
      );

      expect(depois.sections[1].items[1].label, 'Conselho extra');
      expect(depois.sections[1].items[1].isSubItem, isTrue);
    });

    test('depois do último item de uma seção insere no fim dela', () {
      final depois = service.addItem(relatorio(), 'cl8', '9. Extra');

      expect(depois.sections.last.items.map((i) => i.label).last, '9. Extra');
      expect(depois.orderedItems.last.id, 'fechamento');
    });

    test(
      'depois do item fixo de abertura insere no início da primeira seção',
      () {
        final depois = service.addItem(relatorio(), 'abertura', 'Aviso');

        expect(depois.sections.first.items.first.label, 'Aviso');
        expect(depois.orderedItems[1].label, 'Aviso');
      },
    );

    test('depois do item fixo de fechamento insere no fim da última seção', () {
      final depois = service.addItem(relatorio(), 'fechamento', 'Encerramento');

      expect(depois.sections.last.items.last.label, 'Encerramento');
      expect(depois.orderedItems.last.id, 'fechamento');
    });

    test('com id inexistente devolve o relatório inalterado', () {
      final antes = relatorio();

      expect(service.addItem(antes, 'nao-existe', 'Fantasma'), antes);
    });

    test(
      'num relatório sem seções não há onde inserir: devolve inalterado',
      () {
        final semSecoes = relatorio().copyWith(sections: const []);

        expect(
          service.addItem(semSecoes, 'abertura', 'Aviso'),
          same(semSecoes),
        );
      },
    );
  });

  group('removeItem', () {
    test('tira o item da seção e o resto continua na ordem', () {
      final depois = service.removeItem(relatorio(), 't1p');

      expect(depois.itemById('t1p'), isNull);
      expect(
        depois.orderedItems.map((i) => i.id),
        ordemCanonica.where((id) => id != 't1p'),
      );
    });

    test('remover o item que corre para o cronômetro', () {
      final correndo = service.start(
        relatorio().copyWith(selectedItemId: 'm4'),
      );
      relogio.avancar(const Duration(minutes: 5));

      final depois = service.removeItem(correndo, 'm4');

      expect(depois.itemById('m4'), isNull);
      expect(depois.runningItemId, isNull);
      expect(
        depois.orderedItems.map((i) => i.runningSince),
        everyElement(isNull),
      );
    });

    test('remover o item selecionado leva a seleção para o item anterior', () {
      final antes = relatorio().copyWith(selectedItemId: 'm4c');

      final depois = service.removeItem(antes, 'm4c');

      expect(depois.selectedItemId, 'm4');
    });

    test('remover um item não selecionado não mexe na seleção', () {
      final antes = relatorio().copyWith(selectedItemId: 'cl7');

      expect(service.removeItem(antes, 'm4c').selectedItemId, 'cl7');
    });

    test(
      'remover o primeiro item de uma seção seleciona o item que o precede',
      () {
        final antes = relatorio().copyWith(selectedItemId: 't1');

        expect(service.removeItem(antes, 't1').selectedItemId, 'abertura');
      },
    );

    test('com id inexistente devolve o relatório inalterado', () {
      final antes = relatorio();

      expect(service.removeItem(antes, 'nao-existe'), antes);
    });

    test('os itens fixos não são removíveis: o relatório fica inteiro', () {
      final antes = relatorio();

      expect(service.removeItem(antes, 'abertura'), antes);
      expect(service.removeItem(antes, 'fechamento'), antes);
    });

    test('sem item anterior, a seleção vai para o primeiro item', () {
      final antes = relatorio().copyWith(selectedItemId: 'abertura');

      expect(service.removeItem(antes, 'abertura').selectedItemId, 'abertura');
    });
  });
}
