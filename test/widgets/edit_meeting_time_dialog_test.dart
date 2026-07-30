import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/widgets/edit_meeting_time_dialog.dart';

/// Captura o que o diálogo devolveu.
///
/// `fechou` distingue os dois nulos possíveis: o de "ainda aberto" e o de
/// "cancelou". Sem isso, um teste de cancelamento passaria mesmo com o diálogo
/// travado na tela.
class Captura {
  MeetingTimeEdit? resultado;
  bool fechou = false;
}

/// Monta um botão que abre o diálogo e o toca.
///
/// O diálogo precisa de um `Navigator` de verdade para o `pop` devolver valor,
/// então não dá para instanciá-lo solto. O `pump` com duração substitui o
/// `pumpAndSettle`: o campo com `autofocus` tem cursor piscando, uma animação
/// que nunca estabiliza.
Future<Captura> abrir(
  WidgetTester tester, {
  required DateTime? atual,
  String titulo = 'Início da reunião',
}) async {
  final Captura captura = Captura();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () async {
              captura.resultado = await showEditMeetingTimeDialog(
                context: context,
                titulo: titulo,
                atual: atual,
              );
              captura.fechou = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return captura;
}

/// Toca num dos botões do diálogo e deixa o `pop` propagar.
Future<void> tocar(WidgetTester tester, String rotulo) async {
  await tester.tap(find.text(rotulo));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  final DateTime vinteHoras = DateTime(2026, 7, 30, 20, 5);

  testWidgets('pré-preenche os campos com o horário atual', (t) async {
    await abrir(t, atual: vinteHoras);

    expect(find.widgetWithText(TextFormField, '20'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '05'), findsOneWidget);
  });

  testWidgets('sem horário gravado não há o que limpar', (t) async {
    await abrir(t, atual: null);

    expect(find.text('Limpar'), findsNothing);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
  });

  testWidgets('com horário gravado, o Limpar aparece', (t) async {
    await abrir(t, atual: vinteHoras);

    expect(find.text('Limpar'), findsOneWidget);
  });

  testWidgets('hora acima de 23 barra o salvar e mostra a faixa aceita', (
    t,
  ) async {
    final Captura captura = await abrir(t, atual: vinteHoras);

    await t.enterText(find.widgetWithText(TextFormField, '20'), '25');
    await tocar(t, 'Salvar');

    expect(find.text('0 a 23'), findsOneWidget);
    expect(captura.fechou, isFalse, reason: 'o diálogo não pode ter fechado');
  });

  testWidgets('minuto acima de 59 barra o salvar', (t) async {
    final Captura captura = await abrir(t, atual: vinteHoras);

    await t.enterText(find.widgetWithText(TextFormField, '05'), '70');
    await tocar(t, 'Salvar');

    expect(find.text('0 a 59'), findsOneWidget);
    expect(captura.fechou, isFalse);
  });

  testWidgets('salvar devolve o horário digitado, preservando a data', (
    t,
  ) async {
    final Captura captura = await abrir(
      t,
      atual: vinteHoras,
      titulo: 'Fim da reunião',
    );

    await t.enterText(find.widgetWithText(TextFormField, '20'), '21');
    await t.enterText(find.widgetWithText(TextFormField, '05'), '39');
    await tocar(t, 'Salvar');

    expect(captura.resultado?.valor, DateTime(2026, 7, 30, 21, 39));
  });

  testWidgets('campo vazio conta como zero', (t) async {
    final Captura captura = await abrir(t, atual: vinteHoras);

    await t.enterText(find.widgetWithText(TextFormField, '05'), '');
    await tocar(t, 'Salvar');

    expect(captura.resultado?.valor, DateTime(2026, 7, 30, 20, 0));
  });

  testWidgets('Limpar devolve valor nulo, e não é o mesmo que cancelar', (
    t,
  ) async {
    final Captura captura = await abrir(t, atual: vinteHoras);

    await tocar(t, 'Limpar');

    expect(captura.fechou, isTrue);
    expect(captura.resultado, isNotNull, reason: 'limpar não é cancelar');
    expect(captura.resultado!.valor, isNull);
  });

  testWidgets('Cancelar devolve nulo', (t) async {
    final Captura captura = await abrir(t, atual: vinteHoras);

    await tocar(t, 'Cancelar');

    expect(captura.fechou, isTrue);
    expect(captura.resultado, isNull);
  });
}
