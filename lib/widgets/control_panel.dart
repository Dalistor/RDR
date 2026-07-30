import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/meeting_provider.dart';
import '../utils/app_theme.dart';

/// Painel fixo de controle do cronômetro, no rodapé da tela da reunião.
///
/// Não decide nada sobre tempo: cada botão despacha a operação correspondente
/// do [MeetingNotifier], que delega ao service. O painel só conhece três
/// flags — [isRunning], [hasStarted] e [hasEnded] —, nunca o relatório inteiro:
/// a tela já se redesenha a cada tique do cronômetro e o painel não precisa
/// reconstruir junto.
///
/// O arranjo dos botões é uma exigência de uso, não estética: o painel é
/// tocado no escuro, às pressas, durante a reunião. Por isso
///
/// - o **alvo central** é um só, cíclico, com 72dp de altura. É o botão
///   apertado dezenas de vezes por noite: parado diz `Iniciar` e arranca o item
///   selecionado; correndo diz `Próximo`, para o tempo e desce a seleção **sem**
///   arrancar o próximo. Não há pausar sem avançar;
/// - as **setas** de seleção ficam nas laterais, longe dele;
/// - a faixa de baixo, separada por um vão morto e um divisor, traz `Zerar
///   parte` num canto e o **botão cíclico da reunião** no outro. O primeiro
///   age direto — errar custa um toque e ele mexe só na parte selecionada. O
///   segundo grava os horários de início e fim da reunião, e por isso pede
///   confirmação nos dois estados ativos.
class ControlPanel extends ConsumerWidget {
  const ControlPanel({
    super.key,
    required this.isRunning,
    required this.hasStarted,
    required this.hasEnded,
  });

  /// Há algum item com o cronômetro correndo — alterna o alvo central de
  /// `Iniciar` para `Próximo`.
  final bool isRunning;

  /// A reunião já teve o horário de início gravado — alterna o botão cíclico
  /// da reunião de `Iniciar reunião` para `Encerrar reunião`.
  final bool hasStarted;

  /// A reunião já foi encerrada: o relatório está congelado e **todos** os
  /// botões do painel ficam desabilitados. Depois do encerramento não se edita
  /// mais nada — sobra exportar o print e, no menu do topo, reiniciar tudo.
  final bool hasEnded;

  /// Altura dos dois alvos centrais. Bem acima do mínimo de 48dp de propósito.
  static const double _alturaPrincipal = 72;

  /// Alvo mínimo de toque exigido em todos os botões do painel.
  static const double _alvoMinimo = 48;

  static const double _larguraSeta = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.notifier` não muda quando o relatório muda: observar aqui não provoca
    // rebuild a cada tique do cronômetro.
    final MeetingNotifier notifier = ref.watch(meetingProvider.notifier);
    final bool cronometroAtivo = !hasEnded;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              // As setas mexem só na seleção — o item que corre continua
              // correndo. Com a reunião encerrada não há mais o que selecionar:
              // o relatório está congelado.
              _BotaoDeSeta(
                icone: Icons.keyboard_arrow_up,
                rotulo: 'Selecionar o item acima',
                onPressed: cronometroAtivo
                    ? () => notifier.selectPrevious()
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BotaoPrincipal(
                  icone: isRunning ? Icons.skip_next : Icons.play_arrow,
                  rotulo: isRunning ? 'Próximo' : 'Iniciar',
                  cor: isRunning
                      ? const Color(0xFF1F2933)
                      : AppTheme.treasuresColor,
                  onPressed: !cronometroAtivo
                      ? null
                      // `advance` para o tempo e desce a seleção sem arrancar o
                      // próximo: é o toque seguinte que o inicia.
                      : () => isRunning ? notifier.advance() : notifier.start(),
                ),
              ),
              const SizedBox(width: 8),
              _BotaoDeSeta(
                icone: Icons.keyboard_arrow_down,
                rotulo: 'Selecionar o item abaixo',
                onPressed: cronometroAtivo
                    ? () => notifier.selectNext()
                    : null,
              ),
            ],
          ),
          // Vão morto + divisor: é o que separa fisicamente a faixa de baixo do
          // alvo central, logo acima.
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),
          // `spaceBetween` com filhos flexíveis em vez de um `Spacer`: os dois
          // rótulos juntos não cabem em tela estreita, e assim eles encolhem
          // com reticências em vez de estourar o layout.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Age direto, sem confirmação: mexe só na parte selecionada, e o
              // preço de um toque errado é recronometrar uma parte. Encerrada a
              // reunião, some junto com o resto da edição.
              Flexible(
                child: _BotaoSecundario(
                  icone: Icons.restart_alt,
                  rotulo: 'Zerar parte',
                  cor: const Color(0xFF52606D),
                  onPressed: cronometroAtivo
                      ? () => notifier.resetSelectedItem()
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: _BotaoSecundario(
                  icone: hasStarted
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline,
                  rotulo: _rotuloDaReuniao,
                  cor: AppTheme.christianLifeColor,
                  onPressed: hasEnded
                      ? null
                      : () => _confirmarAcaoDaReuniao(context, notifier),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// O rótulo do botão cíclico da reunião no estado atual.
  String get _rotuloDaReuniao {
    if (hasEnded) return 'Reunião encerrada';
    return hasStarted ? 'Encerrar reunião' : 'Iniciar reunião';
  }

  /// Abre e encerra a reunião — as duas pontas do relatório impresso.
  ///
  /// Os dois estados pedem confirmação: gravam um horário que só sai depois
  /// pela edição manual, e o encerramento ainda desliga o cronômetro.
  Future<void> _confirmarAcaoDaReuniao(
    BuildContext context,
    MeetingNotifier notifier,
  ) async {
    final bool encerrando = hasStarted;
    final bool confirmado = await _confirmar(
      context,
      titulo: encerrando ? 'Encerrar a reunião?' : 'Iniciar a reunião?',
      mensagem: encerrando
          ? 'O horário de fim é gravado agora, o cronômetro para e o relatório '
                'fica congelado: depois disso não dá mais para editar nada. '
                'Confira os tempos antes de encerrar.'
          : 'O horário de início da reunião é gravado agora, com a hora do '
                'celular. O cronômetro das partes continua sendo controlado '
                'pelo botão de cima.',
      rotuloDaAcao: encerrando ? 'Encerrar' : 'Iniciar',
    );
    if (!confirmado) return;
    if (encerrando) {
      notifier.endMeeting();
    } else {
      notifier.startMeeting();
    }
  }

  /// Diálogo de confirmação das ações destrutivas.
  ///
  /// O `notifier` é capturado pelo chamador antes do `await` de propósito:
  /// depois de fechado o diálogo não se toca mais em `context` nem em `ref`.
  Future<bool> _confirmar(
    BuildContext context, {
    required String titulo,
    required String mensagem,
    required String rotuloDaAcao,
  }) async {
    final bool? resposta = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensagem),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.christianLifeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, _alvoMinimo),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(rotuloDaAcao),
            ),
          ],
        );
      },
    );
    return resposta ?? false;
  }
}

/// Um dos dois alvos grandes e centrais do painel.
class _BotaoPrincipal extends StatelessWidget {
  const _BotaoPrincipal({
    required this.icone,
    required this.rotulo,
    required this.cor,
    required this.onPressed,
  });

  final IconData icone;
  final String rotulo;
  final Color cor;

  /// Nulo desabilita o botão — é o estado depois de encerrada a reunião.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, ControlPanel._alturaPrincipal),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icone, size: 26),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seta lateral de seleção. Mexe só no item selecionado, nunca no cronômetro.
class _BotaoDeSeta extends StatelessWidget {
  const _BotaoDeSeta({
    required this.icone,
    required this.rotulo,
    required this.onPressed,
  });

  final IconData icone;

  /// Serve de tooltip e de rótulo de acessibilidade.
  final String rotulo;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ControlPanel._larguraSeta,
      height: ControlPanel._alturaPrincipal,
      child: Tooltip(
        message: rotulo,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.treasuresColor,
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Color(0xFFBFD2D8)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icone, size: 30, semanticLabel: rotulo),
        ),
      ),
    );
  }
}

/// Ação da faixa de baixo: discreta e recuada, longe do alvo central.
class _BotaoSecundario extends StatelessWidget {
  const _BotaoSecundario({
    required this.icone,
    required this.rotulo,
    required this.cor,
    required this.onPressed,
  });

  final IconData icone;
  final String rotulo;

  /// Vinho para o botão da reunião, que grava horário; neutro para o `Zerar
  /// parte`, que só desfaz uma cronometragem.
  final Color cor;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icone, size: 18),
      label: Text(
        rotulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cor,
        minimumSize: const Size(0, ControlPanel._alvoMinimo),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: cor.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
