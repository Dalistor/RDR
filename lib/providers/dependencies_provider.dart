/// Instâncias únicas de services e repositories, expostas para injeção.
///
/// Nada aqui tem lógica: é só a fábrica das dependências que o resto da camada
/// de providers e a UI consomem. Trocar qualquer uma delas num teste ou num
/// `ProviderScope` é questão de sobrescrever o provider correspondente.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rdr/repositories/image_export_repository.dart';
import 'package:rdr/repositories/report_storage_repository.dart';
import 'package:rdr/repositories/wol_repository.dart';
import 'package:rdr/services/meeting_timer_service.dart';
import 'package:rdr/services/report_builder.dart';
import 'package:rdr/services/schedule_parser.dart';

/// Relógio do sistema usado pelo cronômetro e pelo tick da UI.
///
/// É o único ponto do app que conhece `DateTime.now()`: services recebem o
/// relógio injetado para que o teste possa controlá-lo.
final clockProvider = Provider<Clock>((ref) => DateTime.now);

/// Acesso HTTP ao wol.jw.org.
final wolRepositoryProvider = Provider<WolRepository>(
  (ref) => WolRepository(),
);

/// Persistência local do relatório em andamento.
final reportStorageRepositoryProvider = Provider<ReportStorageRepository>(
  (ref) => ReportStorageRepository(),
);

/// Exportação do PNG do relatório para a galeria e o compartilhamento.
final imageExportRepositoryProvider = Provider<ImageExportRepository>(
  (ref) => ImageExportRepository(),
);

/// Parser do HTML da programação.
final scheduleParserProvider = Provider<ScheduleParser>(
  (ref) => const ScheduleParser(),
);

/// Montador do relatório a partir da programação parseada.
final reportBuilderProvider = Provider<ReportBuilder>(
  (ref) => const ReportBuilder(),
);

/// Máquina de estados do cronômetro, já com o relógio do app injetado.
final meetingTimerServiceProvider = Provider<MeetingTimerService>(
  (ref) => MeetingTimerService(clock: ref.watch(clockProvider)),
);
