import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/utils/time_format.dart';

void main() {
  group('formatDuration', () {
    test('formata segundos abaixo de um minuto com zero à esquerda', () {
      expect(formatDuration(const Duration(seconds: 11)), '00:11');
    });

    test('formata minutos e segundos com dois dígitos', () {
      expect(formatDuration(const Duration(minutes: 4, seconds: 12)), '04:12');
    });

    test('formata duração zero como 00:00', () {
      expect(formatDuration(Duration.zero), '00:00');
    });

    test('mantém os minutos crescendo além de 59 em vez de virar hora', () {
      expect(formatDuration(const Duration(minutes: 75, seconds: 3)), '75:03');
    });

    test('formata uma hora exata como 60:00, sem campo de hora', () {
      expect(formatDuration(const Duration(hours: 1)), '60:00');
    });

    test('trata duração negativa de segundos como 00:00', () {
      expect(formatDuration(const Duration(seconds: -5)), '00:00');
    });

    test('não mostra sinal de menos em duração negativa de minutos', () {
      expect(
        formatDuration(const Duration(minutes: -1, seconds: -30)),
        '00:00',
      );
    });

    test('trunca milissegundos em vez de arredondar para cima', () {
      expect(
        formatDuration(const Duration(seconds: 5, milliseconds: 900)),
        '00:05',
      );
    });

    test('trunca milissegundos na virada de minuto', () {
      expect(
        formatDuration(
          const Duration(minutes: 3, seconds: 59, milliseconds: 999),
        ),
        '03:59',
      );
    });
  });

  group('formatClock', () {
    test('formata hora da tarde em 24 horas', () {
      expect(formatClock(DateTime(2026, 7, 30, 20, 0)), '20:00');
    });

    test('preenche hora e minuto com zero à esquerda', () {
      expect(formatClock(DateTime(2026, 7, 30, 9, 5)), '09:05');
    });

    test('formata meia-noite como 00:00, sem virar 12 ou 24', () {
      expect(formatClock(DateTime(2026, 7, 30, 0, 0)), '00:00');
    });

    test('formata o último minuto do dia como 23:59', () {
      expect(formatClock(DateTime(2026, 7, 30, 23, 59)), '23:59');
    });

    test('ignora os segundos do instante', () {
      expect(formatClock(DateTime(2026, 7, 30, 9, 5, 59)), '09:05');
    });
  });

  group('parseDurationInput', () {
    test('devolve a duração correspondente a minutos e segundos', () {
      expect(
        parseDurationInput(4, 12),
        const Duration(minutes: 4, seconds: 12),
      );
    });

    test('devolve duração zero quando minutos e segundos são zero', () {
      expect(parseDurationInput(0, 0), Duration.zero);
    });

    test('normaliza segundos maiores que 59 somando aos minutos', () {
      expect(
        parseDurationInput(1, 90),
        const Duration(minutes: 2, seconds: 30),
      );
    });

    test('normaliza segundos equivalentes a uma hora inteira', () {
      expect(parseDurationInput(0, 3600), const Duration(minutes: 60));
    });

    test('trata minutos negativos como zero, preservando os segundos', () {
      expect(parseDurationInput(-1, 30), const Duration(seconds: 30));
    });

    test('trata segundos negativos como zero, preservando os minutos', () {
      expect(parseDurationInput(5, -10), const Duration(minutes: 5));
    });

    test('devolve duração zero quando minutos e segundos são negativos', () {
      expect(parseDurationInput(-3, -45), Duration.zero);
    });

    test('nunca devolve duração negativa', () {
      expect(parseDurationInput(-99, -99).isNegative, isFalse);
    });
  });
}
