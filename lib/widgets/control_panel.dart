import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/meeting_provider.dart';
import '../utils/app_theme.dart';

/// Painel fixo de controle do cronômetro, no rodapé da tela da reunião.
///
/// Não decide nada sobre tempo: cada botão despacha a operação correspondente
/// do [MeetingNotifier], que delega ao service. O painel só sabe se há item
/// correndo ([isRunning]) e se a reunião já foi encerrada ([hasEnded]).
///
/// O arranjo dos botões é uma exigência de uso, não estética: o painel é
/// tocado no escuro, às pressas, durante a reunião. Por isso
///
/// - **Iniciar/Pausar** e **Próximo** são os dois alvos grandes e centrais,
///   com 72dp de altura;
/// - as **setas** de seleção ficam nas laterais, longe deles;
/// - **Resetar** e **Encerrar** ficam numa faixa separada por um vão morto e
///   um divisor, recuados nos cantos opostos e com aparência discreta — em
///   especial `Resetar`, no canto mais distante do `Próximo`, que é o botão
///   apertado dezenas de vezes por noite;
/// - os dois destrutivos ainda pedem confirmação antes de agir.
class ControlPanel extends ConsumerWidget {
  const ControlPanel({
    super.key,
    required this.isRunning,
    required this.hasEnded,
  });

  /// Há algum item com o cronômetro correndo — alterna Iniciar para Pausar.
  final bool isRunning;

  /// A reunião já foi encerrada: Iniciar, Pausar e Próximo não fazem mais
  /// sentido e ficam desabilitados até um `Resetar`.
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
              // correndo. Seguem habilitadas mesmo após o encerramento, para
              // o usuário poder percorrer a lista e conferir os tempos.
              _BotaoDeSeta(
                icone: Icons.keyboard_arrow_up,
                rotulo: 'Selecionar o item acima',
                onPressed: () => notifier.selectPrevious(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BotaoPrincipal(
                  icone: isRunning ? Icons.pause : Icons.play_arrow,
                  rotulo: isRunning ? 'Pausar' : 'Iniciar',
                  cor: isRunning
                      ? AppTheme.ministryColor
                      : AppTheme.treasuresColor,
                  onPressed: !cronometroAtivo
                      ? null
                      : () => isRunning ? notifier.pause() : notifier.start(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BotaoPrincipal(
                  icone: Icons.skip_next,
                  rotulo: 'Próximo',
                  cor: const Color(0xFF1F2933),
                  onPressed: cronometroAtivo ? () => notifier.next() : null,
                ),
              ),
              const SizedBox(width: 8),
              _BotaoDeSeta(
                icone: Icons.keyboard_arrow_down,
                rotulo: 'Selecionar o item abaixo',
                onPressed: () => notifier.selectNext(),
              ),
            ],
          ),
          // Vão morto + divisor: é o que separa fisicamente os destrutivos do
          // Próximo, logo acima.
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              // Canto oposto ao Próximo: `Resetar` apaga a reunião inteira.
              _BotaoDestrutivo(
                icone: Icons.restart_alt,
                rotulo: 'Resetar',
                onPressed: () => _confirmarReset(context, notifier),
              ),
              const Spacer(),
              _BotaoDestrutivo(
                icone: Icons.stop_circle_outlined,
                rotulo: 'Encerrar reunião',
                onPressed: hasEnded
                    ? null
                    : () => _confirmarEncerramento(context, notifier),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarReset(
    BuildContext context,
    MeetingNotifier notifier,
  ) async {
    final bool confirmado = await _confirmar(
      context,
      titulo: 'Resetar a reunião?',
      mensagem:
          'Todos os tempos já cronometrados voltam a zero, inclusive os '
          'horários de início e de fim. A lista de partes é mantida. Não dá '
          'para desfazer.',
      rotuloDaAcao: 'Resetar',
    );
    if (confirmado) notifier.reset();
  }

  Future<void> _confirmarEncerramento(
    BuildContext context,
    MeetingNotifier notifier,
  ) async {
    final bool confirmado = await _confirmar(
      context,
      titulo: 'Encerrar a reunião?',
      mensagem:
          'O horário de fim é gravado agora e o cronômetro para. Iniciar, '
          'Pausar e Próximo ficam desabilitados.',
      rotuloDaAcao: 'Encerrar',
    );
    if (confirmado) notifier.endMeeting();
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

/// Ação destrutiva: discreta, recuada e sempre atrás de uma confirmação.
class _BotaoDestrutivo extends StatelessWidget {
  const _BotaoDestrutivo({
    required this.icone,
    required this.rotulo,
    required this.onPressed,
  });

  final IconData icone;
  final String rotulo;
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
        foregroundColor: AppTheme.christianLifeColor,
        minimumSize: const Size(0, ControlPanel._alvoMinimo),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(
          color: AppTheme.christianLifeColor.withValues(alpha: 0.45),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
