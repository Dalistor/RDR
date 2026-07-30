import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/models/json_decoding.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/models/timed_item.dart';

/// Instâncias novas a cada chamada — nada de `const`, que canonizaria os
/// objetos e faria os testes de igualdade passarem por identidade.
MeetingSection _tesouros() => MeetingSection(
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
);

void main() {
  group('MeetingSection.copyWith', () {
    test('sem argumentos preserva todos os campos', () {
      final original = _tesouros();

      final copia = original.copyWith();

      expect(copia.kind, SectionKind.treasures);
      expect(copia.title, 'TESOUROS DA PALAVRA DE DEUS');
      expect(copia.items, original.items);
    });

    test('troca apenas os itens e preserva tipo e título', () {
      final original = _tesouros();

      final copia = original.copyWith(
        items: const [TimedItem(id: 't9', label: '9. Parte nova')],
      );

      expect(copia.items, hasLength(1));
      expect(copia.items.single.label, '9. Parte nova');
      expect(copia.kind, SectionKind.treasures);
      expect(copia.title, 'TESOUROS DA PALAVRA DE DEUS');
    });
  });

  group('MeetingSection igualdade', () {
    test('seções com os mesmos itens são iguais e têm o mesmo hashCode', () {
      final a = _tesouros();
      final b = _tesouros();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('uma seção é igual a si mesma e à sua cópia sem alterações', () {
      final a = _tesouros();

      expect(a, equals(a));
      expect(a.copyWith(), equals(a));
    });

    test('seções que diferem em um item não são iguais', () {
      final a = _tesouros();
      final b = a.copyWith(
        items: [a.items.first, a.items.last.copyWith(label: 'Conselho')],
      );

      expect(a, isNot(equals(b)));
    });

    test('seções que diferem em tipo ou título não são iguais', () {
      final a = _tesouros();

      expect(a, isNot(equals(a.copyWith(kind: SectionKind.ministry))));
      expect(a, isNot(equals(a.copyWith(title: 'OUTRO TÍTULO'))));
    });
  });

  group('MeetingSection.toString', () {
    test('descreve a seção para facilitar a leitura de falhas de teste', () {
      final texto = _tesouros().toString();

      expect(texto, contains('treasures'));
      expect(texto, contains('TESOUROS DA PALAVRA DE DEUS'));
    });
  });

  group('MeetingSection serialização', () {
    test('faz round-trip fiel preservando tipo, título e ordem dos itens', () {
      final original = _tesouros();

      final decodificada = MeetingSection.fromJson(original.toJson());

      expect(decodificada, equals(original));
      expect(
        decodificada.items.map((item) => item.id).toList(),
        ['t1', 't1p'],
      );
    });

    test('serializa as três seções e as reconhece de volta', () {
      for (final kind in SectionKind.values) {
        final secao = MeetingSection(kind: kind, title: 'X', items: const []);

        expect(MeetingSection.fromJson(secao.toJson()).kind, kind);
      }
    });

    test('lança ReportDecodeException para uma seção desconhecida', () {
      final json = <String, dynamic>{
        'kind': 'cantico',
        'title': 'CÂNTICOS',
        'items': <dynamic>[],
      };

      expect(
        () => MeetingSection.fromJson(json),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('lança ReportDecodeException quando items não é uma lista', () {
      final json = <String, dynamic>{
        'kind': 'treasures',
        'title': 'TESOUROS DA PALAVRA DE DEUS',
        'items': 'nenhum',
      };

      expect(
        () => MeetingSection.fromJson(json),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('lança ReportDecodeException quando um item da lista é inválido', () {
      final json = <String, dynamic>{
        'kind': 'treasures',
        'title': 'TESOUROS DA PALAVRA DE DEUS',
        'items': <dynamic>['isto não é um item'],
      };

      expect(
        () => MeetingSection.fromJson(json),
        throwsA(isA<ReportDecodeException>()),
      );
    });
  });
}
