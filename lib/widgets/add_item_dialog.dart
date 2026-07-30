import 'package:flutter/material.dart';

import '../models/timed_item.dart';
import '../utils/app_theme.dart';

/// O item que o usuário pediu para inserir: o texto e se ele é uma parte ou um
/// sub-item.
@immutable
class NewItemDraft {
  const NewItemDraft({required this.label, required this.isSubItem});

  /// Texto do item novo, já aparado.
  final String label;

  /// `true` insere como sub-item (indentado, com marcador); `false`, como
  /// parte.
  final bool isSubItem;
}

/// Abre o diálogo de inclusão de um item logo abaixo de [after] e devolve o
/// rascunho confirmado, ou `null` se o usuário cancelar.
Future<NewItemDraft?> showAddItemDialog({
  required BuildContext context,
  required TimedItem after,
}) {
  return showDialog<NewItemDraft>(
    context: context,
    builder: (BuildContext dialogContext) => _AddItemDialog(after: after),
  );
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog({required this.after});

  /// Item de origem: o novo entra imediatamente abaixo dele, na mesma seção.
  final TimedItem after;

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nome = TextEditingController();

  late bool _isSubItem;

  @override
  void initState() {
    super.initState();
    // Abaixo de um sub-item quase sempre vem outro sub-item (Conselho e
    // Transição andam juntos); abaixo de uma parte, outra parte.
    _isSubItem = widget.after.isSubItem;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _adicionar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      NewItemDraft(label: _nome.text.trim(), isSubItem: _isSubItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar abaixo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'O item novo entra logo abaixo de "${widget.after.label}", '
                'zerado.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nome,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _adicionar(),
                decoration: const InputDecoration(
                  labelText: 'Nome do item',
                  hintText: 'Ex.: Presidente',
                  border: OutlineInputBorder(),
                ),
                validator: (String? valor) =>
                    (valor == null || valor.trim().isEmpty)
                    ? 'Informe um nome.'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tipo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Parte'),
                      icon: Icon(Icons.subject),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Sub-item'),
                      icon: Icon(Icons.subdirectory_arrow_right),
                    ),
                  ],
                  selected: <bool>{_isSubItem},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<bool> escolha) {
                    setState(() => _isSubItem = escolha.first);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.treasuresColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
          ),
          onPressed: _adicionar,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
