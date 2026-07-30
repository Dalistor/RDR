import 'package:flutter/material.dart';

import '../models/section_kind.dart';
import '../utils/app_theme.dart';

/// Cabeçalho de uma das três seções da reunião.
///
/// Widget puro de apresentação: recebe tudo por parâmetro, não lê provider e
/// não guarda estado. É usado tanto pela lista da tela quanto pelo print do
/// relatório, por isso não depende de nada além do que chega no construtor.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.kind,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(4, 16, 4, 8),
  });

  /// Seção a que este cabeçalho pertence — define a cor do título.
  final SectionKind kind;

  /// Título exibido; é sempre renderizado em caixa alta.
  final String title;

  /// Espaçamento externo, ajustável pelo print para casar com o layout.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Sem ícone: a cor do título já distingue as três seções, na tela e no
    // print, e o texto ganha a largura inteira da linha.
    return Padding(
      padding: padding,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.sectionColor(kind),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          height: 1.2,
        ),
      ),
    );
  }
}
