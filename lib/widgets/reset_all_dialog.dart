import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// Pede confirmação para descartar o relatório inteiro e devolve `true` se o
/// usuário confirmar.
///
/// É a ação mais destrutiva do app: apaga a lista, os tempos e os horários da
/// memória e do disco, sem desfazer. Por isso o texto é explícito sobre o que
/// vai embora e lembra de gerar o print antes.
Future<bool> showResetAllDialog(BuildContext context) async {
  final bool? resposta = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Reiniciar tudo?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'A lista da reunião, todos os tempos cronometrados e os '
              'horários de início e fim são apagados.',
              style: TextStyle(fontSize: 14, height: 1.35),
            ),
            SizedBox(height: 8),
            Text(
              'Não dá para desfazer. Se ainda não exportou o relatório, '
              'cancele e gere o print antes.',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppTheme.christianLifeColor,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.christianLifeColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reiniciar'),
          ),
        ],
      );
    },
  );

  return resposta ?? false;
}
