import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/timed_item.dart';

/// Fonte do tempo do cronômetro.
///
/// Nenhum service chama `DateTime.now()` direto: o relógio é injetado para que
/// o teste possa controlá-lo.
typedef Clock = DateTime Function();

/// Máquina de estados do cronômetro da reunião.
///
/// Toda operação é pura: recebe um [MeetingReport] e devolve outro. O service
/// não guarda estado — quem guarda é o notifier da camada de providers.
class MeetingTimerService {
  const MeetingTimerService({required this.clock});

  /// Relógio usado para abrir e fechar os trechos de tempo.
  final Clock clock;

  /// Arranca o cronômetro no item selecionado.
  MeetingReport start(MeetingReport report) {
    final agora = clock();
    final alvo = _itemSelecionadoOuPrimeiro(report);
    return _arrancar(
      _fecharTrechoAberto(report, agora),
      alvo.id,
      agora,
    ).copyWith(startedAt: report.startedAt ?? agora);
  }

  /// Congela o item que está correndo, somando o trecho aberto ao acumulado.
  ///
  /// Sem nada correndo não há o que fechar: devolve o próprio relatório.
  MeetingReport pause(MeetingReport report) {
    if (report.runningItemId == null) return report;
    return _fecharTrechoAberto(report, clock());
  }

  /// Fecha o item corrente e passa o cronômetro para o próximo da ordem
  /// canônica, movendo também a seleção.
  MeetingReport next(MeetingReport report) {
    final agora = clock();
    final corrente = report.runningItemId ?? report.selectedItemId;
    final proximo = corrente == null
        ? report.orderedItems.first
        : _itemApos(report, corrente);
    final fechado = _fecharTrechoAberto(report, agora);
    if (proximo == null) return fechado;
    return _arrancar(fechado, proximo.id, agora);
  }

  /// Move a seleção um passo para baixo na ordem canônica.
  ///
  /// O item que está correndo continua correndo: as setas mexem só na seleção.
  MeetingReport selectNext(MeetingReport report) => _mover(report, 1);

  /// Move a seleção um passo para cima na ordem canônica, sem parar o
  /// cronômetro.
  MeetingReport selectPrevious(MeetingReport report) => _mover(report, -1);

  /// Encerra a reunião: fecha o trecho corrente e grava o fim no relógio.
  MeetingReport endMeeting(MeetingReport report) {
    final agora = clock();
    return _fecharTrechoAberto(
      report,
      agora,
    ).copyWith(endedAt: report.endedAt ?? agora);
  }

  /// Zera todos os tempos e o estado do cronômetro, preservando a estrutura do
  /// relatório: semana, seções, labels e itens adicionados na mão.
  ///
  /// A seleção também volta ao início: a próxima reunião começa do primeiro
  /// item, não de onde a anterior parou.
  MeetingReport reset(MeetingReport report) {
    return _mapearItens(
      report,
      (item) => item.copyWith(elapsed: Duration.zero, clearRunningSince: true),
    ).copyWith(
      clearStartedAt: true,
      clearEndedAt: true,
      clearRunningItemId: true,
      clearSelectedItemId: true,
    );
  }

  /// Troca o label do item [id] — fixo, parte ou sub-item — sem tocar nos
  /// tempos. Id inexistente não muda nada.
  MeetingReport rename(MeetingReport report, String id, String label) {
    return _mapearItens(
      report,
      (item) => item.id == id ? item.copyWith(label: label) : item,
    );
  }

  /// Define o tempo acumulado do item [id].
  ///
  /// Se o item estiver correndo, o trecho aberto é reancorado no instante
  /// atual: a contagem segue a partir do novo valor em vez de somar de novo o
  /// tempo que já tinha corrido.
  MeetingReport setElapsed(MeetingReport report, String id, Duration elapsed) {
    final agora = clock();
    return _mapearItens(report, (item) {
      if (item.id != id) return item;
      return item.copyWith(
        elapsed: elapsed,
        runningSince: item.runningSince == null ? null : agora,
      );
    });
  }

  /// Insere um item novo e zerado logo depois do item [afterId], na mesma
  /// seção dele.
  ///
  /// Os itens fixos ficam fora das seções, então inserir depois da abertura
  /// coloca o item no topo da primeira seção e inserir depois do fechamento o
  /// coloca no fim da última — as duas únicas posições possíveis.
  MeetingReport addItem(
    MeetingReport report,
    String afterId,
    String label, {
    bool isSubItem = false,
  }) {
    if (report.sections.isEmpty) return report;
    final novo = TimedItem(
      id: _novoId(report),
      label: label,
      isSubItem: isSubItem,
    );
    if (afterId == report.openingComments.id) {
      return _trocarSecao(report, 0, [novo, ...report.sections.first.items]);
    }
    if (afterId == report.closingComments.id) {
      final ultima = report.sections.length - 1;
      return _trocarSecao(report, ultima, [
        ...report.sections[ultima].items,
        novo,
      ]);
    }
    return report.copyWith(
      sections: [
        for (final section in report.sections)
          section.copyWith(items: _inserirApos(section.items, afterId, novo)),
      ],
    );
  }

  /// Remove o item [id] do relatório.
  ///
  /// Se ele estava correndo, o cronômetro para; o tempo dele vai embora junto.
  /// Se estava selecionado, a seleção recua para o item anterior.
  MeetingReport removeItem(MeetingReport report, String id) {
    final semItem = report.copyWith(
      clearRunningItemId: report.runningItemId == id,
      sections: [
        for (final section in report.sections)
          section.copyWith(
            items: section.items
                .where((item) => item.id != id)
                .toList(growable: false),
          ),
      ],
    );
    if (report.selectedItemId != id) return semItem;
    return semItem.copyWith(selectedItemId: _selecaoAposRemover(report, id));
  }
}

/// Para onde a seleção vai quando o item [id] — que estava selecionado — sai do
/// relatório [report]: o item logo antes dele, ou o primeiro que sobrar.
String _selecaoAposRemover(MeetingReport report, String id) {
  final ordem = report.orderedItems;
  final indice = ordem.indexWhere((item) => item.id == id);
  final anterior = indice > 0 ? ordem[indice - 1] : null;
  return (anterior ?? ordem.first).id;
}

/// O relatório com os itens da seção de índice [indice] trocados por [itens].
MeetingReport _trocarSecao(
  MeetingReport report,
  int indice,
  List<TimedItem> itens,
) {
  return report.copyWith(
    sections: [
      for (var i = 0; i < report.sections.length; i++)
        if (i == indice)
          report.sections[i].copyWith(items: itens)
        else
          report.sections[i],
    ],
  );
}

/// Prefixo dos ids gerados para itens adicionados na mão.
const String _prefixoManual = 'manual-';

/// Um id que ainda não existe no relatório.
String _novoId(MeetingReport report) {
  final usados = report.orderedItems.map((item) => item.id).toSet();
  var numero = 1;
  while (usados.contains('$_prefixoManual$numero')) {
    numero++;
  }
  return '$_prefixoManual$numero';
}

/// [itens] com [novo] logo depois de [afterId]; a mesma lista quando [afterId]
/// não está nela.
List<TimedItem> _inserirApos(
  List<TimedItem> itens,
  String afterId,
  TimedItem novo,
) {
  final indice = itens.indexWhere((item) => item.id == afterId);
  if (indice < 0) return itens;
  return [...itens.take(indice + 1), novo, ...itens.skip(indice + 1)];
}

/// Anda [passo] posições com a seleção, sem tocar no cronômetro.
///
/// Nas bordas da lista a seleção fica onde está; sem seleção nenhuma, a primeira
/// seta seleciona o primeiro item.
MeetingReport _mover(MeetingReport report, int passo) {
  final ordem = report.orderedItems;
  final atual = ordem.indexWhere((item) => item.id == report.selectedItemId);
  if (atual < 0) return report.copyWith(selectedItemId: ordem.first.id);
  final destino = atual + passo;
  if (destino < 0 || destino >= ordem.length) return report;
  return report.copyWith(selectedItemId: ordem[destino].id);
}

/// O item que vem logo depois de [id] na ordem canônica, ou `null` quando [id]
/// já é o último.
TimedItem? _itemApos(MeetingReport report, String? id) {
  final ordem = report.orderedItems;
  final indice = ordem.indexWhere((item) => item.id == id);
  if (indice < 0 || indice + 1 >= ordem.length) return null;
  return ordem[indice + 1];
}

/// Fecha o trecho aberto de qualquer item que esteja correndo, somando
/// `agora - runningSince` ao acumulado, e deixa o relatório sem item correndo.
MeetingReport _fecharTrechoAberto(MeetingReport report, DateTime agora) {
  return _mapearItens(report, (item) {
    final desde = item.runningSince;
    if (desde == null) return item;
    return item.copyWith(
      elapsed: item.elapsed + agora.difference(desde),
      clearRunningSince: true,
    );
  }).copyWith(clearRunningItemId: true);
}

/// Abre um trecho no item [id] a partir de [agora] e leva a seleção junto.
MeetingReport _arrancar(MeetingReport report, String id, DateTime agora) {
  return _mapearItens(
    report,
    (item) => item.id == id ? item.copyWith(runningSince: agora) : item,
  ).copyWith(runningItemId: id, selectedItemId: id);
}

/// O item destacado na tela, ou o primeiro da ordem canônica quando ainda não
/// há seleção.
TimedItem _itemSelecionadoOuPrimeiro(MeetingReport report) {
  final selecionado = report.selectedItemId;
  final item = selecionado == null ? null : report.itemById(selecionado);
  return item ?? report.orderedItems.first;
}

/// Reconstrói o relatório aplicando [transformar] a todos os itens, onde quer
/// que eles estejam: fixos, partes ou sub-itens.
MeetingReport _mapearItens(
  MeetingReport report,
  TimedItem Function(TimedItem item) transformar,
) {
  return report.copyWith(
    openingComments: transformar(report.openingComments),
    sections: [
      for (final section in report.sections)
        section.copyWith(
          items: [for (final item in section.items) transformar(item)],
        ),
    ],
    closingComments: transformar(report.closingComments),
  );
}
