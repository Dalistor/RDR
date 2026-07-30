import 'package:flutter/material.dart';

import '../utils/time_format.dart';

/// Linha de um item cronometrado: o rótulo à esquerda e o tempo à direita.
///
/// Widget puro de apresentação — recebe tudo por parâmetro, não lê provider e
/// não tem estado. Com [onTap] e [onLongPress] nulos a linha fica puramente
/// estática, que é como o print do relatório a usa.
///
/// Sub-item ([isSubItem] `true`) sai indentado, prefixado por `• ` e com o
/// rótulo seguido de dois-pontos, como nos prints de referência.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.label,
    required this.elapsed,
    this.isSubItem = false,
    this.isSelected = false,
    this.isRunning = false,
    this.accentColor,
    this.onTap,
    this.onLongPress,
  });

  /// Texto do item, ex.: `1. Ele pregou com coragem` ou `Presidente`.
  final String label;

  /// Tempo já decorrido, formatado como `MM:SS`.
  final Duration elapsed;

  /// `true` indenta a linha e a prefixa com o marcador de sub-item.
  final bool isSubItem;

  /// Item selecionado na tela — destaque de seleção (barra lateral).
  ///
  /// É um conceito distinto de [isRunning]: os dois podem estar ativos ao
  /// mesmo tempo e recebem destaques visuais diferentes de propósito.
  final bool isSelected;

  /// Item que está com o cronômetro correndo — destaque de fundo e negrito.
  final bool isRunning;

  /// Cor usada no destaque de "correndo". Por padrão, a cor primária do tema.
  final Color? accentColor;

  /// Toque simples. Nulo deixa a linha estática, sem área de toque.
  final VoidCallback? onTap;

  /// Toque longo, usado pelo menu de manutenção da lista. Nulo desabilita.
  final VoidCallback? onLongPress;

  static const double _subItemIndent = 22;
  static const double _minTouchTarget = 48;

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? Theme.of(context).colorScheme.primary;
    final bool interativa = onTap != null || onLongPress != null;

    final TextStyle labelStyle = TextStyle(
      fontSize: isSubItem ? 13 : 14,
      color: isSubItem ? const Color(0xFF555555) : const Color(0xFF1A1A1A),
      fontWeight: isRunning ? FontWeight.bold : FontWeight.normal,
      height: 1.3,
    );

    final TextStyle timeStyle = TextStyle(
      fontSize: isSubItem ? 13 : 14,
      color: isRunning ? accent : const Color(0xFF1A1A1A),
      fontWeight: isRunning ? FontWeight.bold : FontWeight.w500,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      height: 1.3,
    );

    final Widget conteudo = Container(
      constraints: BoxConstraints(
        minHeight: interativa ? _minTouchTarget : 0,
      ),
      decoration: BoxDecoration(
        // Fundo tingido marca o item que corre; a barra lateral marca o
        // item selecionado. São destaques independentes e acumuláveis.
        color: isRunning ? accent.withValues(alpha: 0.10) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isSelected ? accent : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        left: 8 + (isSubItem ? _subItemIndent : 0),
        right: 8,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              isSubItem ? '• $label:' : label,
              style: labelStyle,
            ),
          ),
          const SizedBox(width: 12),
          Text(formatDuration(elapsed), style: timeStyle),
        ],
      ),
    );

    if (!interativa) return conteudo;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: conteudo,
      ),
    );
  }
}
