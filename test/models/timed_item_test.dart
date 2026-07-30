import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/models/json_decoding.dart';
import 'package:rdr/models/timed_item.dart';

final _inicioDoTrecho = DateTime(2026, 7, 30, 20, 15);

/// Item correndo, em instâncias novas a cada chamada — sem `const`, que
/// canonizaria os objetos e mascararia a igualdade por valor.
TimedItem _itemCorrendo() => TimedItem(
  id: 'i1',
  label: '3. Leitura da Bíblia',
  elapsed: const Duration(minutes: 4),
  runningSince: _inicioDoTrecho,
  isSubItem: true,
);

Map<String, dynamic> _jsonValido() => <String, dynamic>{
  'id': 'i1',
  'label': 'Presidente',
  'elapsedMicroseconds': 0,
  'runningSince': null,
  'isSubItem': true,
};

void main() {
  group('TimedItem.effectiveElapsed', () {
    test('devolve o elapsed acumulado quando o item está parado', () {
      const item = TimedItem(
        id: 'i1',
        label: 'Comentários iniciais',
        elapsed: Duration(minutes: 3, seconds: 20),
      );

      final resultado = item.effectiveElapsed(DateTime(2026, 7, 30, 20, 15));

      expect(resultado, const Duration(minutes: 3, seconds: 20));
    });

    test('soma o trecho aberto ao elapsed quando o item está correndo', () {
      final item = TimedItem(
        id: 'i1',
        label: 'Comentários iniciais',
        elapsed: const Duration(minutes: 3, seconds: 20),
        runningSince: _inicioDoTrecho,
      );

      final resultado = item.effectiveElapsed(
        _inicioDoTrecho.add(const Duration(seconds: 45)),
      );

      expect(resultado, const Duration(minutes: 4, seconds: 5));
    });
  });

  group('TimedItem.copyWith', () {
    test('sem argumentos preserva todos os campos', () {
      final original = _itemCorrendo();

      final copia = original.copyWith();

      expect(copia.id, 'i1');
      expect(copia.label, '3. Leitura da Bíblia');
      expect(copia.elapsed, const Duration(minutes: 4));
      expect(copia.runningSince, _inicioDoTrecho);
      expect(copia.isSubItem, isTrue);
    });

    test('troca apenas o campo informado e preserva o resto', () {
      final original = _itemCorrendo();

      final renomeado = original.copyWith(label: 'Leitura da Bíblia');

      expect(renomeado.label, 'Leitura da Bíblia');
      expect(renomeado.id, 'i1');
      expect(renomeado.elapsed, const Duration(minutes: 4));
      expect(renomeado.runningSince, _inicioDoTrecho);
      expect(renomeado.isSubItem, isTrue);
    });

    test('limpa o runningSince quando clearRunningSince é usado', () {
      final parado = _itemCorrendo().copyWith(clearRunningSince: true);

      expect(parado.runningSince, isNull);
      expect(parado.elapsed, const Duration(minutes: 4));
    });
  });

  group('TimedItem igualdade', () {
    test('dois itens com os mesmos valores são iguais e têm o mesmo hashCode', () {
      final a = TimedItem(
        id: 'i1',
        label: 'Presidente',
        elapsed: const Duration(seconds: 42),
        runningSince: DateTime(2026, 7, 30, 20, 15),
        isSubItem: true,
      );
      final b = TimedItem(
        id: 'i1',
        label: 'Presidente',
        elapsed: const Duration(seconds: 42),
        runningSince: DateTime(2026, 7, 30, 20, 15),
        isSubItem: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('um item é igual a si mesmo e à sua cópia sem alterações', () {
      final a = _itemCorrendo();

      expect(a, equals(a));
      expect(a.copyWith(), equals(a));
    });

    test('itens que diferem em qualquer campo não são iguais', () {
      const base = TimedItem(id: 'i1', label: 'Presidente');

      expect(base, isNot(equals(base.copyWith(id: 'i2'))));
      expect(base, isNot(equals(base.copyWith(label: 'Conselho'))));
      expect(
        base,
        isNot(equals(base.copyWith(elapsed: const Duration(seconds: 1)))),
      );
      expect(
        base,
        isNot(equals(base.copyWith(runningSince: DateTime(2026, 7, 30)))),
      );
      expect(base, isNot(equals(base.copyWith(isSubItem: true))));
    });
  });

  group('TimedItem.toString', () {
    test('descreve o item para facilitar a leitura de falhas de teste', () {
      final texto = _itemCorrendo().toString();

      expect(texto, contains('i1'));
      expect(texto, contains('3. Leitura da Bíblia'));
    });
  });

  group('TimedItem serialização', () {
    test('faz round-trip fiel de um item correndo, com data em ISO-8601', () {
      final original = _itemCorrendo();

      final json = original.toJson();

      expect(json['runningSince'], _inicioDoTrecho.toIso8601String());
      expect(TimedItem.fromJson(json), equals(original));
    });

    test('preserva runningSince nulo no round-trip', () {
      const original = TimedItem(
        id: 'i2',
        label: 'Comentários finais',
        elapsed: Duration(seconds: 7),
      );

      final json = original.toJson();

      expect(json['runningSince'], isNull);
      expect(TimedItem.fromJson(json), equals(original));
    });

    test('lança ReportDecodeException quando falta um campo obrigatório', () {
      for (final chave in ['id', 'label', 'elapsedMicroseconds', 'isSubItem']) {
        final json = _jsonValido()..remove(chave);

        expect(
          () => TimedItem.fromJson(json),
          throwsA(isA<ReportDecodeException>()),
          reason: 'faltando "$chave"',
        );
      }
    });

    test('lança ReportDecodeException quando um campo tem o tipo errado', () {
      final json = _jsonValido()..['elapsedMicroseconds'] = 'muito tempo';

      expect(
        () => TimedItem.fromJson(json),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('lança ReportDecodeException quando a data não é ISO-8601 válida', () {
      final json = _jsonValido()..['runningSince'] = 'ontem à noite';

      expect(
        () => TimedItem.fromJson(json),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('lança ReportDecodeException quando a data não vem como texto', () {
      final json = _jsonValido()..['runningSince'] = 1753900000000;

      expect(
        () => TimedItem.fromJson(json),
        throwsA(isA<ReportDecodeException>()),
      );
    });

    test('lança ReportDecodeException quando o JSON não é um objeto', () {
      expect(
        () => TimedItem.fromJson('não é um mapa'),
        throwsA(isA<ReportDecodeException>()),
      );
    });
  });
}
