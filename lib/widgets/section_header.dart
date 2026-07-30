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

  /// Seção a que este cabeçalho pertence — define a cor e o ícone.
  final SectionKind kind;

  /// Título exibido; é sempre renderizado em caixa alta.
  final String title;

  /// Espaçamento externo, ajustável pelo print para casar com o layout.
  final EdgeInsetsGeometry padding;

  /// Ícone que representa a seção, aproximado entre os do Material:
  /// losango para Tesouros, espiga para Faça Seu Melhor, ovelha para
  /// Nossa Vida Cristã.
  static IconData iconFor(SectionKind kind) => switch (kind) {
    SectionKind.treasures => Icons.diamond_outlined,
    SectionKind.ministry => Icons.grass,
    SectionKind.christianLife => Icons.pets,
  };

  @override
  Widget build(BuildContext context) {
    final Color color = AppTheme.sectionColor(kind);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(iconFor(kind), size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
