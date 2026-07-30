const int _secondsPerMinute = 60;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formata [duration] como `MM:SS`, sempre com dois dígitos em cada campo.
///
/// Os minutos nunca viram horas: uma reunião de 1h05 sai como `65:00`.
/// Milissegundos são truncados, nunca arredondados para cima, e duração
/// negativa é tratada como zero — o relatório jamais mostra sinal de menos.
String formatDuration(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final minutes = safe.inMinutes;
  final seconds = safe.inSeconds - minutes * _secondsPerMinute;
  return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}

/// Formata o horário de [moment] como `HH:MM` em 24 horas.
///
/// Usado nas linhas `Início da reunião` e `Fim da reunião` do relatório.
/// Os segundos do instante são ignorados.
String formatClock(DateTime moment) {
  return '${_twoDigits(moment.hour)}:${_twoDigits(moment.minute)}';
}

/// Converte a entrada de dois campos numéricos do diálogo de edição
/// em uma [Duration].
///
/// Segundos a partir de 60 são normalizados somando aos minutos
/// (`1` min e `90` s viram 2 min e 30 s). Cada valor negativo é tratado
/// como zero, de modo que o resultado nunca é uma duração negativa.
Duration parseDurationInput(int minutes, int seconds) {
  return Duration(
    minutes: minutes < 0 ? 0 : minutes,
    seconds: seconds < 0 ? 0 : seconds,
  );
}
