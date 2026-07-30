import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/widgets/control_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> montar(
    WidgetTester tester, {
    required bool isRunning,
    required bool hasStarted,
    required bool hasEnded,
    required double largura,
  }) async {
    tester.view.physicalSize = Size(largura, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                const Spacer(),
                ControlPanel(
                  isRunning: isRunning,
                  hasStarted: hasStarted,
                  hasEnded: hasEnded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('parado, tela estreita: Iniciar + Iniciar reunião', (t) async {
    await montar(
      t,
      isRunning: false,
      hasStarted: false,
      hasEnded: false,
      largura: 320,
    );
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('Iniciar reunião'), findsOneWidget);
    expect(find.text('Zerar parte'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('correndo: o alvo central vira Próximo', (t) async {
    await montar(
      t,
      isRunning: true,
      hasStarted: true,
      hasEnded: false,
      largura: 320,
    );
    expect(find.text('Próximo'), findsOneWidget);
    expect(find.text('Encerrar reunião'), findsOneWidget);
    expect(find.text('Pausar'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('encerrada: central desabilitado, setas e zerar ativos', (
    t,
  ) async {
    await montar(
      t,
      isRunning: false,
      hasStarted: true,
      hasEnded: true,
      largura: 320,
    );
    expect(find.text('Reunião encerrada'), findsOneWidget);
    final central = t.widget<FilledButton>(
      find.ancestor(
        of: find.text('Iniciar'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(central.onPressed, isNull);
    final zerar = t.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Zerar parte'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(zerar.onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });
}
