import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rdr/providers/dependencies_provider.dart';

/// Batida de 1 em 1 segundo, exclusiva para a UI redesenhar o cronômetro.
///
/// O tick **não** altera o relatório: o tempo exibido é sempre calculado na
/// hora por `TimedItem.effectiveElapsed(DateTime.now())`, a partir dos
/// timestamps absolutos gravados no item. Este stream existe só para provocar
/// o rebuild — assim o número na tela continua certo mesmo que o app tenha
/// ficado minutos em segundo plano ou com a tela apagada.
///
/// É `autoDispose` de propósito: sem ninguém olhando o cronômetro, o timer
/// para.
final tickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => clock());
});
