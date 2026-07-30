# [0015] Diálogos de edição, inclusão e remoção de itens

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto
**Spec:** `.claude/specs/0001/` — Task 14

## Solicitação

> Spec 0001 — Task 14: Implemente em `lib/widgets/` os diálogos de manutenção da lista e ligue-os à `meeting_screen.dart`. Toque longo num item abre um menu com Editar, Adicionar abaixo e Remover.
>
> Editar abre um diálogo com o nome do item e o tempo em dois campos numéricos (minutos e segundos), pré-preenchidos com o valor atual e convertidos por `parseDurationInput` da Task 01; salvar chama `rename` e `setElapsed` no notifier. A edição é permitida **a qualquer momento, inclusive com o item correndo** — nesse caso a contagem segue a partir do novo valor.
>
> Adicionar abaixo abre um diálogo com o nome e a escolha entre parte e sub-item, e insere logo abaixo do item de origem. Remover pede confirmação, avisando que o tempo daquele item será perdido.
>
> Sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Widgets e na ligação em `meeting_screen.dart`; não modifique arquivos de outras camadas.

## Contexto

A lista montada a partir do wol.jw.org quase nunca bate exatamente com a reunião real: partes mudam de nome, um sub-item extra aparece, uma parte sai. Sem manutenção manual da lista, o cronômetro só serviria para a programação ideal. A Task 05 já deixou `rename`, `setElapsed`, `addItem` e `removeItem` prontos no `MeetingTimerService`, e a Task 09 os expôs no `MeetingNotifier`; faltava a interface que os aciona. O `ItemRow` da Task 11 já nascera com um `onLongPress` opcional, até aqui não ligado.

## O que foi feito

Toque longo em qualquer linha da lista abre uma folha inferior (`showModalBottomSheet`) com o rótulo e o tempo atual do item no cabeçalho e três opções — Editar, Adicionar abaixo e Remover —, cada uma com uma descrição de uma linha e alvo de toque bem acima dos 48dp.

- **Editar** abre um diálogo com o nome e dois campos numéricos (minutos e segundos), pré-preenchidos com o tempo que a lista está mostrando naquele instante, isto é, `effectiveElapsed(DateTime.now())` — o acumulado somado ao trecho ainda aberto. Os campos aceitam só dígitos; a conversão é feita por `parseDurationInput`, de modo que 90 segundos viram 1 min 30 s. Ao salvar são chamados `rename` e, em seguida, `setElapsed` no notifier. Com o item correndo, o diálogo avisa em amarelo que a contagem segue a partir do tempo informado — o `setElapsed` do service reancora o `runningSince` no instante atual.
- **Adicionar abaixo** abre um diálogo com o nome e um `SegmentedButton` de Parte / Sub-item, e chama `addItem(afterId: item.id, …)`, que insere logo abaixo da origem, na mesma seção.
- **Remover** pede confirmação dizendo qual item sai e quanto tempo (`MM:SS`) vai embora junto, e só então chama `removeItem`.

## Arquivos criados

- `lib/widgets/item_actions_menu.dart` — a folha inferior do toque longo e o orquestrador `showItemMaintenanceMenu`, único ponto de entrada dos três diálogos; despacha ao `MeetingNotifier` a operação escolhida.
- `lib/widgets/edit_item_dialog.dart` — diálogo de edição de nome e tempo; devolve um `ItemEdit` (label + `Duration`) ou `null` no cancelamento.
- `lib/widgets/add_item_dialog.dart` — diálogo de inclusão; devolve um `NewItemDraft` (label + `isSubItem`) ou `null`.
- `lib/widgets/remove_item_dialog.dart` — confirmação de remoção; devolve `bool`.

## Arquivos modificados

- `lib/screens/meeting_screen.dart` — `_buildLinha` passa a ligar o `onLongPress` do `ItemRow` ao novo `_abrirMenuDoItem`, que decide se o item é removível e chama `showItemMaintenanceMenu`.

## Decisões técnicas

- **Menu em folha inferior, não `PopupMenuButton`.** O toque longo acontece com o celular na mão, no escuro; uma folha na base da tela fica ao alcance do polegar e comporta rótulo, tempo e descrição de cada ação, coisa que um menu flutuante sobre o ponto do toque não comporta.
- **Um arquivo por diálogo, mais um orquestrador.** Segue o padrão da pasta (um widget por arquivo) e mantém cada diálogo puro: eles só coletam e devolvem dados (`ItemEdit`, `NewItemDraft`, `bool`), sem tocar em provider. Quem conhece o notifier é só o `showItemMaintenanceMenu`, do mesmo jeito que o `ControlPanel` da Task 13.
- **A tela não abre diálogo nenhum.** `meeting_screen.dart` ganhou uma única chamada; a sequência menu → diálogo → notifier fica na camada de widgets, como a task pediu.
- **`rename` antes de `setElapsed`.** Nessa ordem o reancoramento do trecho aberto é a última coisa a acontecer, e o tempo perdido entre as duas gravações é o da persistência do rename, não o inverso.
- **Tempo pré-preenchido com o efetivo, não com o `elapsed` cru.** Se o item corre, o `elapsed` do model está defasado do que a tela mostra; abrir o diálogo com um número menor do que o visível confundiria o usuário no meio da reunião.
- **Remoção escondida para Comentários iniciais e finais.** Esses dois vivem fora das seções e o `removeItem` do service, que varre só as seções, não os alcança — a opção sumiria sem efeito. Em vez de deixar um botão que não faz nada, a tela não o oferece; nome e tempo dos dois continuam editáveis. A regra fica na UI, sem tocar no service.
- **Campos numéricos com `FilteringTextInputFormatter.digitsOnly` e limite de 3 dígitos.** Evita sinal de menos e separadores, e ainda comporta itens de mais de 100 minutos. Campo vazio conta como zero, para o usuário poder apagar e digitar de novo sem que o formulário reclame.
- **`context.mounted` depois do `await` da folha inferior.** Exigência do `use_build_context_synchronously`; depois disso só se toca no notifier, que foi capturado antes.

## Como validar

Com a lista carregada (baixada ou montada na mão):

1. Toque longo em uma parte → a folha abre com o nome e o tempo do item.
2. **Editar**: mude o nome e ponha `1` minuto e `90` segundos → a linha passa a mostrar `02:30`.
3. Inicie o cronômetro, toque longo no item que está correndo e edite o tempo para `05:00` → a linha continua correndo, agora a partir de 05:00, sem saltar de volta.
4. **Adicionar abaixo** em uma parte, escolhendo Sub-item → a linha nova aparece imediatamente abaixo, indentada, com `00:00`.
5. **Remover** um item com tempo → a confirmação cita o `MM:SS` que será perdido; confirmando, o item some; se ele estava correndo, o cronômetro para; se estava selecionado, a seleção recua.
6. Toque longo em `Comentários iniciais` → só Editar e Adicionar abaixo aparecem.
7. Feche e reabra o app depois de qualquer uma dessas operações → o estado editado é restaurado (cada operação do notifier persiste).

## Resultado da validação

- `flutter analyze` — **No issues found!**
- `flutter test` — **190 testes, todos passando** (a suíte existente segue verde; esta task é de UI e, conforme a spec, não trouxe testes próprios).
- Revisão manual do código e das camadas: os diálogos não contêm regra de negócio nem acesso a dados, a conversão de tempo é delegada a `parseDurationInput` (Utils) e toda mutação passa pelo `MeetingNotifier` (Providers) → `MeetingTimerService` (Services). Nenhum arquivo fora de `lib/widgets/` e de `lib/screens/meeting_screen.dart` foi tocado.
