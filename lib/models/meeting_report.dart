import 'package:rdr/models/json_decoding.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/timed_item.dart';

/// O relatório inteiro de uma reunião: itens fixos, seções e estado do
/// cronômetro.
class MeetingReport {
  const MeetingReport({
    required this.weekLabel,
    required this.openingComments,
    required this.sections,
    required this.closingComments,
    this.startedAt,
    this.endedAt,
    this.runningItemId,
    this.selectedItemId,
  });

  /// Rótulo da semana vindo do wol.jw.org, ex.: `27 de julho–2 de agosto`.
  final String weekLabel;

  /// Relógio do sistema no primeiro início do cronômetro.
  final DateTime? startedAt;

  /// Relógio do sistema no encerramento da reunião.
  final DateTime? endedAt;

  /// Item fixo que abre o relatório.
  final TimedItem openingComments;

  /// As seções da reunião, na ordem em que acontecem.
  final List<MeetingSection> sections;

  /// Item fixo que fecha o relatório.
  final TimedItem closingComments;

  /// Item que está correndo agora; `null` quando nada corre.
  final String? runningItemId;

  /// Item destacado na tela — independente do que está correndo.
  final String? selectedItemId;

  /// Todos os itens na ordem canônica percorrida pelo botão Próximo e pelas
  /// setas: abertura, itens de cada seção, fechamento.
  List<TimedItem> get orderedItems => [
    openingComments,
    for (final section in sections) ...section.items,
    closingComments,
  ];

  /// O item de [id] em qualquer posição — fixo, parte ou sub-item —, ou `null`
  /// se ele não existir no relatório.
  TimedItem? itemById(String id) {
    for (final item in orderedItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Cópia trocando apenas os campos informados.
  ///
  /// Os campos anuláveis não são apagados passando `null`: use as flags
  /// `clearX` correspondentes.
  MeetingReport copyWith({
    String? weekLabel,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? endedAt,
    bool clearEndedAt = false,
    TimedItem? openingComments,
    List<MeetingSection>? sections,
    TimedItem? closingComments,
    String? runningItemId,
    bool clearRunningItemId = false,
    String? selectedItemId,
    bool clearSelectedItemId = false,
  }) {
    return MeetingReport(
      weekLabel: weekLabel ?? this.weekLabel,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      openingComments: openingComments ?? this.openingComments,
      sections: sections ?? this.sections,
      closingComments: closingComments ?? this.closingComments,
      runningItemId: clearRunningItemId
          ? null
          : (runningItemId ?? this.runningItemId),
      selectedItemId: clearSelectedItemId
          ? null
          : (selectedItemId ?? this.selectedItemId),
    );
  }

  /// Mapa pronto para `jsonEncode` — é o que vai para o `shared_preferences`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'weekLabel': weekLabel,
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'openingComments': openingComments.toJson(),
    'sections': sections
        .map((section) => section.toJson())
        .toList(growable: false),
    'closingComments': closingComments.toJson(),
    'runningItemId': runningItemId,
    'selectedItemId': selectedItemId,
  };

  /// Reconstrói o relatório a partir do mapa produzido por [toJson].
  ///
  /// Lança [ReportDecodeException] se o JSON estiver malformado, faltar campo
  /// obrigatório ou algum valor vier com o tipo errado.
  static MeetingReport fromJson(Object? json) {
    const contexto = 'Relatório da reunião';
    final map = readJsonMap(json, contexto);
    return MeetingReport(
      weekLabel: readField<String>(map, 'weekLabel', contexto),
      startedAt: readOptionalDateTime(map, 'startedAt', contexto),
      endedAt: readOptionalDateTime(map, 'endedAt', contexto),
      openingComments: TimedItem.fromJson(map['openingComments']),
      sections: readList(map, 'sections', contexto, MeetingSection.fromJson),
      closingComments: TimedItem.fromJson(map['closingComments']),
      runningItemId: readOptionalString(map, 'runningItemId', contexto),
      selectedItemId: readOptionalString(map, 'selectedItemId', contexto),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MeetingReport &&
        other.weekLabel == weekLabel &&
        other.startedAt == startedAt &&
        other.endedAt == endedAt &&
        other.openingComments == openingComments &&
        other.closingComments == closingComments &&
        other.runningItemId == runningItemId &&
        other.selectedItemId == selectedItemId &&
        _mesmasSecoes(other.sections, sections);
  }

  @override
  int get hashCode => Object.hash(
    weekLabel,
    startedAt,
    endedAt,
    openingComments,
    closingComments,
    runningItemId,
    selectedItemId,
    Object.hashAll(sections),
  );

  @override
  String toString() =>
      'MeetingReport(weekLabel: $weekLabel, startedAt: $startedAt, '
      'endedAt: $endedAt, runningItemId: $runningItemId, '
      'selectedItemId: $selectedItemId, sections: ${sections.length})';
}

bool _mesmasSecoes(List<MeetingSection> a, List<MeetingSection> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
