import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/models/json_decoding.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/models/timed_item.dart';

/// Relatório completo, com instâncias novas a cada chamada (sem `const`, que
/// canonizaria os objetos e mascararia a igualdade por valor).
MeetingReport _relatorio() => MeetingReport(
  weekLabel: '27 de julho–2 de agosto',
  startedAt: DateTime(2026, 7, 30, 19, 30),
  endedAt: DateTime(2026, 7, 30, 21, 15),
  openingComments: TimedItem(
    id: 'abertura',
    label: 'Comentários iniciais',
    elapsed: const Duration(minutes: 1),
  ),
  sections: [
    MeetingSection(
      kind: SectionKind.treasures,
      title: 'TESOUROS DA PALAVRA DE DEUS',
      items: [
        TimedItem(id: 't1', label: '1. Ele pregou com coragem'),
        TimedItem(
          id: 't1p',
          label: 'Presidente',
          elapsed: const Duration(seconds: 30),
          isSubItem: true,
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
          runningSince: DateTime(2026, 7, 30, 21, 0),
        ),
      ],
    ),
  ],
  closingComments: TimedItem(
    id: 'fechamento',
    label: 'Comentários finais',
    elapsed: const Duration(minutes: 3),
  ),
  runningItemId: 'c8',
  selectedItemId: 'c8',
);

void main() {
  group('MeetingReport.orderedItems', () {
    test('percorre abertura, itens das seções na ordem e fechamento', () {
      final relatorio = _relatorio();

      final ids = relatorio.orderedItems.map((item) => item.id).toList();

      expect(ids, ['abertura', 't1', 't1p', 'c0', 'c8', 'fechamento']);
    });

    test('sem seções devolve apenas os dois itens fixos', () {
      final relatorio = _relatorio().copyWith(sections: const []);

      expect(
        relatorio.orderedItems.map((item) => item.id).toList(),
        ['abertura', 'fechamento'],
      );
    });
  });

  group('MeetingReport.itemById', () {
    test('acha um item fixo', () {
      expect(_relatorio().itemById('abertura')?.label, 'Comentários iniciais');
      expect(_relatorio().itemById('fechamento')?.label, 'Comentários finais');
    });

    test('acha uma parte de seção e um sub-item', () {
      final relatorio = _relatorio();

      expect(relatorio.itemById('t1')?.label, '1. Ele pregou com coragem');
      expect(relatorio.itemById('t1p')?.isSubItem, isTrue);
    });

    test('devolve null quando o id não existe', () {
      expect(_relatorio().itemById('inexistente'), isNull);
    });
  });

  group('MeetingReport.copyWith', () {
    test('sem argumentos preserva todos os campos', () {
      final original = _relatorio();

      final copia = original.copyWith();

      expect(copia.weekLabel, '27 de julho–2 de agosto');
      expect(copia.startedAt, DateTime(2026, 7, 30, 19, 30));
      expect(copia.endedAt, DateTime(2026, 7, 30, 21, 15));
      expect(copia.openingComments, original.openingComments);
      expect(copia.sections, original.sections);
      expect(copia.closingComments, original.closingComments);
      expect(copia.runningItemId, 'c8');
      expect(copia.selectedItemId, 'c8');
    });

    test('troca apenas o campo informado e preserva o resto', () {
      final original = _relatorio();

      final copia = original.copyWith(selectedItemId: 't1');

      expect(copia.selectedItemId, 't1');
      expect(copia.runningItemId, 'c8');
      expect(copia.weekLabel, original.weekLabel);
      expect(copia.sections, original.sections);
      expect(copia.startedAt, original.startedAt);
    });

    test('limpa os campos anuláveis pelas flags clearX', () {
      final original = _relatorio();

      final zerado = original.copyWith(
        clearStartedAt: true,
        clearEndedAt: true,
        clearRunningItemId: true,
        clearSelectedItemId: true,
      );

      expect(zerado.startedAt, isNull);
      expect(zerado.endedAt, isNull);
      expect(zerado.runningItemId, isNull);
      expect(zerado.selectedItemId, isNull);
      expect(zerado.weekLabel, original.weekLabel);
      expect(zerado.sections, original.sections);
    });
  });

  group('MeetingReport igualdade', () {
    test('relatórios com os mesmos valores são iguais e têm o mesmo hashCode', () {
      final a = _relatorio();
      final b = _relatorio();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('um relatório é igual a si mesmo e à sua cópia sem alterações', () {
      final a = _relatorio();

      expect(a, equals(a));
      expect(a.copyWith(), equals(a));
    });

    test('relatórios que diferem em qualquer campo não são iguais', () {
      final base = _relatorio();

      expect(base, isNot(equals(base.copyWith(weekLabel: 'outra semana'))));
      expect(base, isNot(equals(base.copyWith(clearStartedAt: true))));
      expect(base, isNot(equals(base.copyWith(clearEndedAt: true))));
      expect(base, isNot(equals(base.copyWith(clearRunningItemId: true))));
      expect(base, isNot(equals(base.copyWith(clearSelectedItemId: true))));
      expect(base, isNot(equals(base.copyWith(sections: const []))));
      expect(
        base,
        isNot(
          equals(
            base.copyWith(
              openingComments: base.openingComments.copyWith(label: 'Outro'),
            ),
          ),
        ),
      );
      expect(
        base,
        isNot(
          equals(
            base.copyWith(
              closingComments: base.closingComments.copyWith(label: 'Outro'),
            ),
          ),
        ),
      );
    });
  });

  group('MeetingReport.toString', () {
    test('descreve o relatório para facilitar a leitura de falhas de teste', () {
      final texto = _relatorio().toString();

      expect(texto, contains('27 de julho–2 de agosto'));
      expect(texto, contains('c8'));
    });
  });

  group('MeetingReport serialização', () {
    test('faz round-trip fiel de um relatório completo passando por texto', () {
      final original = _relatorio();

      final decodificado = MeetingReport.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
      );

      expect(decodificado, equals(original));
      expect(decodificado.weekLabel, '27 de julho–2 de agosto');
      expect(
        decodificado.orderedItems.map((item) => item.id).toList(),
        ['abertura', 't1', 't1p', 'c0', 'c8', 'fechamento'],
      );
      expect(decodificado.orderedItems[2].isSubItem, isTrue);
      expect(decodificado.orderedItems[2].elapsed, const Duration(seconds: 30));
      expect(decodificado.sections.map((s) => s.kind).toList(), [
        SectionKind.treasures,
        SectionKind.christianLife,
      ]);
    });

    test('datas sobrevivem como DateTime, serializadas em ISO-8601', () {
      final original = _relatorio();

      final json = original.toJson();
      final decodificado = MeetingReport.fromJson(
        jsonDecode(jsonEncode(json)),
      );

      expect(json['startedAt'], DateTime(2026, 7, 30, 19, 30).toIso8601String());
      expect(json['endedAt'], DateTime(2026, 7, 30, 21, 15).toIso8601String());
      expect(decodificado.startedAt, isA<DateTime>());
      expect(decodificado.startedAt, DateTime(2026, 7, 30, 19, 30));
      expect(decodificado.endedAt, DateTime(2026, 7, 30, 21, 15));
      expect(
        decodificado.itemById('c8')!.runningSince,
        DateTime(2026, 7, 30, 21, 0),
      );
    });

    test('campos nulos continuam nulos no round-trip', () {
      final original = _relatorio().copyWith(
        clearStartedAt: true,
        clearEndedAt: true,
        clearRunningItemId: true,
        clearSelectedItemId: true,
      );

      final json = original.toJson();
      final decodificado = MeetingReport.fromJson(
        jsonDecode(jsonEncode(json)),
      );

      expect(json['startedAt'], isNull);
      expect(json['endedAt'], isNull);
      expect(decodificado.startedAt, isNull);
      expect(decodificado.endedAt, isNull);
      expect(decodificado.runningItemId, isNull);
      expect(decodificado.selectedItemId, isNull);
      expect(decodificado, equals(original));
    });
  });

  group('MeetingReport.fromJson com entrada inválida', () {
    Map<String, dynamic> jsonValido() =>
        jsonDecode(jsonEncode(_relatorio().toJson())) as Map<String, dynamic>;

    test('lança ReportDecodeException quando o JSON não é um objeto', () {
      expect(
        () => MeetingReport.fromJson(jsonDecode('[1, 2, 3]')),
        throwsA(isA<ReportDecodeException>()),
      );
      expect(
        () => MeetingReport.fromJson(null),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('lança ReportDecodeException quando falta um campo obrigatório', () {
      for (final chave in [
        'weekLabel',
        'openingComments',
        'sections',
        'closingComments',
      ]) {
        final json = jsonValido()..remove(chave);

        expect(
          () => MeetingReport.fromJson(json),
          throwsA(isA<ReportDecodeException>()),
          reason: 'faltando "$chave"',
        );
      }
    });

    test('lança ReportDecodeException quando um campo tem o tipo errado', () {
      final semanaInvalida = jsonValido()..['weekLabel'] = 42;
      final secoesInvalidas = jsonValido()..['sections'] = <String, dynamic>{};
      final idInvalido = jsonValido()..['runningItemId'] = 7;
      final dataInvalida = jsonValido()..['startedAt'] = 'quinta-feira';

      expect(
        () => MeetingReport.fromJson(semanaInvalida),
        throwsA(isA<ReportDecodeException>()),
      );
      expect(
        () => MeetingReport.fromJson(secoesInvalidas),
        throwsA(isA<ReportDecodeException>()),
      );
      expect(
        () => MeetingReport.fromJson(idInvalido),
        throwsA(isA<ReportDecodeException>()),
      );
      expect(
        () => MeetingReport.fromJson(dataInvalida),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('lança ReportDecodeException quando um item aninhado é inválido', () {
      final json = jsonValido();
      (json['sections'] as List<dynamic>).first = 'não é uma seção';

      expect(
        () => MeetingReport.fromJson(json),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('a exceção traz uma mensagem descrevendo o problema', () {
      final json = jsonValido()..remove('weekLabel');

      expect(
        () => MeetingReport.fromJson(json),
        throwsA(
          isA<ReportDecodeException>().having(
            (e) => e.message,
            'message',
            contains('weekLabel'),
          ),
        ),
      );
      expect(
        const ReportDecodeException('relatório ilegível').toString(),
        contains('relatório ilegível'),
      );
    });
  });
}
