import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_theme.dart';

/// O que o usuário confirmou no diálogo de horário da reunião.
///
/// Um retorno `null` do diálogo significa **cancelou**; um [MeetingTimeEdit]
/// com [valor] nulo significa **limpar o horário**. São coisas diferentes, e é
/// por isso que o resultado não é um `DateTime?` cru.
@immutable
class MeetingTimeEdit {
  const MeetingTimeEdit(this.valor);

  /// O horário escolhido, ou `null` para apagar o que estava gravado.
  final DateTime? valor;
}

/// Abre o diálogo de edição de um dos horários da reunião — o início ou o fim.
///
/// [titulo] identifica qual dos dois está sendo editado. [atual] pré-preenche
/// os campos e decide se o botão `Limpar` aparece: não há o que limpar num
/// horário que ainda não foi gravado.
Future<MeetingTimeEdit?> showEditMeetingTimeDialog({
  required BuildContext context,
  required String titulo,
  required DateTime? atual,
}) {
  return showDialog<MeetingTimeEdit>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _EditMeetingTimeDialog(titulo: titulo, atual: atual),
  );
}

class _EditMeetingTimeDialog extends StatefulWidget {
  const _EditMeetingTimeDialog({required this.titulo, required this.atual});

  final String titulo;
  final DateTime? atual;

  @override
  State<_EditMeetingTimeDialog> createState() => _EditMeetingTimeDialogState();
}

class _EditMeetingTimeDialogState extends State<_EditMeetingTimeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _hora;
  late final TextEditingController _minuto;

  @override
  void initState() {
    super.initState();
    final DateTime? atual = widget.atual;
    _hora = TextEditingController(
      text: atual == null ? '' : atual.hour.toString().padLeft(2, '0'),
    );
    _minuto = TextEditingController(
      text: atual == null ? '' : atual.minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hora.dispose();
    _minuto.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final int hora = int.tryParse(_hora.text.trim()) ?? 0;
    final int minuto = int.tryParse(_minuto.text.trim()) ?? 0;
    // A data vem do horário que já estava gravado; sem ele, é a de hoje. O app
    // só grava hora e minuto, mas o model guarda um DateTime completo.
    final DateTime base = widget.atual ?? DateTime.now();
    Navigator.of(context).pop(
      MeetingTimeEdit(DateTime(base.year, base.month, base.day, hora, minuto)),
    );
  }

  void _limpar() => Navigator.of(context).pop(const MeetingTimeEdit(null));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _CampoDeHorario(
                    controller: _hora,
                    rotulo: 'Hora',
                    maximo: 23,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CampoDeHorario(
                    controller: _minuto,
                    rotulo: 'Minuto',
                    maximo: 59,
                    onSubmitted: (_) => _salvar(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Formato de 24 horas. Campo vazio conta como zero.',
              style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.atual != null)
          TextButton(
            onPressed: _limpar,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.christianLifeColor,
            ),
            child: const Text('Limpar'),
          ),
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

/// Campo numérico de hora ou de minuto, limitado a [maximo].
class _CampoDeHorario extends StatelessWidget {
  const _CampoDeHorario({
    required this.controller,
    required this.rotulo,
    required this.maximo,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String rotulo;

  /// Maior valor aceito: 23 para hora, 59 para minuto.
  final int maximo;

  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
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
      // Vazio é válido e vira zero, para o usuário poder apagar e redigitar sem
      // o formulário reclamar no meio do caminho.
      validator: (String? valor) {
        final String texto = (valor ?? '').trim();
        if (texto.isEmpty) return null;
        final int? numero = int.tryParse(texto);
        if (numero == null || numero > maximo) return '0 a $maximo';
        return null;
      },
    );
  }
}
