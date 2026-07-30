/// Extração da programação da reunião a partir do HTML do wol.jw.org.
library;

import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' show parse;
import 'package:rdr/models/section_kind.dart';

/// Texto que identifica o cartão da apostila na página da semana; o outro
/// cartão é o de A Sentinela, que não interessa ao app.
const String _mwbCardText = 'Apostila Vida e Ministério';

/// Caminho de um documento do wol, ex.: `/pt/wol/d/r5/lp-t/202026244`.
final RegExp _documentPathPattern = RegExp(r'^/[^/]+/wol/d/r5/[^/]+/\d+$');

/// Sufixo comum das mensagens de erro: o app sempre oferece a saída manual.
const String _layoutHint =
    'O site pode ter mudado de layout — monte a lista de partes manualmente.';

/// O HTML do wol.jw.org não tem a forma esperada.
///
/// A [message] é escrita em português para a UI mostrar direto ao usuário e
/// oferecer a montagem manual da lista de partes.
class ScheduleParseException implements Exception {
  const ScheduleParseException(this.message);

  final String message;

  @override
  String toString() => 'ScheduleParseException: $message';
}

/// Endereço do documento da apostila da semana, mais o rótulo da semana.
class WeekDocumentLink {
  const WeekDocumentLink({required this.documentPath, required this.weekLabel});

  /// Caminho relativo do documento, ex.: `/pt/wol/d/r5/lp-t/202026244`.
  final String documentPath;

  /// Rótulo exibido no relatório, ex.: `27 de julho–2 de agosto`.
  final String weekLabel;
}

/// Uma das três seções da reunião, com os títulos das partes que a compõem.
///
/// É a entrada do montador do relatório: só texto, sem tempos nem ids.
class ParsedSection {
  const ParsedSection({
    required this.kind,
    required this.title,
    required this.partTitles,
  });

  final SectionKind kind;

  /// Título em caixa alta, ex.: `TESOUROS DA PALAVRA DE DEUS`.
  final String title;

  /// Partes já numeradas pelo próprio wol, ex.: `1. Ele pregou com coragem`.
  final List<String> partTitles;
}

/// Lê o HTML do wol.jw.org e devolve a programação da semana.
class ScheduleParser {
  const ScheduleParser();

  /// Acha, na página da semana, o documento da Apostila Vida e Ministério.
  WeekDocumentLink parseWeekPage(String html) {
    final document = parse(html);
    final link = document
        .querySelectorAll('a[href]')
        .where(_isMwbDocumentLink)
        .firstOrNull;
    if (link == null) {
      throw const ScheduleParseException(
        'Não achei o link da Apostila Vida e Ministério na página do '
        'wol.jw.org. $_layoutHint',
      );
    }
    final weekLabel = _normalizeText(
      link.querySelector('.cardLine1')?.text ?? '',
    );
    if (weekLabel.isEmpty) {
      throw const ScheduleParseException(
        'Achei a apostila, mas não o rótulo da semana na página do '
        'wol.jw.org. $_layoutHint',
      );
    }
    return WeekDocumentLink(
      documentPath: link.attributes['href']!,
      weekLabel: weekLabel,
    );
  }

  /// Lê o documento da apostila e devolve as três seções com suas partes.
  ///
  /// A duração prevista (`(10 min)`) existe no HTML e é ignorada de propósito.
  List<ParsedSection> parseDocument(String html) {
    final drafts = <_SectionDraft>[];
    // Os títulos vêm na ordem do documento: cada `h2` colorido abre uma seção
    // e os `h3` seguintes pertencem a ela.
    for (final heading in parse(html).querySelectorAll('h2, h3')) {
      final kind = _sectionKindOf(heading);
      final text = _normalizeText(heading.text);
      if (heading.localName == 'h2') {
        if (kind == null) continue; // texto bíblico da semana
        drafts.add(_SectionDraft(kind, text));
      } else if (drafts.isNotEmpty && _isPartOf(drafts.last, kind, text)) {
        drafts.last.partTitles.add(text);
      }
    }
    if (drafts.isEmpty) {
      throw const ScheduleParseException(
        'Não achei as seções da reunião no documento do wol.jw.org. $_layoutHint',
      );
    }
    return drafts.map((draft) => draft.toSection()).toList(growable: false);
  }
}

/// Deixa o texto do jeito que o relatório mostra: sem entidades pendentes,
/// sem `&nbsp;`, sem quebra de linha interna e sem espaço duplo.
String _normalizeText(String raw) => raw.replaceAll(_whitespaceRun, ' ').trim();

/// O `\s` do Dart já cobre o `&nbsp;` (U+00A0), que o wol usa bastante.
final RegExp _whitespaceRun = RegExp(r'\s+');

/// Toda parte da programação já vem numerada pelo wol: `1. Ele pregou...`.
final RegExp _numberedPart = RegExp(r'^\d+\.\s');

/// Um `h3` é parte da seção aberta quando repete a cor dela. Se o wol deixar
/// de colorir os títulos, a numeração ainda distingue uma parte de um cântico
/// ou dos comentários, e o app continua montando a lista sozinho.
bool _isPartOf(_SectionDraft section, SectionKind? kind, String text) =>
    kind == section.kind || (kind == null && _numberedPart.hasMatch(text));

/// Seção em construção enquanto o documento é percorrido.
class _SectionDraft {
  _SectionDraft(this.kind, this.title);

  final SectionKind kind;
  final String title;
  final List<String> partTitles = <String>[];

  ParsedSection toSection() => ParsedSection(
    kind: kind,
    title: title,
    partTitles: List<String>.unmodifiable(partTitles),
  );
}

/// A cor do título é o que identifica a seção no HTML do wol; um `h2` sem
/// nenhuma dessas classes é o texto bíblico da semana (ex.: `JEREMIAS 20-21`).
const Map<String, SectionKind> _sectionColorClasses = <String, SectionKind>{
  'du-color--teal-700': SectionKind.treasures,
  'du-color--gold-700': SectionKind.ministry,
  'du-color--maroon-600': SectionKind.christianLife,
};

SectionKind? _sectionKindOf(Element heading) {
  for (final entry in _sectionColorClasses.entries) {
    if (heading.classes.contains(entry.key)) return entry.value;
  }
  return null;
}

bool _isMwbDocumentLink(Element anchor) {
  final href = anchor.attributes['href'] ?? '';
  return _documentPathPattern.hasMatch(href) &&
      anchor.text.contains(_mwbCardText);
}
