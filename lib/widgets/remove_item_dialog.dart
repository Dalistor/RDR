import 'package:flutter/material.dart';

import '../models/timed_item.dart';
import '../utils/app_theme.dart';
import '../utils/time_format.dart';

/// Pede confirmação para remover [item] e devolve `true` se o usuário
/// confirmar.
///
/// A mensagem sempre diz quanto tempo vai embora junto: a remoção apaga o
/// cronometrado daquele item e não há como desfazer no meio da reunião.
Future<bool> showRemoveItemDialog({
  required BuildContext context,
  required TimedItem item,
}) async {
  final Duration perdido = item.effectiveElapsed(DateTime.now());

  final bool? resposta = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Remover o item?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '"${item.label}" sai da lista.',
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              'O tempo cronometrado desse item '
              '(${formatDuration(perdido)}) será perdido e não dá para '
              'desfazer.',
              style: const TextStyle(
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
            child: const Text('Remover'),
          ),
        ],
      );
    },
  );

  return resposta ?? false;
}
