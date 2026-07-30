import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/models/timed_item.dart';
import 'package:rdr/repositories/report_storage_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma reunião a meio caminho: tempos acumulados, um item correndo, sub-itens
/// automáticos e um item acrescentado na mão durante a reunião.
MeetingReport _reuniaoEmAndamento() => MeetingReport(
  weekLabel: '27 de julho–2 de agosto',
  startedAt: DateTime(2026, 7, 30, 19, 30),
  openingComments: TimedItem(
    id: 'abertura',
    label: 'Comentários iniciais',
    elapsed: const Duration(minutes: 1, seconds: 12),
  ),
  sections: [
    MeetingSection(
      kind: SectionKind.treasures,
      title: 'TESOUROS DA PALAVRA DE DEUS',
      items: [
        TimedItem(
          id: 't1',
          label: '1. Ele pregou com coragem',
          elapsed: const Duration(minutes: 10, seconds: 4),
        ),
        TimedItem(
          id: 't1p',
          label: 'Presidente',
          elapsed: const Duration(seconds: 47),
          isSubItem: true,
        ),
        TimedItem(
          id: 'manual-1',
          label: 'Parte extra da assembleia',
          elapsed: const Duration(minutes: 2),
        ),
      ],
    ),
    MeetingSection(
      kind: SectionKind.christianLife,
      title: 'NOSSA VIDA CRISTÃ',
      items: [
        TimedItem(id: 'c0', label: 'Presidente'),
        TimedItem(
          id: 'c8',
          label: '8. Estudo bíblico de congregação',
          elapsed: const Duration(minutes: 5),
          runningSince: DateTime(2026, 7, 30, 20, 42, 15),
        ),
      ],
    ),
  ],
  closingComments: TimedItem(id: 'fechamento', label: 'Comentários finais'),
  runningItemId: 'c8',
  selectedItemId: 'c0',
);

/// Relatório recém-montado: nada iniciado, nada correndo, tudo zerado.
MeetingReport _reuniaoNaoIniciada() => MeetingReport(
  weekLabel: '3–9 de agosto',
  openingComments: TimedItem(id: 'abertura', label: 'Comentários iniciais'),
  sections: const [],
  closingComments: TimedItem(id: 'fechamento', label: 'Comentários finais'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ReportStorageRepository.load', () {
    test('sem nada salvo devolve null, sem lançar', () async {
      final repository = ReportStorageRepository();

      await expectLater(repository.load(), completion(isNull));
    });
  });

  group('ReportStorageRepository round-trip', () {
    test('carregar depois de salvar devolve um relatório igual ao original', () async {
      final repository = ReportStorageRepository();
      final original = _reuniaoEmAndamento();

      await repository.save(original);

      expect(await repository.load(), equals(original));
    });

    // Asserções campo a campo, que não dependem do `==` do model: se um dia a
    // igualdade deixar de comparar algum campo, o teste acima passaria vazio.
    test('preserva o estado do cronômetro: tempos, início e item correndo', () async {
      final repository = ReportStorageRepository();
      await repository.save(_reuniaoEmAndamento());

      final carregado = (await repository.load())!;

      expect(carregado.weekLabel, '27 de julho–2 de agosto');
      expect(carregado.startedAt, DateTime(2026, 7, 30, 19, 30));
      expect(carregado.endedAt, isNull);
      expect(carregado.runningItemId, 'c8');
      expect(carregado.selectedItemId, 'c0');
      expect(
        carregado.itemById('c8')!.runningSince,
        DateTime(2026, 7, 30, 20, 42, 15),
      );
      expect(carregado.itemById('c8')!.elapsed, const Duration(minutes: 5));
      expect(
        carregado.openingComments.elapsed,
        const Duration(minutes: 1, seconds: 12),
      );
      expect(
        carregado.itemById('t1')!.elapsed,
        const Duration(minutes: 10, seconds: 4),
      );
    });

    test('preserva seções, ordem dos itens, sub-itens e itens adicionados na mão', () async {
      final repository = ReportStorageRepository();
      await repository.save(_reuniaoEmAndamento());

      final carregado = (await repository.load())!;

      expect(carregado.sections.map((s) => s.kind).toList(), [
        SectionKind.treasures,
        SectionKind.christianLife,
      ]);
      expect(carregado.sections.first.title, 'TESOUROS DA PALAVRA DE DEUS');
      expect(carregado.orderedItems.map((item) => item.id).toList(), [
        'abertura',
        't1',
        't1p',
        'manual-1',
        'c0',
        'c8',
        'fechamento',
      ]);
      expect(carregado.itemById('t1p')!.isSubItem, isTrue);
      expect(carregado.itemById('manual-1')!.label, 'Parte extra da assembleia');
      expect(carregado.itemById('manual-1')!.isSubItem, isFalse);
      expect(carregado.itemById('manual-1')!.elapsed, const Duration(minutes: 2));
    });

    test('relatório ainda não iniciado volta com os campos nulos intactos', () async {
      final repository = ReportStorageRepository();
      final original = _reuniaoNaoIniciada();

      await repository.save(original);

      final carregado = (await repository.load())!;
      expect(carregado, equals(original));
      expect(carregado.startedAt, isNull);
      expect(carregado.endedAt, isNull);
      expect(carregado.runningItemId, isNull);
      expect(carregado.selectedItemId, isNull);
      expect(carregado.sections, isEmpty);
      expect(carregado.openingComments.elapsed, Duration.zero);
      expect(carregado.openingComments.runningSince, isNull);
    });
  });

  group('ReportStorageRepository.save sobrescrevendo', () {
    test('salvar duas vezes deixa apenas o último relatório', () async {
      final repository = ReportStorageRepository();
      final primeiro = _reuniaoEmAndamento();
      final segundo = primeiro.copyWith(
        weekLabel: '3–9 de agosto',
        endedAt: DateTime(2026, 7, 30, 21, 15),
        clearRunningItemId: true,
      );

      await repository.save(primeiro);
      await repository.save(segundo);

      final carregado = await repository.load();
      expect(carregado, equals(segundo));
      expect(carregado, isNot(equals(primeiro)));
    });

    test('salvar duas vezes não acumula chaves no armazenamento', () async {
      final repository = ReportStorageRepository();

      await repository.save(_reuniaoEmAndamento());
      await repository.save(_reuniaoNaoIniciada());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), hasLength(1));
    });
  });

  group('ReportStorageRepository.load com valor corrompido', () {
    test('JSON inválido devolve null em vez de propagar exceção', () async {
      SharedPreferences.setMockInitialValues({
        ReportStorageRepository.storageKey: '{isso não é json',
      });
      final repository = ReportStorageRepository();

      await expectLater(repository.load(), completion(isNull));
    });

    test('JSON inválido é apagado, para não travar a próxima reunião', () async {
      SharedPreferences.setMockInitialValues({
        ReportStorageRepository.storageKey: '{isso não é json',
      });
      final repository = ReportStorageRepository();

      await repository.load();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ReportStorageRepository.storageKey), isFalse);
    });

    test('JSON de formato antigo devolve null e é apagado', () async {
      // JSON perfeitamente válido, mas sem os campos que o relatório exige hoje.
      SharedPreferences.setMockInitialValues({
        ReportStorageRepository.storageKey:
            '{"semana":"27 de julho","partes":[{"nome":"Leitura da Bíblia","segundos":240}]}',
      });
      final repository = ReportStorageRepository();

      expect(await repository.load(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ReportStorageRepository.storageKey), isFalse);
    });

    test('valor de outro tipo sob a chave devolve null e é apagado', () async {
      // Uma versão antiga do app pode ter gravado outra coisa nessa chave.
      SharedPreferences.setMockInitialValues({
        ReportStorageRepository.storageKey: 42,
      });
      final repository = ReportStorageRepository();

      expect(await repository.load(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ReportStorageRepository.storageKey), isFalse);
    });
  });

  group('ReportStorageRepository.clear', () {
    test('remove o relatório salvo e carregar depois devolve null', () async {
      final repository = ReportStorageRepository();
      await repository.save(_reuniaoEmAndamento());

      await repository.clear();

      expect(await repository.load(), isNull);
    });

    test('não deixa a chave para trás no armazenamento', () async {
      final repository = ReportStorageRepository();
      await repository.save(_reuniaoEmAndamento());

      await repository.clear();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(ReportStorageRepository.storageKey), isFalse);
    });

    test('limpar sem nada salvo não lança', () async {
      final repository = ReportStorageRepository();

      await expectLater(repository.clear(), completes);
      expect(await repository.load(), isNull);
    });

    test('depois de limpar dá para salvar de novo', () async {
      final repository = ReportStorageRepository();
      await repository.save(_reuniaoEmAndamento());
      await repository.clear();

      final novo = _reuniaoNaoIniciada();
      await repository.save(novo);

      expect(await repository.load(), equals(novo));
    });
  });
}
