import 'package:rdr/models/json_decoding.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/models/timed_item.dart';

/// Uma das três seções da reunião, com os itens cronometráveis que a compõem.
class MeetingSection {
  const MeetingSection({
    required this.kind,
    required this.title,
    required this.items,
  });

  /// Qual das três seções fixas é esta.
  final SectionKind kind;

  /// Título exibido em caixa alta, ex.: `TESOUROS DA PALAVRA DE DEUS`.
  final String title;

  /// Partes e sub-itens da seção, na ordem em que são cronometrados.
  final List<TimedItem> items;

  /// Cópia trocando apenas os campos informados.
  MeetingSection copyWith({
    SectionKind? kind,
    String? title,
    List<TimedItem>? items,
  }) {
    return MeetingSection(
      kind: kind ?? this.kind,
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }

  /// Mapa pronto para `jsonEncode`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'title': title,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };

  /// Reconstrói a seção a partir do mapa produzido por [toJson].
  static MeetingSection fromJson(Object? json) {
    const contexto = 'Seção do relatório';
    final map = readJsonMap(json, contexto);
    return MeetingSection(
      kind: SectionKind.fromName(readField<String>(map, 'kind', contexto)),
      title: readField<String>(map, 'title', contexto),
      items: readList(map, 'items', contexto, TimedItem.fromJson),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MeetingSection &&
        other.kind == kind &&
        other.title == title &&
        _mesmosItens(other.items, items);
  }

  @override
  int get hashCode => Object.hash(kind, title, Object.hashAll(items));

  @override
  String toString() =>
      'MeetingSection(kind: $kind, title: $title, items: $items)';
}

bool _mesmosItens(List<TimedItem> a, List<TimedItem> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
