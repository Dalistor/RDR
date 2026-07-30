import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'screens/meeting_screen.dart';
import 'utils/app_theme.dart';

const Locale _ptBr = Locale('pt', 'BR');

Future<void> main() async {
  // Toda a interface e o relatório são em português: fixa o locale padrão do
  // `intl` e carrega os dados de data de pt_BR antes da primeira formatação.
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  runApp(const ProviderScope(child: RdrApp()));
}

class RdrApp extends StatelessWidget {
  const RdrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDR',
      debugShowCheckedModeBanner: false,
      locale: _ptBr,
      theme: AppTheme.light,
      // Tema claro apenas — sem `darkTheme`.
      themeMode: ThemeMode.light,
      home: const MeetingScreen(),
    );
  }
}
