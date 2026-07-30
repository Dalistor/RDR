import 'package:flutter/material.dart';

import '../models/meeting_report.dart';
import '../models/timed_item.dart';
import '../utils/app_theme.dart';
import '../utils/time_format.dart';
import 'item_row.dart';
import 'section_header.dart';

/// O relatório inteiro desenhado em coluna única, para virar imagem.
///
/// É este widget que o `captureFromLongWidget` renderiza **fora da tela**: ele
/// nunca é montado dentro do `MaterialApp`, e por isso precisa bastar a si
/// mesmo. Duas consequências práticas, que não podem ser esquecidas ao mexer
/// aqui:
///
/// - **Nada de `Theme.of`, `MediaQuery.of` ou `Scaffold`.** A captura monta a
///   árvore em um `PipelineOwner` próprio, sem os `InheritedWidget` do app;
///   todas as cores e estilos saem de `app_theme.dart` ou de literais locais.
/// - **Largura fixa ([captureWidth]).** A medição do print acontece com
///   restrições frouxas, então a folha define a própria largura em vez de
///   herdá-la do pai — é o que garante uma imagem única, sem corte, com altura
///   livre para crescer o quanto o relatório precisar.
///
/// Os componentes da lista ([SectionHeader] e [ItemRow]) são reaproveitados em
/// modo estático: sem callbacks, sem destaque de seleção e sem destaque de
/// item correndo — o print é a fotografia do resultado, não da interface.
class ReportSheet extends StatelessWidget {
  const ReportSheet({super.key, required this.report, this.now});

  /// O relatório desenhado.
  final MeetingReport report;

  /// Instante usado para fechar o tempo dos itens que ainda estejam correndo.
  /// Nulo usa o relógio do sistema no momento da renderização.
  final DateTime? now;

  /// Largura lógica da folha. Multiplicada por [capturePixelRatio], dá a
  /// largura em pixels da imagem final.
  static const double captureWidth = 720;

  /// Densidade da captura. Alta de propósito: o print é lido no celular de
  /// quem recebe, com zoom, e o texto precisa sair nítido.
  static const double capturePixelRatio = 3;

  /// Placeholder dos horários ainda não gravados — a linha permanece no print
  /// para deixar explícito que o horário não foi registrado.
  static const String _semHorario = '—';

  static const Color _corDoTexto = Color(0xFF1A1A1A);
  static const Color _corSecundaria = Color(0xFF555555);

  @override
  Widget build(BuildContext context) {
    final DateTime agora = now ?? DateTime.now();

    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        width: captureWidth,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 14,
            color: _corDoTexto,
            decoration: TextDecoration.none,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Relatório da reunião',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.treasuresColor,
                    height: 1.2,
                  ),
                ),
                if (report.weekLabel.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    report.weekLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: _corSecundaria,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE0E0E0),
                ),
                const SizedBox(height: 12),
                _LinhaDeHorario(
                  rotulo: 'Início da reunião:',
                  horario: report.startedAt,
                ),
                const SizedBox(height: 8),
                _linhaDoItem(report.openingComments, agora, null),
                for (final section in report.sections) ...<Widget>[
                  SectionHeader(
                    kind: section.kind,
                    title: section.title,
                    padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
                  ),
                  for (final item in section.items)
                    _linhaDoItem(
                      item,
                      agora,
                      AppTheme.sectionColor(section.kind),
                    ),
                ],
                const SizedBox(height: 20),
                _linhaDoItem(report.closingComments, agora, null),
                const SizedBox(height: 12),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE0E0E0),
                ),
                const SizedBox(height: 12),
                _LinhaDeHorario(
                  rotulo: 'Fim da reunião:',
                  horario: report.endedAt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Uma linha do relatório em modo estático: sem toque, sem seleção e sem
  /// destaque de item correndo.
  ///
  /// O tempo de um item que ainda esteja rodando é fechado em [agora], para o
  /// print não sair com o cronômetro pela metade.
  Widget _linhaDoItem(TimedItem item, DateTime agora, Color? accent) {
    return ItemRow(
      label: item.label,
      elapsed: item.effectiveElapsed(agora),
      isSubItem: item.isSubItem,
      accentColor: accent ?? AppTheme.treasuresColor,
    );
  }
}

/// Linha `Início da reunião: HH:MM` / `Fim da reunião: HH:MM`.
class _LinhaDeHorario extends StatelessWidget {
  const _LinhaDeHorario({required this.rotulo, required this.horario});

  final String rotulo;

  /// Nulo significa horário não gravado.
  final DateTime? horario;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          rotulo,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ReportSheet._corDoTexto,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          horario == null ? ReportSheet._semHorario : formatClock(horario!),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.treasuresColor,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
