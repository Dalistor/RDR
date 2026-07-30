import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/timed_item.dart';
import '../utils/app_theme.dart';
import '../utils/time_format.dart';

/// O que o usuário confirmou no diálogo de edição: o novo texto do item e o
/// novo tempo acumulado.
@immutable
class ItemEdit {
  const ItemEdit({required this.label, required this.elapsed});

  /// Texto do item, já aparado.
  final String label;

  /// Tempo acumulado escolhido, vindo de `parseDurationInput`.
  final Duration elapsed;
}

/// Abre o diálogo de edição de um item e devolve o resultado, ou `null` se o
/// usuário cancelar.
///
/// A edição é permitida a qualquer momento, **inclusive com o item correndo**:
/// nesse caso o tempo mostrado já inclui o trecho aberto e quem aplica a
/// mudança (`setElapsed`) reancora a contagem no novo valor.
Future<ItemEdit?> showEditItemDialog({
  required BuildContext context,
  required TimedItem item,
}) {
  return showDialog<ItemEdit>(
    context: context,
    builder: (BuildContext dialogContext) => _EditItemDialog(item: item),
  );
}

class _EditItemDialog extends StatefulWidget {
  const _EditItemDialog({required this.item});

  final TimedItem item;

  @override
  State<_EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<_EditItemDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _minutos;
  late final TextEditingController _segundos;

  @override
  void initState() {
    super.initState();
    // O valor pré-preenchido é o mesmo que a lista mostra no momento do toque
    // longo — o acumulado somado ao trecho ainda aberto, se o item corre.
    final Duration atual = widget.item.effectiveElapsed(DateTime.now());
    final int minutos = atual.isNegative ? 0 : atual.inMinutes;
    final int segundos = atual.isNegative ? 0 : atual.inSeconds - minutos * 60;

    _nome = TextEditingController(text: widget.item.label);
    _minutos = TextEditingController(text: '$minutos');
    _segundos = TextEditingController(text: segundos.toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _nome.dispose();
    _minutos.dispose();
    _segundos.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      ItemEdit(
        label: _nome.text.trim(),
        elapsed: parseDurationInput(
          int.tryParse(_minutos.text.trim()) ?? 0,
          int.tryParse(_segundos.text.trim()) ?? 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool correndo = widget.item.runningSince != null;

    return AlertDialog(
      title: const Text('Editar item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _nome,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nome do item',
                  border: OutlineInputBorder(),
                ),
                validator: (String? valor) =>
                    (valor == null || valor.trim().isEmpty)
                    ? 'Informe um nome.'
                    : null,
              ),
              const SizedBox(height: 16),
              const Text(
                'Tempo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _CampoDeTempo(
                      controller: _minutos,
                      rotulo: 'Minutos',
                      // Uma reunião inteira passa de 100 minutos; três dígitos
                      // cobrem qualquer item sem cortar digitação legítima.
                      maxLength: 3,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CampoDeTempo(
                      controller: _segundos,
                      rotulo: 'Segundos',
                      maxLength: 3,
                      onSubmitted: (_) => _salvar(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Segundos a partir de 60 viram minutos.',
                style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
              ),
              if (correndo) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: AppTheme.ministryColor,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Este item está correndo. A contagem continua a partir '
                        'do tempo informado.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppTheme.ministryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
          onPressed: _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Campo numérico de minutos ou de segundos.
///
/// Aceita só dígitos; vazio conta como zero, para o usuário poder apagar o
/// conteúdo e digitar de novo sem que o formulário reclame.
class _CampoDeTempo extends StatelessWidget {
  const _CampoDeTempo({
    required this.controller,
    required this.rotulo,
    required this.maxLength,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String rotulo;
  final int maxLength;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      textAlign: TextAlign.center,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        labelText: rotulo,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
