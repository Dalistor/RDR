import 'package:rdr/models/json_decoding.dart';

/// Um item cronometrável do relatório: item fixo, parte da programação ou
/// sub-item (Presidente, Conselho, Transição).
class TimedItem {
  const TimedItem({
    required this.id,
    required this.label,
    this.elapsed = Duration.zero,
    this.runningSince,
    this.isSubItem = false,
  });

  /// Identificador estável e único dentro de um relatório.
  final String id;

  /// Texto exibido, ex.: `1. Ele pregou com coragem`, `Presidente`.
  final String label;

  /// Soma dos trechos de tempo já fechados.
  final Duration elapsed;

  /// Instante em que o trecho aberto começou; `null` quando o item está parado.
  final DateTime? runningSince;

  /// `true` renderiza indentado com marcador.
  final bool isSubItem;

  /// Cópia trocando apenas os campos informados.
  ///
  /// Como `runningSince` é anulável, passar `null` não o apaga — use
  /// [clearRunningSince] para parar o item.
  TimedItem copyWith({
    String? id,
    String? label,
    Duration? elapsed,
    DateTime? runningSince,
    bool clearRunningSince = false,
    bool? isSubItem,
  }) {
    return TimedItem(
      id: id ?? this.id,
      label: label ?? this.label,
      elapsed: elapsed ?? this.elapsed,
      runningSince: clearRunningSince ? null : (runningSince ?? this.runningSince),
      isSubItem: isSubItem ?? this.isSubItem,
    );
  }

  /// Tempo decorrido considerando o trecho ainda aberto, se houver.
  Duration effectiveElapsed(DateTime now) {
    final aberto = runningSince;
    if (aberto == null) return elapsed;
    return elapsed + now.difference(aberto);
  }

  /// Mapa pronto para `jsonEncode`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'elapsedMicroseconds': elapsed.inMicroseconds,
    'runningSince': runningSince?.toIso8601String(),
    'isSubItem': isSubItem,
  };

  /// Reconstrói um item a partir do mapa produzido por [toJson].
  static TimedItem fromJson(Object? json) {
    const contexto = 'Item do relatório';
    final map = readJsonMap(json, contexto);
    return TimedItem(
      id: readField<String>(map, 'id', contexto),
      label: readField<String>(map, 'label', contexto),
      elapsed: Duration(
        microseconds: readField<int>(map, 'elapsedMicroseconds', contexto),
      ),
      runningSince: readOptionalDateTime(map, 'runningSince', contexto),
      isSubItem: readField<bool>(map, 'isSubItem', contexto),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimedItem &&
        other.id == id &&
        other.label == label &&
        other.elapsed == elapsed &&
        other.runningSince == runningSince &&
        other.isSubItem == isSubItem;
  }

  @override
  int get hashCode => Object.hash(id, label, elapsed, runningSince, isSubItem);

  @override
  String toString() =>
      'TimedItem(id: $id, label: $label, elapsed: $elapsed, '
      'runningSince: $runningSince, isSubItem: $isSubItem)';
}
