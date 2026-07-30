import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/timed_item.dart';
import 'package:rdr/providers/dependencies_provider.dart';
import 'package:rdr/providers/meeting_provider.dart';
import 'package:rdr/providers/tick_provider.dart';
import 'package:rdr/repositories/image_export_repository.dart';
import 'package:rdr/utils/app_theme.dart';
import 'package:rdr/utils/time_format.dart';
import 'package:rdr/widgets/control_panel.dart';
import 'package:rdr/widgets/item_actions_menu.dart';
import 'package:rdr/widgets/item_row.dart';
import 'package:rdr/widgets/report_sheet.dart';
import 'package:rdr/widgets/section_header.dart';
import 'package:screenshot/screenshot.dart';

/// Tela principal: a lista viva da reunião e os estados de carga da
/// programação.
///
/// Toda a regra mora nos services, atrás do `MeetingNotifier`; aqui só há
/// layout e leitura de estado. O cronômetro é redesenhado a cada tick de 1
/// segundo, mas o tempo mostrado nunca é acumulado — vem sempre de
/// `TimedItem.effectiveElapsed(DateTime.now())`, calculado a partir dos
/// timestamps absolutos do item.
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({super.key});

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen> {
  final ScrollController _scrollController = ScrollController();

  /// Uma chave por item, para levar o item selecionado à área visível.
  ///
  /// A lista não é preguiçosa de propósito (ver [_buildLista]): a rolagem
  /// automática precisa que o item de destino já esteja montado, mesmo fora
  /// da tela.
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};

  String? _ultimoSelecionado;

  /// Enquanto a restauração do relatório salvo não termina, a tela espera —
  /// sem isso o estado vazio piscaria por cima de uma reunião em andamento.
  bool _restaurando = true;

  /// Geração do PNG em andamento: trava o botão e cobre a tela com o
  /// indicador de progresso.
  bool _exportando = false;

  /// Renderiza o `ReportSheet` fora da tela. Nada é montado dentro desta
  /// árvore — o controller é usado só pelo `captureFromLongWidget`.
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _aguardarRestauracao();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _aguardarRestauracao() async {
    await ref.read(meetingProvider.notifier).restored;
    if (!mounted) return;
    setState(() => _restaurando = false);
  }

  @override
  Widget build(BuildContext context) {
    final MeetingReport? report = ref.watch(meetingProvider);
    final ScheduleFetchState fetch = ref.watch(scheduleFetchProvider);

    // O tick não muda o estado: é observado só para provocar o rebuild de
    // segundo em segundo enquanto a tela está visível.
    ref.watch(tickProvider);

    _acompanharSelecao(report?.selectedItemId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Relatório da reunião'),
            if (report != null && report.weekLabel.isNotEmpty)
              Text(
                report.weekLabel,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
          ],
        ),
        actions: <Widget>[
          if (report != null)
            IconButton(
              onPressed: _exportando ? null : () => _exportarRelatorio(report),
              icon: const Icon(Icons.ios_share),
              tooltip: 'Exportar o relatório em imagem',
            ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                // Rebaixar a programação com a reunião já montada não pode
                // esconder a lista: o progresso vira uma barra fina no topo.
                if (report != null && fetch.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(child: _buildCorpo(report, fetch)),
                // Rodapé fixo, fora da área rolável: os botões são tocados às
                // pressas e no escuro, e não podem sumir com a rolagem.
                if (report != null)
                  ControlPanel(
                    isRunning: report.runningItemId != null,
                    hasEnded: report.endedAt != null,
                  ),
              ],
            ),
          ),
          // A captura do print longo trava a interface por um instante; o véu
          // impede que um toque perdido mexa no cronômetro nesse meio-tempo.
          if (_exportando) const _VeuDeExportacao(),
        ],
      ),
    );
  }

  /// Gera o PNG do relatório inteiro e o entrega ao repositório de exportação,
  /// que salva na galeria e abre o compartilhamento.
  ///
  /// A folha é renderizada **fora da tela** por `captureFromLongWidget`: a
  /// altura do aparelho não limita o resultado, e o relatório sai numa imagem
  /// única, sem corte e sem rolagem.
  Future<void> _exportarRelatorio(MeetingReport report) async {
    if (_exportando) return;

    // Capturados antes do `await`: depois do trecho assíncrono não se toca
    // mais em `context`.
    final ScaffoldMessengerState mensagens = ScaffoldMessenger.of(context);
    final ImageExportRepository exportador = ref.read(
      imageExportRepositoryProvider,
    );

    setState(() => _exportando = true);

    String? erro;
    try {
      final Uint8List png = await _screenshotController.captureFromLongWidget(
        ReportSheet(report: report, now: DateTime.now()),
        pixelRatio: ReportSheet.capturePixelRatio,
        // A folha define a própria largura; a restrição só impede que a
        // medição a deixe crescer horizontalmente sem limite.
        constraints: const BoxConstraints(maxWidth: ReportSheet.captureWidth),
        delay: const Duration(milliseconds: 100),
      );
      await exportador.exportReportImage(png);
    } on ImageExportException catch (falha) {
      erro = falha.message;
    } on Object catch (falha) {
      debugPrint('Falha ao gerar a imagem do relatório: $falha');
      erro = 'Não foi possível gerar a imagem do relatório.';
    }

    if (!mounted) return;
    setState(() => _exportando = false);

    mensagens.hideCurrentSnackBar();
    mensagens.showSnackBar(
      SnackBar(
        content: Text(
          erro ?? 'Relatório salvo na galeria. Escolha por onde compartilhar.',
        ),
        backgroundColor: erro == null
            ? AppTheme.treasuresColor
            : AppTheme.christianLifeColor,
        duration: Duration(seconds: erro == null ? 3 : 6),
      ),
    );
  }

  Widget _buildCorpo(MeetingReport? report, ScheduleFetchState fetch) {
    if (_restaurando) {
      return const _EstadoDeProgresso(mensagem: 'Restaurando a reunião…');
    }
    if (report != null) return _buildLista(report);
    if (fetch.isLoading) {
      return const _EstadoDeProgresso(mensagem: 'Baixando a programação…');
    }
    if (fetch.hasError) {
      return _EstadoDeErro(
        mensagem: fetch.message ?? 'Não foi possível baixar a programação.',
        onTentarDeNovo: _baixarProgramacao,
        onMontarNaMao: _montarNaMao,
      );
    }
    return _EstadoVazio(onBaixar: _baixarProgramacao);
  }

  /// A lista inteira do relatório, na ordem canônica.
  ///
  /// É uma coluna rolável e não uma `ListView` preguiçosa: são poucas dezenas
  /// de linhas e, montadas todas, `Scrollable.ensureVisible` consegue alcançar
  /// o item selecionado ainda que ele esteja fora da tela.
  Widget _buildLista(MeetingReport report) {
    final DateTime agora = DateTime.now();
    final List<Widget> linhas = <Widget>[
      _CabecalhoDoRelatorio(startedAt: report.startedAt),
      _buildLinha(report, report.openingComments, agora, null),
      for (final section in report.sections) ...<Widget>[
        SectionHeader(kind: section.kind, title: section.title),
        for (final item in section.items)
          _buildLinha(report, item, agora, AppTheme.sectionColor(section.kind)),
      ],
      const SizedBox(height: 16),
      _buildLinha(report, report.closingComments, agora, null),
      if (report.endedAt != null) _RodapeDoRelatorio(endedAt: report.endedAt!),
    ];

    _descartarChavesOrfas(report);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: linhas,
      ),
    );
  }

  Widget _buildLinha(
    MeetingReport report,
    TimedItem item,
    DateTime agora,
    Color? accent,
  ) {
    return KeyedSubtree(
      key: _chaveDe(item.id),
      child: ItemRow(
        label: item.label,
        elapsed: item.effectiveElapsed(agora),
        isSubItem: item.isSubItem,
        // Selecionado e correndo são coisas diferentes e podem coexistir: o
        // primeiro é onde o usuário está olhando, o segundo é o que consome
        // tempo agora. Cada um tem seu destaque no `ItemRow`.
        isSelected: report.selectedItemId == item.id,
        isRunning: report.runningItemId == item.id,
        accentColor: accent,
        onTap: () => ref.read(meetingProvider.notifier).select(item.id),
        onLongPress: () => _abrirMenuDoItem(report, item),
      ),
    );
  }

  /// Toque longo: abre o menu de manutenção da lista (editar, adicionar abaixo
  /// e remover). Os diálogos e o despacho ao notifier moram na camada de
  /// widgets; aqui só se decide o que pode ser removido.
  void _abrirMenuDoItem(MeetingReport report, TimedItem item) {
    // Comentários iniciais e finais são a moldura fixa do relatório e vivem
    // fora das seções: podem ser renomeados e ter o tempo ajustado, mas não
    // saem da lista.
    final bool removivel =
        item.id != report.openingComments.id &&
        item.id != report.closingComments.id;

    showItemMaintenanceMenu(
      context: context,
      notifier: ref.read(meetingProvider.notifier),
      item: item,
      canRemove: removivel,
    );
  }

  GlobalKey _chaveDe(String id) => _itemKeys.putIfAbsent(id, () => GlobalKey());

  /// Remove as chaves de itens que saíram do relatório, para o mapa não
  /// crescer indefinidamente ao longo de edições e resets.
  void _descartarChavesOrfas(MeetingReport report) {
    final Set<String> vivos = <String>{
      for (final item in report.orderedItems) item.id,
    };
    _itemKeys.removeWhere((String id, _) => !vivos.contains(id));
  }

  /// Rola até o item selecionado sempre que a seleção muda — inclusive quando
  /// quem mudou foram as setas do painel de controle.
  void _acompanharSelecao(String? selecionado) {
    if (selecionado == _ultimoSelecionado) return;
    _ultimoSelecionado = selecionado;
    if (selecionado == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? alvo = _itemKeys[selecionado]?.currentContext;
      if (alvo == null) return;
      Scrollable.ensureVisible(
        alvo,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _baixarProgramacao() {
    ref.read(meetingProvider.notifier).downloadSchedule();
  }

  void _montarNaMao() {
    ref.read(meetingProvider.notifier).startManualReport();
  }
}

/// Linha `Início da reunião: HH:MM` no topo da lista.
///
/// Antes do primeiro início o valor fica em branco — a linha permanece para o
/// topo da tela não dançar quando o cronômetro arranca.
class _CabecalhoDoRelatorio extends StatelessWidget {
  const _CabecalhoDoRelatorio({required this.startedAt});

  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: <Widget>[
          const Text(
            'Início da reunião:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            startedAt == null ? '' : formatClock(startedAt!),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.treasuresColor,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha `Fim da reunião: HH:MM`, exibida só depois de encerrada.
class _RodapeDoRelatorio extends StatelessWidget {
  const _RodapeDoRelatorio({required this.endedAt});

  final DateTime endedAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Row(
        children: <Widget>[
          const Text(
            'Fim da reunião:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatClock(endedAt),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.treasuresColor,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Véu de progresso exibido enquanto o PNG do relatório é gerado, salvo na
/// galeria e enviado ao compartilhamento.
class _VeuDeExportacao extends StatelessWidget {
  const _VeuDeExportacao();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.88),
          child: const _EstadoDeProgresso(
            mensagem: 'Gerando a imagem do relatório…',
          ),
        ),
      ),
    );
  }
}

/// Indicador de progresso com uma legenda curta.
class _EstadoDeProgresso extends StatelessWidget {
  const _EstadoDeProgresso({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            mensagem,
            style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}

/// Nenhuma reunião carregada ainda.
class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio({required this.onBaixar});

  final VoidCallback onBaixar;

  @override
  Widget build(BuildContext context) {
    return _PainelCentral(
      icone: Icons.cloud_download_outlined,
      corDoIcone: AppTheme.treasuresColor,
      titulo: 'Nenhuma programação carregada',
      descricao:
          'Baixe a programação desta semana do wol.jw.org para montar a '
          'lista da reunião. É preciso estar conectado à internet.',
      acoes: <Widget>[
        FilledButton.icon(
          onPressed: onBaixar,
          icon: const Icon(Icons.download),
          label: const Text('Baixar programação'),
        ),
      ],
    );
  }
}

/// A busca falhou: mostra a mensagem do provider e as duas saídas possíveis.
class _EstadoDeErro extends StatelessWidget {
  const _EstadoDeErro({
    required this.mensagem,
    required this.onTentarDeNovo,
    required this.onMontarNaMao,
  });

  final String mensagem;
  final VoidCallback onTentarDeNovo;

  /// Sem esta saída, um wol.jw.org fora do ar deixaria a reunião sem
  /// cronômetro: monta um relatório vazio, só com os itens fixos.
  final VoidCallback onMontarNaMao;

  @override
  Widget build(BuildContext context) {
    return _PainelCentral(
      icone: Icons.cloud_off_outlined,
      corDoIcone: AppTheme.christianLifeColor,
      titulo: 'Não deu para baixar a programação',
      descricao: mensagem,
      acoes: <Widget>[
        FilledButton.icon(
          onPressed: onTentarDeNovo,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onMontarNaMao,
          icon: const Icon(Icons.edit_note),
          label: const Text('Montar a lista na mão'),
        ),
      ],
    );
  }
}

/// Moldura comum dos estados vazio e de erro.
class _PainelCentral extends StatelessWidget {
  const _PainelCentral({
    required this.icone,
    required this.corDoIcone,
    required this.titulo,
    required this.descricao,
    required this.acoes,
  });

  final IconData icone;
  final Color corDoIcone;
  final String titulo;
  final String descricao;
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: 48),
          Icon(icone, size: 56, color: corDoIcone),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            descricao,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF555555),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ...acoes,
        ],
      ),
    );
  }
}
