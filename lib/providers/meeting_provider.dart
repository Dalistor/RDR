import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/providers/dependencies_provider.dart';
import 'package:rdr/repositories/report_storage_repository.dart';
import 'package:rdr/repositories/wol_repository.dart';
import 'package:rdr/services/meeting_timer_service.dart';
import 'package:rdr/services/report_builder.dart';
import 'package:rdr/services/schedule_parser.dart';

/// Em que pé está a busca da programação no wol.jw.org.
enum ScheduleFetchStatus {
  /// Nada em andamento — nem baixando, nem com erro pendente.
  idle,

  /// Download e parsing em curso.
  loading,

  /// A última tentativa falhou; a mensagem está em [ScheduleFetchState.message].
  error,
}

/// Estado da busca da programação, para a tela reagir à falta de internet.
@immutable
class ScheduleFetchState {
  const ScheduleFetchState._(this.status, this.message);

  /// Ocioso: nenhuma busca em andamento.
  const ScheduleFetchState.idle() : this._(ScheduleFetchStatus.idle, null);

  /// Baixando e montando a programação.
  const ScheduleFetchState.loading()
    : this._(ScheduleFetchStatus.loading, null);

  /// Falha, com a mensagem em português que a tela mostra ao usuário.
  const ScheduleFetchState.error(String message)
    : this._(ScheduleFetchStatus.error, message);

  final ScheduleFetchStatus status;

  /// Mensagem de erro pronta para exibição; nula fora do estado de erro.
  final String? message;

  bool get isLoading => status == ScheduleFetchStatus.loading;

  bool get hasError => status == ScheduleFetchStatus.error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleFetchState &&
          other.status == status &&
          other.message == message;

  @override
  int get hashCode => Object.hash(status, message);

  @override
  String toString() => 'ScheduleFetchState($status, message: $message)';
}

/// Guarda o estado da busca. Quem o move é o [MeetingNotifier], que é dono do
/// fluxo de download; a UI só observa.
class ScheduleFetchNotifier extends StateNotifier<ScheduleFetchState> {
  ScheduleFetchNotifier() : super(const ScheduleFetchState.idle());

  void markLoading() => state = const ScheduleFetchState.loading();

  void markIdle() => state = const ScheduleFetchState.idle();

  void fail(String message) => state = ScheduleFetchState.error(message);
}

/// Estado da busca da programação: ocioso, carregando ou erro com mensagem.
final scheduleFetchProvider =
    StateNotifierProvider<ScheduleFetchNotifier, ScheduleFetchState>(
      (ref) => ScheduleFetchNotifier(),
    );

/// O relatório da reunião em andamento, ou `null` enquanto não houver nenhum.
final meetingProvider =
    StateNotifierProvider<MeetingNotifier, MeetingReport?>((ref) {
      return MeetingNotifier(
        timer: ref.watch(meetingTimerServiceProvider),
        builder: ref.watch(reportBuilderProvider),
        parser: ref.watch(scheduleParserProvider),
        wol: ref.watch(wolRepositoryProvider),
        storage: ref.watch(reportStorageRepositoryProvider),
        fetchStatus: ref.watch(scheduleFetchProvider.notifier),
      );
    });

/// Única porta de entrada da UI para o relatório da reunião.
///
/// Não decide nada: cada operação é delegada ao [MeetingTimerService] e o
/// resultado é gravado no [ReportStorageRepository] em seguida. Uma reunião
/// dura quase duas horas e não se repete — nenhuma mudança pode ficar só na
/// memória.
class MeetingNotifier extends StateNotifier<MeetingReport?> {
  MeetingNotifier({
    required this._timer,
    required this._builder,
    required this._parser,
    required this._wol,
    required this._storage,
    required this._fetchStatus,
  }) : super(null) {
    _restored = _restoreSaved();
  }

  // As dependências ficam privadas de propósito: o notifier é a única porta de
  // entrada da UI, que não deve alcançar repositórios por dentro dele.
  final MeetingTimerService _timer;
  final ReportBuilder _builder;
  final ScheduleParser _parser;
  final WolRepository _wol;
  final ReportStorageRepository _storage;
  final ScheduleFetchNotifier _fetchStatus;

  late final Future<void> _restored;

  /// Conclui quando a tentativa de restaurar o relatório salvo termina.
  ///
  /// A restauração começa junto com o notifier; a tela pode esperar por ela
  /// para não piscar o estado vazio em cima de uma reunião já em andamento.
  Future<void> get restored => _restored;

  /// Baixa a programação da semana e substitui o relatório atual por um novo,
  /// zerado.
  ///
  /// Percorre repositório HTTP → parser → montador. Falha de rede e falha de
  /// layout viram mensagem em [scheduleFetchProvider], nunca exceção solta na
  /// UI.
  Future<void> downloadSchedule() async {
    _fetchStatus.markLoading();
    try {
      final paginaDaSemana = await _wol.fetchCurrentWeekPage();
      final link = _parser.parseWeekPage(paginaDaSemana);
      final documento = await _wol.fetchDocument(link.documentPath);
      final secoes = _parser.parseDocument(documento);
      await _replace(
        _builder.build(weekLabel: link.weekLabel, sections: secoes),
      );
      if (!mounted) return;
      _fetchStatus.markIdle();
    } on WolFetchException catch (erro) {
      if (!mounted) return;
      _fetchStatus.fail(erro.message);
    } on ScheduleParseException catch (erro) {
      if (!mounted) return;
      _fetchStatus.fail(erro.message);
    } on Object catch (erro) {
      // Rede de dispositivo e plugins têm mais jeitos de falhar do que os dois
      // acima. Sem esta rede de segurança, uma exceção inesperada deixaria a
      // busca parada em "carregando" para sempre, sem nem o botão de tentar
      // de novo.
      debugPrint('Falha inesperada ao baixar a programação: $erro');
      if (!mounted) return;
      _fetchStatus.fail(
        'Não foi possível baixar a programação. Verifique a internet e '
        'tente de novo.',
      );
    }
  }

  /// Cria um relatório vazio, só com os itens fixos e as três seções sem
  /// partes, para o usuário montar a lista na mão.
  ///
  /// É a saída quando o wol.jw.org está fora do ar ou mudou de layout: sem ela
  /// a reunião ficaria sem como ser cronometrada.
  Future<void> startManualReport({String weekLabel = ''}) async {
    _fetchStatus.markIdle();
    await _replace(
      _builder.build(weekLabel: weekLabel, sections: _secoesVazias),
    );
  }

  /// Descarta o relatório inteiro — da memória e do disco — e devolve o app ao
  /// estado "nenhuma programação carregada".
  ///
  /// Depois de encerrada a reunião o relatório fica congelado: esta é a única
  /// saída, para começar a semana seguinte com uma lista nova. Como não há
  /// como desfazer, quem chama confirma antes.
  Future<void> resetAll() async {
    if (!mounted) return;
    state = null;
    _fetchStatus.markIdle();
    await _storage.clear();
  }

  /// Arranca o cronômetro no item selecionado.
  Future<void> start() => _apply(_timer.start);

  /// Congela o item que está correndo.
  Future<void> pause() => _apply(_timer.pause);

  /// Fecha o item corrente e passa o cronômetro para o próximo.
  Future<void> next() => _apply(_timer.next);

  /// Sobe a seleção um item, sem parar o cronômetro.
  Future<void> selectPrevious() => _apply(_timer.selectPrevious);

  /// Desce a seleção um item, sem parar o cronômetro.
  Future<void> selectNext() => _apply(_timer.selectNext);

  /// Seleciona um item específico — é o que o toque na lista faz.
  ///
  /// Assim como as setas, mexe só na seleção: o item que corre continua
  /// correndo.
  Future<void> select(String id) {
    return _apply(
      (report) => report.itemById(id) == null
          ? report
          : report.copyWith(selectedItemId: id),
    );
  }

  /// Fecha o item corrente e desce a seleção, sem arrancar o próximo.
  Future<void> advance() => _apply(_timer.advance);

  /// Grava o horário de início da reunião.
  Future<void> startMeeting() => _apply(_timer.startMeeting);

  /// Encerra a reunião e grava o horário do fim.
  Future<void> endMeeting() => _apply(_timer.endMeeting);

  /// Zera o tempo de um item, e só dele.
  Future<void> resetItem(String id) =>
      _apply((report) => _timer.resetItem(report, id));

  /// Zera o tempo da parte selecionada — é o que o botão do painel faz.
  ///
  /// Sem nada selecionado não há o que zerar.
  Future<void> resetSelectedItem() {
    return _apply((report) {
      final id = report.selectedItemId;
      return id == null ? report : _timer.resetItem(report, id);
    });
  }

  /// Define à mão o horário de início da reunião; `null` limpa.
  Future<void> setStartedAt(DateTime? valor) =>
      _apply((report) => _timer.setStartedAt(report, valor));

  /// Define à mão o horário de fim da reunião; `null` limpa.
  Future<void> setEndedAt(DateTime? valor) =>
      _apply((report) => _timer.setEndedAt(report, valor));

  /// Troca o texto de um item.
  Future<void> rename(String id, String label) =>
      _apply((report) => _timer.rename(report, id, label));

  /// Define o tempo acumulado de um item, inclusive com ele correndo.
  Future<void> setElapsed(String id, Duration elapsed) =>
      _apply((report) => _timer.setElapsed(report, id, elapsed));

  /// Insere um item novo logo depois de [afterId].
  Future<void> addItem({
    required String afterId,
    required String label,
    bool isSubItem = false,
  }) {
    return _apply(
      (report) => _timer.addItem(report, afterId, label, isSubItem: isSubItem),
    );
  }

  /// Remove um item do relatório, junto com o tempo dele.
  Future<void> removeItem(String id) =>
      _apply((report) => _timer.removeItem(report, id));

  /// Recupera a reunião que estava em andamento quando o app foi fechado.
  ///
  /// Não regrava o que acabou de vir do disco.
  Future<void> _restoreSaved() async {
    final salvo = await _storage.load();
    if (!mounted || salvo == null) return;
    state = salvo;
  }

  /// Aplica uma operação do cronômetro ao relatório atual e persiste.
  ///
  /// Sem relatório carregado não há o que cronometrar: a operação é ignorada.
  Future<void> _apply(MeetingReport Function(MeetingReport report) operacao) {
    final atual = state;
    if (atual == null) return Future<void>.value();
    return _replace(operacao(atual));
  }

  /// Publica o novo relatório e o grava em disco — nesta ordem, para a tela
  /// responder na hora e a escrita acontecer logo atrás.
  Future<void> _replace(MeetingReport report) async {
    if (!mounted) return;
    state = report;
    await _storage.save(report);
  }
}

/// As três seções da reunião sem nenhuma parte, base do relatório montado à
/// mão. Os títulos são os mesmos que o parser extrai do wol.jw.org.
const List<ParsedSection> _secoesVazias = <ParsedSection>[
  ParsedSection(
    kind: SectionKind.treasures,
    title: 'TESOUROS DA PALAVRA DE DEUS',
    partTitles: <String>[],
  ),
  ParsedSection(
    kind: SectionKind.ministry,
    title: 'FAÇA SEU MELHOR NO MINISTÉRIO',
    partTitles: <String>[],
  ),
  ParsedSection(
    kind: SectionKind.christianLife,
    title: 'NOSSA VIDA CRISTÃ',
    partTitles: <String>[],
  ),
];
