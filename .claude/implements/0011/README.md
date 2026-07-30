# [0011] Providers Riverpod: estado do relatório, tick do cronômetro e estado da busca

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto
**Spec:** `.claude/specs/0001/` — Task 09

## Solicitação

> Spec 0001 — Task 09: Implemente os providers Riverpod em `lib/providers/` (sugestão: `dependencies_provider.dart` para as instâncias de services/repositories e `meeting_provider.dart` para o estado). O `MeetingNotifier` (um `StateNotifier<MeetingReport?>`) é a única porta de entrada da UI.
>
> Ele deve expor: carregar o relatório salvo ao iniciar; baixar a programação (repositório HTTP → parser → `ReportBuilder`) e substituir o estado; e repassar cada operação do `MeetingTimerService` (start, pause, next, selectPrevious, selectNext, endMeeting, reset, rename, setElapsed, addItem, removeItem). **Toda** mutação de estado grava no `ReportStorageRepository` logo em seguida.
>
> Exponha também um provider separado que emite um tick de 1 em 1 segundo (`Stream.periodic`) só para a UI redesenhar o cronômetro — o tick **não** altera o estado do relatório; o tempo mostrado é sempre calculado por `effectiveElapsed(DateTime.now())`. E um provider de estado da busca (ocioso / carregando / erro com mensagem), para a tela reagir à falta de internet.
>
> Toda a lógica fica nos services: o notifier só orquestra e persiste. Não duplique regra de negócio aqui, não faça parsing e não chame `http` direto. Esta task é de fiação, sem testes unitários próprios; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Providers; não modifique arquivos de outras camadas.

## Contexto

As tasks 03 a 08 entregaram services e repositories isolados, sem nada que os ligasse. A camada Providers é a cola: instancia as dependências, guarda o estado vivo do relatório e garante a persistência a cada mudança — requisito duro do projeto, já que uma reunião de 1h45 não se repete. Sem esta task as telas (12 a 15) não teriam de onde ler nem para onde escrever.

## O que foi feito

Três arquivos novos em `lib/providers/`:

1. **`dependencies_provider.dart`** — um provider por dependência: `clockProvider` (`DateTime.now`, único ponto do app que conhece o relógio real), `wolRepositoryProvider`, `reportStorageRepositoryProvider`, `imageExportRepositoryProvider`, `scheduleParserProvider`, `reportBuilderProvider` e `meetingTimerServiceProvider` (já com o relógio injetado).

2. **`meeting_provider.dart`** — `MeetingNotifier extends StateNotifier<MeetingReport?>`, exposto por `meetingProvider`, mais o estado da busca (`ScheduleFetchStatus`, `ScheduleFetchState`, `ScheduleFetchNotifier`, `scheduleFetchProvider`).

   O notifier começa a restaurar o relatório salvo no próprio construtor e expõe `restored` (um `Future`) para a tela saber quando a restauração terminou. `downloadSchedule()` percorre `WolRepository → ScheduleParser → ReportBuilder` e substitui o estado, movendo o estado da busca entre carregando/ocioso/erro. Todas as operações do cronômetro são repassadas ao `MeetingTimerService` e passam pelo mesmo par `_apply`/`_replace`, que publica o novo relatório e grava no `ReportStorageRepository` em seguida.

3. **`tick_provider.dart`** — `tickProvider`, um `StreamProvider.autoDispose<DateTime>` com `Stream.periodic` de 1 segundo, só para forçar rebuild da UI.

## Arquivos modificados

Nenhum.

## Arquivos criados

- `lib/providers/dependencies_provider.dart` — instâncias de services e repositories, mais o relógio do app.
- `lib/providers/meeting_provider.dart` — `MeetingNotifier` (estado do relatório) e estado da busca da programação.
- `lib/providers/tick_provider.dart` — tick de 1 segundo para o redesenho do cronômetro.

## Decisões técnicas

- **Persistência centralizada em um único ponto.** Toda mutação passa por `_apply` → `_replace`, que faz `state = report` e depois `_storage.save(report)`. Nenhum método pode esquecer de gravar porque nenhum método mexe em `state` diretamente. O estado é publicado antes da escrita para a tela responder na hora, com a gravação logo atrás.
- **`_apply` recebe a operação do service como função.** Cada método público do notifier é uma linha (`Future<void> start() => _apply(_timer.start);`), o que deixa explícito que ele não decide nada — só delega e persiste.
- **A restauração não regrava.** `_restoreSaved` só faz `state = salvo`, sem passar por `_replace`: reescrever no disco o que acabou de vir dele seria trabalho à toa.
- **Estado da busca em notifier próprio, não em `AsyncValue` do relatório.** O relatório e a busca têm ciclos de vida diferentes: uma falha de download não pode apagar a reunião que já está na tela. Separar os dois deixa a tela mostrar o erro de rede por cima de um relatório em andamento.
- **Erros de domínio viram mensagem, nunca exceção solta.** `downloadSchedule` captura `WolFetchException` e `ScheduleParseException` e joga o `message` (já em português, escrito pelas tasks 03 e 06) no estado da busca. Qualquer outro erro sobe — se não é um dos dois, é bug, e engolir esconderia o problema.
- **Guardas de `mounted` depois de cada `await`.** O notifier faz I/O; escrever em `state` (ou no notifier da busca) após o descarte lançaria `StateError`.
- **`tickProvider` é `autoDispose` e emite `DateTime`, não um contador.** Sem ninguém olhando o cronômetro o timer para. O valor emitido é irrelevante para o cálculo — o tempo continua vindo de `effectiveElapsed(DateTime.now())` sobre timestamps absolutos, como manda o `CLAUDE.md`; o stream só provoca o rebuild.
- **Duas operações além da lista da task, ambas exigidas pelas tasks seguintes, que não podem tocar em Providers:**
  - `select(String id)` — a Task 12 pede "tocar num item o seleciona", e o `MeetingTimerService` só tem as setas. É um `copyWith(selectedItemId:)` guardado por `itemById`, sem regra nova.
  - `startManualReport()` — a Task 12 pede a opção de montar a lista na mão quando o download falha. Chama o `ReportBuilder` com as três seções vazias. As seções precisam existir mesmo sem partes porque `MeetingTimerService.addItem` não insere nada num relatório sem seções; os títulos usados são os mesmos que o parser extrai do site.
- **`ImageExportRepository` já provido aqui**, embora só a Task 15 vá usá-lo: aquela task está restrita às camadas Widgets e Screens e não poderia criar o provider.
- **Dependências privadas com initializing formals nomeados** (`required this._timer`). O notifier é a única porta de entrada da UI, então ela não deve alcançar repositórios por dentro dele; o SDK (Dart 3.12) aceita parâmetro nomeado privado e expõe o nome sem o `_`, o que mantém `flutter analyze` limpo sem `ignore`.

## Como validar

1. `flutter analyze` — precisa passar sem nenhum issue.
2. `flutter test` — nenhum teste desta camada, mas nada pode ter quebrado nas outras.
3. Manual, com a Task 12 pronta: abrir o app sem internet e tocar em "Baixar programação" — o estado da busca deve ir para erro com a mensagem do `WolRepository`. Com internet, o relatório da semana deve aparecer montado. Iniciar o cronômetro, fechar o app e reabrir: a reunião volta com os tempos certos, e o item que estava correndo segue contando a partir do timestamp gravado.

## Resultado da validação

- `flutter analyze` → **No issues found!**
- `flutter test` → 179 testes passando. A única falha é em `test/integration/meeting_flow_test.dart`, arquivo da Task 16, que estava sendo escrita em paralelo — fora do escopo desta task e sem relação com a camada Providers.
- Revisão de camadas: os providers não fazem parsing, não chamam `http` e não contêm regra de cronômetro — tudo é delegado a `ScheduleParser`, `ReportBuilder`, `MeetingTimerService`, `WolRepository` e `ReportStorageRepository`. Nenhum arquivo fora de `lib/providers/` foi tocado.
