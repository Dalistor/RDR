import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/models/timed_item.dart';
import 'package:rdr/services/schedule_parser.dart';

// A programação parseada é definida por quem a produz, o parser; quem
// monta o relatório a partir dela reexporta o tipo por conveniência.
export 'package:rdr/services/schedule_parser.dart' show ParsedSection;

/// Fábrica de itens zerados com `id` único dentro do relatório em montagem.
typedef _CriarItem = TimedItem Function(String label, {bool isSubItem});

/// Monta o [MeetingReport] zerado a partir da programação da semana.
class ReportBuilder {
  const ReportBuilder();

  /// Rótulo do item fixo que abre o relatório.
  static const openingLabel = 'Comentários iniciais';

  /// Rótulo do item fixo que fecha o relatório.
  static const closingLabel = 'Comentários finais';

  static const _presidente = 'Presidente';
  static const _conselho = 'Conselho';
  static const _transicao = 'Transição';

  /// Trecho que identifica a parte de leitura da Bíblia em Tesouros, que é a
  /// exceção da regra de sub-itens da seção.
  static const _leituraDaBiblia = 'Leitura da Bíblia';

  /// Constrói o relatório com os itens fixos e os sub-itens automáticos.
  MeetingReport build({
    required String weekLabel,
    required List<ParsedSection> sections,
  }) {
    var itensCriados = 0;
    TimedItem criarItem(String label, {bool isSubItem = false}) {
      itensCriados++;
      return TimedItem(
        id: 'item-$itensCriados',
        label: label,
        isSubItem: isSubItem,
      );
    }

    final abertura = criarItem(openingLabel);
    final secoesMontadas = [
      for (final secao in sections) _montarSecao(secao, criarItem),
    ];
    final fechamento = criarItem(closingLabel);

    return MeetingReport(
      weekLabel: weekLabel,
      openingComments: abertura,
      sections: secoesMontadas,
      closingComments: fechamento,
    );
  }

  /// Uma seção com o item avulso que a abre, se houver, e cada parte seguida
  /// dos seus sub-itens automáticos.
  MeetingSection _montarSecao(ParsedSection secao, _CriarItem criarItem) {
    final ultimaParte = secao.partTitles.length - 1;
    return MeetingSection(
      kind: secao.kind,
      title: secao.title,
      items: [
        if (secao.kind == SectionKind.christianLife) criarItem(_presidente),
        for (var i = 0; i <= ultimaParte; i++) ...[
          criarItem(secao.partTitles[i]),
          for (final rotulo in _subItensDaParte(
            kind: secao.kind,
            parte: secao.partTitles[i],
            ehUltimaParte: i == ultimaParte,
          ))
            criarItem(rotulo, isSubItem: true),
        ],
      ],
    );
  }

  /// Sub-itens automáticos de uma parte, conforme a seção a que ela pertence.
  ///
  /// A última parte de Nossa Vida Cristã não recebe nenhum: ela é seguida
  /// direto pelos comentários finais.
  List<String> _subItensDaParte({
    required SectionKind kind,
    required String parte,
    required bool ehUltimaParte,
  }) {
    switch (kind) {
      case SectionKind.treasures:
        return parte.contains(_leituraDaBiblia)
            ? const [_conselho, _transicao]
            : const [_presidente];
      case SectionKind.ministry:
        return const [_conselho, _transicao];
      case SectionKind.christianLife:
        return ehUltimaParte ? const [] : const [_presidente];
    }
  }
}
