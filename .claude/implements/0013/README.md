# [0013] Tela principal com a lista da reunião

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto
**Spec:** `.claude/specs/0001/` — Task 12

## Solicitação

> Spec 0001 — Task 12: Implemente `lib/screens/meeting_screen.dart` e aponte a `home` do `MaterialApp` em `lib/main.dart` para ela. A tela consome os providers da Task 09 e usa os widgets da Task 11.
>
> Estados a cobrir: sem relatório carregado, mostra um estado vazio com botão "Baixar programação"; durante a busca, indicador de progresso; em erro, a mensagem do provider mais um botão de tentar de novo e a opção de montar a lista na mão (relatório vazio só com os itens fixos). Com relatório carregado, mostra `Início da reunião: HH:MM` no topo (ou vazio antes de começar), a lista rolável na ordem canônica com os cabeçalhos das três seções, e `Fim da reunião: HH:MM` ao final quando já encerrado.
>
> A lista redesenha a cada tick de 1 segundo do provider de tick, calculando o tempo por `effectiveElapsed(DateTime.now())`. Item selecionado e item que corre recebem destaques visuais **distintos** — são conceitos diferentes e o usuário precisa enxergar os dois ao mesmo tempo. A lista rola sozinha para manter o item selecionado visível quando a seleção muda. Tocar num item o seleciona.
>
> Deixe espaço reservado no rodapé para o painel de controle, que chega na Task 13. Sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Screens e no `home` de `lib/main.dart`; não modifique arquivos de outras camadas.

## Contexto

Até aqui o app tinha todas as camadas prontas — models, services, repositories, providers (Task 09) e os widgets de apresentação (Task 11) — mas nenhuma tela: a `home` do `MaterialApp` era um `Scaffold` vazio deixado pela Task 10. Esta task fecha o circuito e torna o app utilizável: é a primeira vez que o estado do `MeetingNotifier` aparece na interface.

## O que foi feito

Criada a `MeetingScreen`, um `ConsumerStatefulWidget` que observa `meetingProvider`, `scheduleFetchProvider` e `tickProvider`, e faz o roteamento entre quatro estados de tela:

1. **Restaurando** — enquanto `MeetingNotifier.restored` não conclui, mostra progresso, para o estado vazio não piscar por cima de uma reunião já em andamento no disco.
2. **Vazio** — sem relatório e sem busca em curso: painel central com o botão "Baixar programação".
3. **Carregando** — `ScheduleFetchState.isLoading` sem relatório: `CircularProgressIndicator` com legenda. Com relatório já montado, o progresso vira uma `LinearProgressIndicator` fina no topo, para não esconder a lista.
4. **Erro** — a mensagem vinda do provider, mais "Tentar de novo" (`downloadSchedule`) e "Montar a lista na mão" (`startManualReport`, que gera o relatório só com os itens fixos e as três seções vazias).

Com relatório carregado, a tela desenha `Início da reunião: HH:MM` (valor em branco antes do primeiro início), a lista na ordem canônica — `Comentários iniciais`, as três seções com `SectionHeader` e seus itens, `Comentários finais` —, e `Fim da reunião: HH:MM` ao final quando `endedAt` está preenchido. O rodapé fixo reserva 120dp para o painel de controle da Task 13.

A `home` do `MaterialApp` passou a apontar para `MeetingScreen` e o `_HomePlaceholder` da Task 10 foi removido.

## Arquivos modificados

- `lib/main.dart` — `home` agora é `const MeetingScreen()`; removido o `_HomePlaceholder`.

## Arquivos criados

- `lib/screens/meeting_screen.dart` — tela principal: estados de carga, lista viva do relatório, rolagem automática e o espaço reservado do painel de controle.

## Decisões técnicas

- **Coluna rolável em vez de `ListView` preguiçosa.** `Scrollable.ensureVisible` precisa que o item de destino esteja montado; numa `ListView` o item selecionado fora da viewport ainda não tem `RenderObject` e a rolagem falharia justamente quando é mais necessária (setas percorrendo a lista). São poucas dezenas de linhas, então `SingleChildScrollView` + `Column` custa pouco e sempre funciona.
- **Uma `GlobalKey` por item, guardada num mapa por `id`.** Chaves de itens que saem do relatório (remoção, reset) são descartadas a cada build para o mapa não crescer sem limite.
- **Rolagem disparada por mudança de `selectedItemId`**, comparado com o último visto e agendado em `addPostFrameCallback` — assim funciona tanto para o toque quanto para as setas do painel que chega na Task 13, sem a tela precisar saber quem mudou a seleção.
- **Selecionado e correndo continuam separados.** A tela só repassa as duas flags ao `ItemRow`, que já as distingue: barra lateral colorida para seleção, fundo tingido e negrito para o item que corre. Os dois podem estar ativos ao mesmo tempo, no mesmo item ou em itens diferentes.
- **`accentColor` por seção.** Itens de seção recebem `AppTheme.sectionColor(kind)`; os itens fixos (comentários) ficam com a cor primária do tema. Nenhum literal de cor de seção foi repetido aqui.
- **`ref.watch(tickProvider)` sem usar o valor.** O tick só provoca o rebuild; o tempo é sempre recalculado por `effectiveElapsed(DateTime.now())`, coerente com a regra de timestamps absolutos do `CLAUDE.md`. Como o provider é `autoDispose`, o timer para sozinho quando a tela sai.
- **Opção de montar na mão só no estado de erro**, como a task pede — no estado vazio o caminho normal é baixar, e oferecer as duas saídas ali confundiria o uso principal.
- **Nenhuma regra de negócio na tela**: toda mutação passa pelo `MeetingNotifier` (`downloadSchedule`, `startManualReport`, `select`). A camada Screens não importa services nem repositories.

## Como validar

1. `flutter run` com o dispositivo conectado.
2. Sem programação baixada, a tela abre no estado vazio; tocar em "Baixar programação" mostra o progresso e, com internet, monta a lista com as três seções.
3. Com o Wi-Fi e os dados desligados, o mesmo botão leva ao estado de erro com a mensagem do repositório; "Tentar de novo" repete a busca e "Montar a lista na mão" abre o relatório só com os itens fixos.
4. Tocar num item o seleciona (barra lateral colorida). Quando o painel da Task 13 chegar, iniciar o cronômetro deve destacar o item que corre com fundo tingido, simultaneamente e de forma distinta da seleção.
5. Fechar e reabrir o app com uma reunião em andamento: a lista volta com os tempos, sem piscar o estado vazio.

## Resultado da validação

- `flutter analyze` — **No issues found!**
- `flutter test` — **190 testes, todos passando** (a mudança em `main.dart` não afeta a suíte).
- `dart format` aplicado aos arquivos tocados.
- Task de UI, sem testes próprios, conforme a instrução da task.
- Revisão de camadas: a tela só conversa com `lib/providers/`, `lib/widgets/`, `lib/models/` e `lib/utils/` — nenhum import de `services/` ou `repositories/`, nenhuma regra de negócio ou I/O.
