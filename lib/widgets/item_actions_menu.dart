import 'package:flutter/material.dart';

import '../models/timed_item.dart';
import '../providers/meeting_provider.dart';
import '../utils/app_theme.dart';
import '../utils/time_format.dart';
import 'add_item_dialog.dart';
import 'edit_item_dialog.dart';
import 'remove_item_dialog.dart';

/// As três operações de manutenção da lista, oferecidas no toque longo.
enum _ItemAction { edit, addBelow, remove }

/// Abre o menu de manutenção de [item] — Editar, Adicionar abaixo e Remover —
/// e executa a operação escolhida no [notifier].
///
/// É o único ponto de entrada dos diálogos de manutenção: a tela só precisa
/// ligar o toque longo da linha aqui. Toda a regra continua nos services,
/// atrás do notifier; aqui só se coleta o que o usuário quis e se despacha.
///
/// [canRemove] `false` esconde a remoção. É o caso dos Comentários iniciais e
/// finais, que são a moldura fixa do relatório e vivem fora das seções.
Future<void> showItemMaintenanceMenu({
  required BuildContext context,
  required MeetingNotifier notifier,
  required TimedItem item,
  bool canRemove = true,
}) async {
  final _ItemAction? acao = await showModalBottomSheet<_ItemAction>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext sheetContext) =>
        _MenuDoItem(item: item, canRemove: canRemove),
  );

  if (acao == null || !context.mounted) return;

  switch (acao) {
    case _ItemAction.edit:
      final ItemEdit? edicao = await showEditItemDialog(
        context: context,
        item: item,
      );
      if (edicao == null) return;
      await notifier.rename(item.id, edicao.label);
      // `setElapsed` vem depois de propósito: com o item correndo ele reancora
      // o trecho aberto, para a contagem seguir a partir do novo valor.
      await notifier.setElapsed(item.id, edicao.elapsed);

    case _ItemAction.addBelow:
      final NewItemDraft? novo = await showAddItemDialog(
        context: context,
        after: item,
      );
      if (novo == null) return;
      await notifier.addItem(
        afterId: item.id,
        label: novo.label,
        isSubItem: novo.isSubItem,
      );

    case _ItemAction.remove:
      final bool confirmado = await showRemoveItemDialog(
        context: context,
        item: item,
      );
      if (confirmado) await notifier.removeItem(item.id);
  }
}

/// Folha inferior com as opções de manutenção do item.
class _MenuDoItem extends StatelessWidget {
  const _MenuDoItem({required this.item, required this.canRemove});

  final TimedItem item;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatDuration(item.effectiveElapsed(DateTime.now())),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF555555),
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          _OpcaoDoMenu(
            icone: Icons.edit_outlined,
            cor: AppTheme.treasuresColor,
            titulo: 'Editar',
            descricao: 'Mudar o nome e o tempo, mesmo com o item correndo.',
            acao: _ItemAction.edit,
          ),
          _OpcaoDoMenu(
            icone: Icons.playlist_add,
            cor: AppTheme.ministryColor,
            titulo: 'Adicionar abaixo',
            descricao: 'Inserir uma parte ou um sub-item logo depois deste.',
            acao: _ItemAction.addBelow,
          ),
          if (canRemove)
            _OpcaoDoMenu(
              icone: Icons.delete_outline,
              cor: AppTheme.christianLifeColor,
              titulo: 'Remover',
              descricao: 'Tirar o item da lista, junto com o tempo dele.',
              acao: _ItemAction.remove,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Uma linha do menu. Alvo de toque bem acima dos 48dp mínimos: o menu é usado
/// no escuro, durante a reunião.
class _OpcaoDoMenu extends StatelessWidget {
  const _OpcaoDoMenu({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.descricao,
    required this.acao,
  });

  final IconData icone;
  final Color cor;
  final String titulo;
  final String descricao;
  final _ItemAction acao;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 12,
      leading: Icon(icone, color: cor),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
      subtitle: Text(
        descricao,
        style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
      ),
      onTap: () => Navigator.of(context).pop(acao),
    );
  }
}
