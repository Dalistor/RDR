# [0009] Máquina de estados do cronômetro e edição de itens

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 05

## Solicitação

> Spec 0001 — Task 05: Implemente por TDD a máquina de estados do cronômetro em `lib/services/meeting_timer_service.dart`, com testes em `test/services/meeting_timer_service_test.dart`. Cada operação recebe um `MeetingReport` e devolve um novo `MeetingReport` (funções puras, sem estado interno). O relógio entra por um `Clock` injetado (`typedef Clock = DateTime Function()`) — nunca chame `DateTime.now()`. Leia "Controle de tempo" no `CLAUDE.md`. Esta é a task mais delicada da spec: a distinção entre **item que corre** (`runningItemId`) e **item selecionado** (`selectedItemId`) é o coração do app.
>
> Toque apenas na camada Services (pode importar Models e Utils); não modifique arquivos de outras camadas.

## Contexto

O relatório já sabia se descrever (Task 02) e se montar a partir da programação (Task 04), mas nada sabia cronometrar. Esta task concentra toda a regra de tempo e de mutação do relatório num único service puro, para que o notifier da Task 09 seja só orquestração e persistência, e para que o comportamento do cronômetro possa ser verificado sem Flutter engine e sem relógio real.

O ponto central é a separação entre **item que corre** (`runningItemId`, quem está acumulando tempo) e **item selecionado** (`selectedItemId`, o destaque na tela). As setas mexem só na seleção; `Próximo` mexe nos dois. Confundir os dois é o defeito mais caro possível neste app: a reunião acontece uma vez só.

O tempo é medido por timestamps absolutos (`runningSince` + soma dos trechos fechados), nunca por acumulador de `Timer` — assim o cronômetro não desanda com a tela apagada.

## Critérios de aceite

- `start`: na primeira vez grava `startedAt` com o relógio; põe a correr o item selecionado, ou o primeiro da ordem canônica se nada estiver selecionado; define `runningSince` desse item; sincroniza `selectedItemId` com ele. Um `start` posterior não sobrescreve o `startedAt` original.
- `pause`: fecha o trecho aberto somando `now - runningSince` ao `elapsed` do item que corre, zera o `runningSince` e limpa `runningItemId`. `pause` sem nada correndo devolve o relatório inalterado.
- `next`: fecha o trecho do item corrente igual ao `pause` e imediatamente põe a correr o próximo item da ordem canônica, movendo também a seleção. Se o item corrente é o último, fecha o trecho e para, sem estourar índice e sem encerrar a reunião.
- `next` sem nada correndo inicia o item seguinte ao selecionado (ou o primeiro, se nada selecionado).
- `selectPrevious` / `selectNext`: mudam só o `selectedItemId`, um passo na ordem canônica. O item que está correndo continua correndo, com `runningSince` e `runningItemId` intocados. Nas bordas da lista a seleção não se move e nada quebra.
- `endMeeting`: fecha o trecho corrente e grava `endedAt` com o relógio. Chamado duas vezes, não altera o `endedAt` já gravado.
- `reset`: devolve o relatório com todos os itens em `Duration.zero` e `runningSince` nulo, `startedAt`, `endedAt` e `runningItemId` nulos, mas preserva a estrutura: `weekLabel`, seções, labels e itens adicionados manualmente.
- `rename(id, label)`: troca o label de qualquer item (fixo, parte ou sub-item) sem tocar em tempos.
- `setElapsed(id, duration)`: define o `elapsed` do item. Se esse item estiver correndo, o `runningSince` passa a ser o instante atual, de modo que a contagem siga a partir do novo valor em vez de reaplicar o trecho já aberto.
- `addItem(afterId, label, isSubItem)`: insere um item novo, zerado, imediatamente após o item indicado, na mesma seção dele (ou entre os fixos, se for o caso), com `id` único. Inserir depois do último item do relatório funciona.
- `removeItem(id)`: remove o item. Se ele estiver correndo, o cronômetro para (`runningItemId` nulo); se estiver selecionado, a seleção vai para o item anterior, ou para o primeiro se não houver anterior.
- Um item que corre e é medido em dois trechos separados (start, pause, start, pause com o relógio avançando) acumula a soma dos dois trechos.

## Ciclos TDD

Todos os testes ficam em `test/services/meeting_timer_service_test.dart`.

| # | Caso de teste | Código que passou a existir |
|---|---------------|------------------------------|
| 1 | start grava startedAt e arranca o primeiro item quando nada está selecionado | `MeetingTimerService`, `typedef Clock`, `start`, helper `_mapearItens` |
| 2 | start arranca o item selecionado, e não o primeiro da ordem | `_itemSelecionadoOuPrimeiro` |
| 3 | start um start posterior não sobrescreve o startedAt original | `startedAt: report.startedAt ?? agora` |
| 4 | start com outro item correndo, fecha o trecho dele antes de arrancar | `_fecharTrechoAberto` e `_arrancar` |
| 5 | pause soma o trecho aberto ao elapsed e para o cronômetro | `pause` |
| 6 | pause sem nada correndo devolve o próprio relatório, sem reconstruir | guarda `runningItemId == null` em `pause` |
| 7 | pause dois trechos separados do mesmo item somam no elapsed | — (composição já implementada; teste de regressão) |
| 8 | next fecha o trecho do item corrente e arranca o próximo, levando a seleção | `next`, `_itemApos` |
| 9 | next no último item fecha o trecho, para, e não encerra a reunião | guarda `proximo == null` |
| 10 | next sem nada correndo, arranca o item seguinte ao selecionado | `runningItemId ?? selectedItemId` |
| 11 | next sem nada correndo e sem seleção, arranca o primeiro item | ramo `corrente == null` |
| 12 | next parado no último item selecionado não arranca nada | — (borda já coberta pela guarda do ciclo 9) |
| 13 | selectNext anda um passo na ordem sem parar o item que corre | `selectNext` |
| 14 | selectNext no último item não move a seleção | guarda de borda superior |
| 15 | selectNext sem seleção nenhuma seleciona o primeiro item | helper `_mover(report, passo)` |
| 16 | selectPrevious anda um passo para trás sem parar o item que corre | `selectPrevious` |
| 17 | selectPrevious no primeiro item não move a seleção | — (guarda de borda inferior do `_mover`) |
| 18 | selectPrevious sem seleção nenhuma seleciona o primeiro item | — |
| 19 | as setas percorrem a ordem canônica inteira, ida e volta | — (teste de regressão da ordem completa) |
| 20 | endMeeting fecha o trecho corrente e grava endedAt | `endMeeting` |
| 21 | endMeeting chamado duas vezes não altera o endedAt já gravado | `endedAt: report.endedAt ?? agora` |
| 22 | reset zera tempos e estado do cronômetro preservando a estrutura | `reset` |
| 23 | rename troca o label de um sub-item sem tocar nos tempos | `rename` |
| 24 | rename troca o label de um item fixo | — |
| 25 | rename com id inexistente devolve o relatório inalterado | — |
| 26 | setElapsed define o tempo de um item parado sem mexer no cronômetro | `setElapsed` |
| 27 | setElapsed no item que corre, a contagem segue a partir do novo valor | reancoragem do `runningSince` em `setElapsed` |
| 28 | addItem insere um item zerado logo depois do indicado, na mesma seção | `addItem`, `_inserirApos`, `_novoId` |
| 29 | addItem inserções sucessivas geram ids diferentes | varredura de ids usados em `_novoId` |
| 30 | addItem marca o item novo como sub-item quando pedido | — |
| 31 | addItem depois do último item de uma seção insere no fim dela | — |
| 32 | addItem depois do item fixo de abertura insere no início da primeira seção | ramo dos itens fixos, `_trocarSecao` |
| 33 | addItem depois do item fixo de fechamento insere no fim da última seção | ramo dos itens fixos |
| 34 | addItem com id inexistente devolve o relatório inalterado | — |
| 35 | addItem num relatório sem seções não há onde inserir: devolve inalterado | guarda `sections.isEmpty` |
| 36 | removeItem tira o item da seção e o resto continua na ordem | `removeItem` |
| 37 | removeItem remover o item que corre para o cronômetro | `clearRunningItemId: report.runningItemId == id` |
| 38 | removeItem remover o item selecionado leva a seleção para o item anterior | `_selecaoAposRemover` |
| 39 | removeItem remover um item não selecionado não mexe na seleção | — |
| 40 | removeItem remover o primeiro item de uma seção seleciona o item que o precede | — |
| 41 | removeItem com id inexistente devolve o relatório inalterado | — |
| 42 | removeItem os itens fixos não são removíveis: o relatório fica inteiro | — |
| 43 | removeItem sem item anterior, a seleção vai para o primeiro item | ramo de fallback de `_selecaoAposRemover` |

Nos ciclos 17-19, 24-25, 30-31, 34 e 39-42 o teste ficou verde de imediato porque o código escrito no ciclo anterior já generalizava o caso (guardas de borda do `_mover`, `_mapearItens` que simplesmente não casa o id, `_inserirApos` no fim da lista). Eles foram mantidos como cobertura explícita dos critérios de aceite e travam a borda contra regressão.

## O que foi feito

`MeetingTimerService` implementa as onze operações do painel de controle como funções puras `MeetingReport → MeetingReport`. O relógio é o `typedef Clock = DateTime Function()` recebido no construtor; o service não tem estado interno e não chama `DateTime.now()`.

O núcleo são quatro helpers privados:

- `_mapearItens` — reconstrói o relatório aplicando uma transformação a todos os itens, onde quer que estejam (fixos, partes, sub-itens). Todas as operações de mutação passam por ele.
- `_fecharTrechoAberto` — soma `agora - runningSince` ao `elapsed` de qualquer item correndo, limpa o `runningSince` e o `runningItemId`. É o mesmo fechamento usado por `pause`, `next`, `start` e `endMeeting`, o que garante que nenhum caminho perca tempo já corrido.
- `_arrancar` — abre um trecho num item e leva `runningItemId` e `selectedItemId` junto.
- `_mover` — anda um passo com a seleção, sem tocar no cronômetro.

Com isso a distinção entre correr e selecionar fica explícita no código: só `_arrancar` mexe em `runningItemId`, e só `_mover` mexe em `selectedItemId` isoladamente.

## Arquivos criados

- `lib/services/meeting_timer_service.dart` — o service e o `typedef Clock`.
- `test/services/meeting_timer_service_test.dart` — 43 testes, com relógio falso (`RelogioFalso`) e um relatório de 12 itens cobrindo as três seções, sub-itens e os dois itens fixos.

## Arquivos modificados

Nenhum. A task não tocou em nenhuma outra camada.

## Decisões técnicas

- **`typedef Clock` mora no service**, não em `utils/`, porque é o contrato de injeção desta camada; a Task 09 e a Task 16 importam daqui.
- **`start` fecha o trecho aberto antes de arrancar.** O critério não exige, mas na prática protege contra perda de tempo: se um item já corre e o usuário arranca outro, o trecho aberto é banqueado em vez de descartado. Quando o item selecionado é o próprio que corre, fechar e reabrir no mesmo instante é idempotente.
- **`pause` sem nada correndo devolve a mesma instância** (`identical`), não uma cópia equivalente. Além de ser o significado literal de "inalterado", evita que a Task 09 grave no `shared_preferences` a cada toque inútil.
- **`next` não grava `startedAt`.** Só `Iniciar` marca o início da reunião, conforme "Controle de tempo" no `CLAUDE.md`.
- **`reset` também limpa `selectedItemId`.** O critério lista `startedAt`, `endedAt` e `runningItemId`, mas manter a seleção no meio da lista faria a próxima reunião começar do item errado. "Zera tudo" ganhou da leitura literal.
- **Ids de itens adicionados na mão são `manual-N`**, com N escolhido varrendo os ids já usados. É determinístico e único sem precisar injetar um segundo colaborador (gerador de uuid) só para poder testar.
- **Posição do item novo quando o âncora é um item fixo.** `openingComments` e `closingComments` moram fora das seções, então não existe slot "entre os fixos" no model da Task 02: inserir depois da abertura coloca o item no topo da primeira seção, e inserir depois do fechamento o coloca no fim da última. São as duas únicas posições representáveis. Num relatório sem seções não há onde inserir e a operação devolve o relatório intacto.
- **Itens fixos não são removíveis.** `MeetingReport.openingComments` e `closingComments` são campos não-anuláveis: não há como representar um relatório sem eles. `removeItem` nesses ids é um no-op silencioso em vez de exceção — durante uma reunião ao vivo, nenhuma operação de edição pode derrubar o app.
- **Id inexistente nunca lança.** `rename`, `setElapsed`, `addItem` e `removeItem` devolvem o relatório inalterado. Mesma razão: uma reunião de 1h45 não pode ser perdida por um id defasado vindo da UI.
- **O fallback "primeiro item" de `_selecaoAposRemover`** é alcançado quando o item removido está no índice 0 da ordem canônica — o que hoje só acontece ao pedir a remoção da abertura estando ela selecionada (no-op estrutural, seleção preservada). Ficou coberto pelo ciclo 43 e é a defesa que mantém a operação total caso a estrutura do relatório mude.
- **Nada foi mockado.** O único colaborador externo é o relógio, e ele é uma função injetada; o resto são models de valor reais. Nenhum teste toca rede, disco ou `DateTime.now()`.

## Como validar

```bash
flutter test test/services/meeting_timer_service_test.dart
flutter test --coverage
flutter analyze
```

## Resultado da validação

- `flutter test test/services/meeting_timer_service_test.dart` → **43 testes passando**, 0 falhas.
- `flutter test` (suíte inteira, com as tasks paralelas da spec já integradas) → **173 testes passando**, nenhuma regressão.
- `flutter test --coverage` → `lib/services/meeting_timer_service.dart`: **LF 118 / LH 118 = 100% de cobertura de linha**. O `lcov.info` gerado pelo `flutter test` não traz registros de branch (`BRF`/`BRH`), então não há número de cobertura de branch a reportar; as bordas foram cobertas explicitamente por teste (primeiro e último item da ordem, lista sem seleção, relatório sem seções, id inexistente, item fixo).
- `flutter analyze` → **No issues found!**
