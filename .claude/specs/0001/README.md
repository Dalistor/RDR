# [0001] App RDR completo — cronômetro e relatório da reunião Vida e Ministério

**Data:** 2026-07-30
**Status:** Concluída
**Solicitação original:** App RDR completo: scraping da programação de Vida e Ministério do wol.jw.org, montagem do relatório com sub-itens automáticos por seção, painel de controle de tempo (iniciar/pausar/resetar com confirm/próximo/setas sem pausar), edição manual de nome e tempo das partes, adicionar e remover partes, persistência local, e print longo em PNG único com compartilhamento.

## Objetivo

Ao término das 16 tasks, o app Android deve: baixar a programação da semana corrente do wol.jw.org, montar automaticamente a lista de itens cronometráveis (partes + sub-itens fixos por seção + comentários iniciais/finais), permitir cronometrar a reunião inteira com painel de controle, editar/adicionar/remover itens a qualquer momento, sobreviver a reload sem perder o estado, e exportar o relatório completo como um PNG único salvo na galeria e compartilhável.

## Contexto técnico

Leia o `CLAUDE.md` da raiz antes de qualquer task — ele traz a Arquitetura de Camadas, os seletores do scraping já verificados no HTML real, a regra dos sub-itens e as restrições do projeto.

### Estado do projeto

Scaffold `flutter create` limpo. `lib/main.dart` é o contador padrão do Flutter (será substituído). Pastas de camada criadas e vazias. Dependências já instaladas: `flutter_riverpod`, `http`, `html`, `shared_preferences`, `screenshot`, `share_plus`, `gal`, `path_provider`, `intl`, `mocktail`.

### Fixtures de HTML real (já commitadas)

- `test/fixtures/meetings_week_2026_31.html` — página de semana (`/pt/wol/meetings/r5/lp-t/` após redirect)
- `test/fixtures/mwb_2026_31.html` — documento da apostila Vida e Ministério

Nenhum teste pode bater na rede. Use sempre as fixtures.

### Contrato dos models (todas as tasks dependem disto — não divergir)

```dart
enum SectionKind { treasures, ministry, christianLife }

class TimedItem {
  final String id;            // uuid ou contador estável
  final String label;         // "1. Ele pregou com coragem" | "Presidente" | "Comentários iniciais"
  final Duration elapsed;     // acumulado dos trechos já fechados
  final DateTime? runningSince; // null = parado
  final bool isSubItem;       // true = renderiza indentado com "•"
}

class MeetingSection {
  final SectionKind kind;
  final String title;         // "TESOUROS DA PALAVRA DE DEUS"
  final List<TimedItem> items;
}

class MeetingReport {
  final String weekLabel;     // "27 de julho–2 de agosto"
  final DateTime? startedAt;
  final DateTime? endedAt;
  final TimedItem openingComments;   // "Comentários iniciais"
  final List<MeetingSection> sections;
  final TimedItem closingComments;   // "Comentários finais"
  final String? runningItemId;
  final String? selectedItemId;
}
```

Regras transversais:

- **Ordem canônica dos itens** (`MeetingReport.orderedItems`): `openingComments` → itens de cada seção na ordem → `closingComments`. É essa ordem que o botão Próximo e as setas percorrem.
- **Tempo decorrido efetivo** de um item: `elapsed + (runningSince == null ? Duration.zero : now.difference(runningSince!))`. Nunca acumular com `Timer`.
- Models são imutáveis: campos `final`, `copyWith`, `toJson`/`fromJson`.
- Nenhum service chama `DateTime.now()` direto — recebe um `Clock` (`typedef Clock = DateTime Function()`) injetado, para o teste controlar o relógio.

### Ordem de execução / paralelismo

| Onda | Tasks |
|------|-------|
| 1 | 01, 02, 06, 08, 10 (paralelizáveis) |
| 2 | 03, 04, 05, 07 (paralelizáveis) |
| 3 | 09, 11 |
| 4 | 12, 15 |
| 5 | 13, 14 |
| 6 | 16 |

## Tasks

### Task 01 — Utilitários de formatação de tempo

**Objetivo:** Funções puras de formatação usadas pela UI e pelo relatório.
**Camadas:** Utils
**Modo:** TDD
**Depende de:** —
**Instrução para o subagente:**
> Spec 0001 — Task 01: Implemente por TDD as funções puras de formatação de tempo em `lib/utils/time_format.dart`, com testes em `test/utils/time_format_test.dart`.
>
> Critérios de aceite (comportamentos observáveis):
> - `formatDuration(Duration)` devolve `MM:SS` com zero à esquerda: `Duration(seconds: 11)` → `"00:11"`; `Duration(minutes: 4, seconds: 12)` → `"04:12"`; `Duration.zero` → `"00:00"`.
> - Passando de 59 minutos, os minutos continuam crescendo em vez de virar hora: `Duration(minutes: 75, seconds: 3)` → `"75:03"`.
> - Duração negativa é tratada como `"00:00"` (não deve aparecer sinal de menos).
> - Milissegundos são truncados, nunca arredondados para cima: `Duration(seconds: 5, milliseconds: 900)` → `"00:05"`.
> - `formatClock(DateTime)` devolve `HH:MM` em 24 horas com zero à esquerda: `DateTime(2026, 7, 30, 20, 0)` → `"20:00"`; `DateTime(2026, 7, 30, 9, 5)` → `"09:05"`.
> - `parseDurationInput(int minutes, int seconds)` devolve a `Duration` correspondente e normaliza segundos ≥ 60 somando aos minutos (`parseDurationInput(1, 90)` → 2min30s); valores negativos viram zero.
>
> Toque apenas na camada Utils; não modifique arquivos de outras camadas.

---

### Task 02 — Models do domínio com serialização JSON

**Objetivo:** Entidades imutáveis do relatório, ordem canônica dos itens e round-trip JSON.
**Camadas:** Models
**Modo:** TDD
**Depende de:** —
**Instrução para o subagente:**
> Spec 0001 — Task 02: Implemente por TDD os models do domínio em `lib/models/` (sugestão: `section_kind.dart`, `timed_item.dart`, `meeting_section.dart`, `meeting_report.dart`), com testes em `test/models/`. Use exatamente o contrato de models descrito na seção "Contexto técnico" da spec `.claude/specs/0001/README.md` — leia esse arquivo antes de começar. Não invente campos além dos listados.
>
> Critérios de aceite (comportamentos observáveis):
> - `TimedItem`, `MeetingSection` e `MeetingReport` são imutáveis (campos `final`) e expõem `copyWith` que troca só o que foi passado e preserva o resto.
> - `TimedItem.effectiveElapsed(DateTime now)` devolve `elapsed` quando `runningSince` é nulo, e `elapsed + now.difference(runningSince!)` quando está correndo.
> - `MeetingReport.orderedItems` devolve, nesta ordem: `openingComments`, os itens de cada seção na ordem das seções e dos itens, e por último `closingComments`.
> - `MeetingReport.itemById(String id)` acha um item em qualquer posição (fixo, de seção ou sub-item) e devolve `null` se não existir.
> - `toJson`/`fromJson` fazem round-trip fiel de um relatório completo: mesmos ids, labels, `elapsed`, `isSubItem`, seções e ordem; `startedAt`, `endedAt` e `runningSince` sobrevivem como `DateTime` (serialize em ISO-8601) e continuam nulos quando eram nulos.
> - `fromJson` com JSON malformado ou campo obrigatório ausente lança uma exceção de domínio própria (ex.: `ReportDecodeException`), não um `TypeError` cru.
> - Igualdade por valor (`==` e `hashCode`) funciona nos três models.
>
> Toque apenas na camada Models; não modifique arquivos de outras camadas.

---

### Task 03 — Parser do HTML do wol.jw.org

**Objetivo:** Extrair, do HTML real, o link da apostila + rótulo da semana e a lista de seções/partes.
**Camadas:** Services
**Modo:** TDD
**Depende de:** Task 02
**Instrução para o subagente:**
> Spec 0001 — Task 03: Implemente por TDD o parser em `lib/services/schedule_parser.dart` (pacote `html`), com testes em `test/services/schedule_parser_test.dart` usando as fixtures reais `test/fixtures/meetings_week_2026_31.html` e `test/fixtures/mwb_2026_31.html`. Leia a seção "Scraping do wol.jw.org" do `CLAUDE.md` — os seletores ali foram verificados no HTML real. Nenhum teste pode acessar a rede.
>
> O parser expõe duas operações. A primeira recebe o HTML da página de semana e devolve o caminho do documento da apostila mais o rótulo da semana. A segunda recebe o HTML do documento e devolve as três seções com suas partes (apenas título; a duração prevista `(10 min)` é ignorada de propósito).
>
> Critérios de aceite (comportamentos observáveis):
> - Na fixture da página de semana, encontra o link `/pt/wol/d/r5/lp-t/202026244` — o link cujo texto contém "Apostila Vida e Ministério" — e **não** o link de A Sentinela.
> - Da mesma fixture extrai o rótulo da semana `"27 de julho–2 de agosto"` (o traço é `–`, U+2013).
> - Se nenhum link de apostila existir no HTML, lança uma exceção de domínio própria (ex.: `ScheduleParseException`) com mensagem clara, nunca devolve nulo silencioso.
> - Na fixture do documento, devolve exatamente 3 seções, nesta ordem e com estes `SectionKind`: `treasures` ("TESOUROS DA PALAVRA DE DEUS", `h2.du-color--teal-700`), `ministry` ("FAÇA SEU MELHOR NO MINISTÉRIO", `h2.du-color--gold-700`), `christianLife` ("NOSSA VIDA CRISTÃ", `h2.du-color--maroon-600`).
> - As partes saem com o número que já vem no texto: Tesouros tem `["1. Ele pregou com coragem", "2. Joias espirituais", "3. Leitura da Bíblia"]`; Faça Seu Melhor tem `["4. Iniciando conversas", "5. Cultivando o interesse", "6. Explicando suas crenças"]`; Nossa Vida Cristã tem `["7. Seja adaptável — mostre interesse pessoal", "8. Estudo bíblico de congregação"]`.
> - `h3` de cântico e oração ("Cântico 73 e oração | Comentários iniciais", "Cântico 57", "Comentários finais (3 min) | Cântico 31 e oração") **não** viram partes.
> - O `h2` do texto bíblico da semana ("JEREMIAS 20-21"), que não tem classe de cor, é ignorado.
> - Os títulos das partes vêm com entidades HTML decodificadas e espaços normalizados (sem `&nbsp;`, sem quebras de linha internas, sem espaço duplo).
> - Um HTML sem nenhuma das três seções lança `ScheduleParseException` em vez de devolver lista vazia.
>
> Toque apenas na camada Services (pode importar Models); não modifique arquivos de outras camadas.

---

### Task 04 — Montagem do relatório com itens fixos e sub-itens automáticos

**Objetivo:** Transformar a programação parseada no `MeetingReport` completo, já com o esqueleto de itens.
**Camadas:** Services
**Modo:** TDD
**Depende de:** Task 02
**Instrução para o subagente:**
> Spec 0001 — Task 04: Implemente por TDD o montador do relatório em `lib/services/report_builder.dart`, com testes em `test/services/report_builder_test.dart`. Ele recebe a programação parseada (seções + títulos de partes) e o rótulo da semana, e devolve um `MeetingReport` zerado e pronto para cronometrar. Leia a regra dos sub-itens no `CLAUDE.md`. Não dependa do parser: monte a entrada à mão nos testes.
>
> Critérios de aceite (comportamentos observáveis), usando a programação da semana de exemplo (Tesouros: partes 1, 2 e "3. Leitura da Bíblia"; Faça Seu Melhor: partes 4, 5, 6; Nossa Vida Cristã: partes 7 e 8):
> - O relatório abre com o item fixo `"Comentários iniciais"` e fecha com o item fixo `"Comentários finais"`, ambos fora das seções e com `isSubItem == false`.
> - Em Tesouros, as partes 1 e 2 recebem um sub-item `"Presidente"` cada.
> - A parte cujo título contém "Leitura da Bíblia" é exceção: recebe `"Conselho"` e `"Transição"`, nessa ordem, e **não** recebe `"Presidente"`.
> - Em Faça Seu Melhor, toda parte recebe `"Conselho"` e `"Transição"`, nessa ordem.
> - Nossa Vida Cristã abre com um item avulso `"Presidente"` com `isSubItem == false`, antes da primeira parte da seção.
> - Em Nossa Vida Cristã, cada parte recebe um sub-item `"Presidente"`, **exceto a última parte da seção**, que fica sem nenhum sub-item.
> - Todos os sub-itens têm `isSubItem == true`; partes e itens fixos têm `isSubItem == false`.
> - Todo item nasce com `elapsed == Duration.zero` e `runningSince == null`; o relatório nasce com `startedAt`, `endedAt`, `runningItemId` e `selectedItemId` nulos e com o `weekLabel` recebido.
> - Todo item tem `id` único dentro do relatório.
> - Uma seção sem partes não quebra a montagem (Nossa Vida Cristã vazia gera só o `"Presidente"` avulso; as demais geram seção vazia).
>
> Toque apenas na camada Services (pode importar Models); não modifique arquivos de outras camadas.

---

### Task 05 — Máquina de estados do cronômetro e edição de itens

**Objetivo:** Toda a regra de tempo e de mutação do relatório, pura e testável.
**Camadas:** Services
**Modo:** TDD
**Depende de:** Task 02
**Instrução para o subagente:**
> Spec 0001 — Task 05: Implemente por TDD a máquina de estados do cronômetro em `lib/services/meeting_timer_service.dart`, com testes em `test/services/meeting_timer_service_test.dart`. Cada operação recebe um `MeetingReport` e devolve um novo `MeetingReport` (funções puras, sem estado interno). O relógio entra por um `Clock` injetado (`typedef Clock = DateTime Function()`) — nunca chame `DateTime.now()`. Leia "Controle de tempo" no `CLAUDE.md`. Esta é a task mais delicada da spec: a distinção entre **item que corre** (`runningItemId`) e **item selecionado** (`selectedItemId`) é o coração do app.
>
> Critérios de aceite (comportamentos observáveis):
> - `start`: na primeira vez grava `startedAt` com o relógio; põe a correr o item selecionado, ou o primeiro da ordem canônica se nada estiver selecionado; define `runningSince` desse item; sincroniza `selectedItemId` com ele. Um `start` posterior **não** sobrescreve o `startedAt` original.
> - `pause`: fecha o trecho aberto somando `now - runningSince` ao `elapsed` do item que corre, zera o `runningSince` e limpa `runningItemId`. `pause` sem nada correndo devolve o relatório inalterado.
> - `next`: fecha o trecho do item corrente igual ao `pause` e imediatamente põe a correr o próximo item da ordem canônica, movendo também a seleção. Se o item corrente é o último, fecha o trecho e para, sem estourar índice e sem encerrar a reunião.
> - `next` sem nada correndo inicia o item seguinte ao selecionado (ou o primeiro, se nada selecionado).
> - `selectPrevious` / `selectNext`: mudam só o `selectedItemId`, um passo na ordem canônica. O item que está correndo **continua correndo**, com `runningSince` e `runningItemId` intocados. Nas bordas da lista a seleção não se move e nada quebra.
> - `endMeeting`: fecha o trecho corrente e grava `endedAt` com o relógio. Chamado duas vezes, não altera o `endedAt` já gravado.
> - `reset`: devolve o relatório com todos os itens em `Duration.zero` e `runningSince` nulo, `startedAt`, `endedAt` e `runningItemId` nulos, mas **preserva** a estrutura: `weekLabel`, seções, labels e itens adicionados manualmente.
> - `rename(id, label)`: troca o label de qualquer item (fixo, parte ou sub-item) sem tocar em tempos.
> - `setElapsed(id, duration)`: define o `elapsed` do item. Se esse item estiver correndo, o `runningSince` passa a ser o instante atual, de modo que a contagem siga a partir do novo valor em vez de reaplicar o trecho já aberto.
> - `addItem(afterId, label, isSubItem)`: insere um item novo, zerado, imediatamente após o item indicado, na mesma seção dele (ou entre os fixos, se for o caso), com `id` único. Inserir depois do último item do relatório funciona.
> - `removeItem(id)`: remove o item. Se ele estiver correndo, o cronômetro para (`runningItemId` nulo); se estiver selecionado, a seleção vai para o item anterior, ou para o primeiro se não houver anterior.
> - Um item que corre e é medido em dois trechos separados (start, pause, start, pause com o relógio avançando) acumula a soma dos dois trechos.
>
> Toque apenas na camada Services (pode importar Models e Utils); não modifique arquivos de outras camadas.

---

### Task 06 — Repositório HTTP do wol.jw.org

**Objetivo:** Buscar HTML do site, com header correto e erros tipados.
**Camadas:** Repositories
**Modo:** TDD
**Depende de:** —
**Instrução para o subagente:**
> Spec 0001 — Task 06: Implemente por TDD o repositório HTTP em `lib/repositories/wol_repository.dart`, com testes em `test/repositories/wol_repository_test.dart`. Ele faz **apenas HTTP** — nada de parsing, que é responsabilidade do service. Receba um `http.Client` por construtor para poder injetar o `MockClient` de `package:http/testing.dart` nos testes. Nenhum teste pode acessar a rede.
>
> A URL de entrada é `https://wol.jw.org/pt/wol/meetings/r5/lp-t/`, que redireciona para a semana corrente; caminhos relativos como `/pt/wol/d/r5/lp-t/202026244` devem ser resolvidos contra `https://wol.jw.org`.
>
> Critérios de aceite (comportamentos observáveis):
> - Buscar a página de semana devolve o corpo em texto e envia um header `User-Agent` de navegador móvel (não o padrão do Dart).
> - O corpo é decodificado como UTF-8: acentos e o traço `–` chegam íntegros, sem mojibake.
> - Buscar um caminho relativo monta a URL absoluta corretamente contra o host do wol.
> - Resposta com status diferente de 200 lança uma exceção de domínio própria (ex.: `WolFetchException`) trazendo o status; não devolve corpo vazio.
> - Falha de rede (o client lança `SocketException`/`ClientException`) vira a mesma `WolFetchException`, com mensagem indicando falta de conexão — a UI depende disso para orientar o usuário, já que o app exige internet para baixar.
> - Um timeout razoável é aplicado à requisição e também resulta em `WolFetchException`.
>
> Toque apenas na camada Repositories; não modifique arquivos de outras camadas.

---

### Task 07 — Repositório de persistência do relatório

**Objetivo:** Salvar e restaurar o relatório em andamento no dispositivo.
**Camadas:** Repositories
**Modo:** TDD
**Depende de:** Task 02
**Instrução para o subagente:**
> Spec 0001 — Task 07: Implemente por TDD o repositório de persistência em `lib/repositories/report_storage_repository.dart`, com testes em `test/repositories/report_storage_repository_test.dart`. Ele grava o `MeetingReport` como JSON em `shared_preferences` sob uma única chave. Nos testes use `SharedPreferences.setMockInitialValues({})` e `TestWidgetsFlutterBinding.ensureInitialized()`.
>
> Critérios de aceite (comportamentos observáveis):
> - Salvar e depois carregar devolve um relatório igual ao original (round-trip fiel, incluindo tempos, ids, seções, itens adicionados manualmente, `startedAt`/`endedAt` e o item que estava correndo).
> - Carregar sem nada salvo devolve `null`, sem lançar.
> - Salvar duas vezes sobrescreve — não acumula nem duplica.
> - Se o valor gravado estiver corrompido (JSON inválido ou de formato antigo), carregar devolve `null` e limpa a chave, em vez de propagar exceção — uma reunião não pode ser bloqueada por lixo em disco.
> - Existe uma operação de limpar que remove o relatório salvo, e carregar depois dela devolve `null`.
>
> Toque apenas na camada Repositories (pode importar Models); não modifique arquivos de outras camadas.

---

### Task 08 — Repositório de exportação de imagem

**Objetivo:** Salvar o PNG na galeria e abrir o compartilhamento.
**Camadas:** Repositories
**Modo:** direto
**Depende de:** —
**Instrução para o subagente:**
> Spec 0001 — Task 08: Implemente em `lib/repositories/image_export_repository.dart` a exportação da imagem do relatório. A classe recebe os bytes PNG já renderizados (`Uint8List`) e faz duas coisas: grava o arquivo em disco via `path_provider` num nome com a data (ex.: `relatorio-reuniao-2026-07-30.png`), salva na galeria via `gal` (pedindo permissão antes com a API do próprio `gal` e devolvendo um erro claro se for negada) e abre o menu de compartilhamento via `share_plus` apontando para esse arquivo.
>
> Erros de plugin devem virar uma exceção de domínio própria (ex.: `ImageExportException`) com mensagem em português, para a UI conseguir mostrar um `SnackBar` útil. Esta task é estrutural e ligada a plugins de plataforma, portanto não exige testes unitários; garanta apenas que `flutter analyze` passa limpo.
>
> Toque apenas na camada Repositories; não modifique arquivos de outras camadas.

---

### Task 09 — Providers Riverpod

**Objetivo:** Ligar services e repositories à UI, com o estado do relatório num `StateNotifier`.
**Camadas:** Providers
**Modo:** direto
**Depende de:** Tasks 03, 04, 05, 06, 07
**Instrução para o subagente:**
> Spec 0001 — Task 09: Implemente os providers Riverpod em `lib/providers/` (sugestão: `dependencies_provider.dart` para as instâncias de services/repositories e `meeting_provider.dart` para o estado). O `MeetingNotifier` (um `StateNotifier<MeetingReport?>`) é a única porta de entrada da UI.
>
> Ele deve expor: carregar o relatório salvo ao iniciar; baixar a programação (repositório HTTP → parser → `ReportBuilder`) e substituir o estado; e repassar cada operação do `MeetingTimerService` (start, pause, next, selectPrevious, selectNext, endMeeting, reset, rename, setElapsed, addItem, removeItem). **Toda** mutação de estado grava no `ReportStorageRepository` logo em seguida.
>
> Exponha também um provider separado que emite um tick de 1 em 1 segundo (`Stream.periodic`) só para a UI redesenhar o cronômetro — o tick **não** altera o estado do relatório; o tempo mostrado é sempre calculado por `effectiveElapsed(DateTime.now())`. E um provider de estado da busca (ocioso / carregando / erro com mensagem), para a tela reagir à falta de internet.
>
> Toda a lógica fica nos services: o notifier só orquestra e persiste. Não duplique regra de negócio aqui, não faça parsing e não chame `http` direto. Esta task é de fiação, sem testes unitários próprios; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Providers; não modifique arquivos de outras camadas.

---

### Task 10 — Bootstrap do app e tema

**Objetivo:** Substituir o scaffold padrão pelo app real, com `ProviderScope` e tema claro.
**Camadas:** Screens (bootstrap)
**Modo:** direto
**Depende de:** —
**Instrução para o subagente:**
> Spec 0001 — Task 10: Substitua o contador padrão do Flutter em `lib/main.dart` pelo bootstrap real do RDR: `runApp` com `ProviderScope` envolvendo um `MaterialApp` de título "RDR", `debugShowCheckedModeBanner: false`, locale `pt_BR`, e um tema **claro apenas** (sem `darkTheme`, `themeMode: ThemeMode.light`) definido em `lib/utils/app_theme.dart`.
>
> O tema centraliza as três cores de seção usadas em todo o app, iguais às do wol.jw.org: Tesouros teal (`#26697C`), Faça Seu Melhor dourado (`#9B6E1A`), Nossa Vida Cristã vinho (`#A33B2A`). Exponha-as como constantes nomeadas, mais uma função que mapeia `SectionKind` para a cor, para que os widgets não repitam literais de cor.
>
> A `home` deve ser um placeholder mínimo (um `Scaffold` vazio com o título) — a tela real chega na Task 12. Remova também o teste padrão `test/widget_test.dart`, que testa o contador e vai quebrar. Esta task é estrutural, sem testes próprios; garanta que `flutter analyze` passa limpo.
>
> Toque apenas em `lib/main.dart`, `lib/utils/app_theme.dart` e na remoção de `test/widget_test.dart`; não modifique arquivos de outras camadas.

---

### Task 11 — Widgets de linha de item e cabeçalho de seção

**Objetivo:** Componentes visuais reutilizáveis pela tela e pelo print.
**Camadas:** Widgets
**Modo:** direto
**Depende de:** Tasks 01, 02, 10
**Instrução para o subagente:**
> Spec 0001 — Task 11: Implemente em `lib/widgets/` os dois componentes de apresentação do relatório: o cabeçalho de seção e a linha de item. Ambos são puros de apresentação — recebem tudo por parâmetro, não leem provider, não têm estado.
>
> O cabeçalho de seção mostra o ícone e o título na cor da seção, no estilo dos prints de referência: quadrado colorido com ícone à esquerda (losango para Tesouros, espiga para Faça Seu Melhor, ovelha para Nossa Vida Cristã — use ícones do Material que se aproximem) e o título em caixa alta e negrito na cor da seção, vindo de `app_theme.dart`.
>
> A linha de item mostra o label à esquerda e o tempo formatado à direita, com `formatDuration` da Task 01. Sub-item (`isSubItem == true`) é indentado e prefixado por `• `, com o label seguido de dois-pontos, igual aos prints. A linha aceita flags de `selecionado` e `correndo` para destaque visual, e callbacks opcionais de toque — quando os callbacks são nulos ela fica puramente estática, que é como o widget de print vai usá-la.
>
> Fundo branco, tema claro. Esta task é de UI, sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Widgets; não modifique arquivos de outras camadas.

---

### Task 12 — Tela principal com a lista da reunião

**Objetivo:** Tela que lista o relatório vivo e trata os estados de carga.
**Camadas:** Screens
**Modo:** direto
**Depende de:** Tasks 09, 11
**Instrução para o subagente:**
> Spec 0001 — Task 12: Implemente `lib/screens/meeting_screen.dart` e aponte a `home` do `MaterialApp` em `lib/main.dart` para ela. A tela consome os providers da Task 09 e usa os widgets da Task 11.
>
> Estados a cobrir: sem relatório carregado, mostra um estado vazio com botão "Baixar programação"; durante a busca, indicador de progresso; em erro, a mensagem do provider mais um botão de tentar de novo e a opção de montar a lista na mão (relatório vazio só com os itens fixos). Com relatório carregado, mostra `Início da reunião: HH:MM` no topo (ou vazio antes de começar), a lista rolável na ordem canônica com os cabeçalhos das três seções, e `Fim da reunião: HH:MM` ao final quando já encerrado.
>
> A lista redesenha a cada tick de 1 segundo do provider de tick, calculando o tempo por `effectiveElapsed(DateTime.now())`. Item selecionado e item que corre recebem destaques visuais **distintos** — são conceitos diferentes e o usuário precisa enxergar os dois ao mesmo tempo. A lista rola sozinha para manter o item selecionado visível quando a seleção muda. Tocar num item o seleciona.
>
> Deixe espaço reservado no rodapé para o painel de controle, que chega na Task 13. Sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Screens e no `home` de `lib/main.dart`; não modifique arquivos de outras camadas.

---

### Task 13 — Painel de controle do tempo

**Objetivo:** Os botões que dirigem o cronômetro durante a reunião.
**Camadas:** Widgets
**Modo:** direto
**Depende de:** Tasks 09, 12
**Instrução para o subagente:**
> Spec 0001 — Task 13: Implemente `lib/widgets/control_panel.dart` e encaixe-o no rodapé fixo de `lib/screens/meeting_screen.dart`. Ele chama as operações do notifier da Task 09.
>
> Botões: **Iniciar/Pausar** (alterna conforme houver item correndo), **Próximo**, **seta para cima**, **seta para baixo**, **Resetar** e **Encerrar reunião**. Iniciar/Pausar e Próximo são os alvos grandes e centrais; as setas ficam laterais. Resetar e Encerrar são destrutivos e ficam **visualmente afastados** do Próximo, para não serem tocados por engano no escuro — leia a seção "Restrições e Cuidados" do `CLAUDE.md`.
>
> Resetar e Encerrar abrem diálogo de confirmação antes de agir; os demais agem direto. Após encerrar, Iniciar, Próximo e Pausar ficam desabilitados. Alvos de toque com no mínimo 48dp.
>
> Sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Widgets e no encaixe do painel em `meeting_screen.dart`; não modifique arquivos de outras camadas.

---

### Task 14 — Diálogos de edição, inclusão e remoção de itens

**Objetivo:** Edição manual completa da lista durante a reunião.
**Camadas:** Widgets
**Modo:** direto
**Depende de:** Tasks 09, 12
**Instrução para o subagente:**
> Spec 0001 — Task 14: Implemente em `lib/widgets/` os diálogos de manutenção da lista e ligue-os à `meeting_screen.dart`. Toque longo num item abre um menu com Editar, Adicionar abaixo e Remover.
>
> Editar abre um diálogo com o nome do item e o tempo em dois campos numéricos (minutos e segundos), pré-preenchidos com o valor atual e convertidos por `parseDurationInput` da Task 01; salvar chama `rename` e `setElapsed` no notifier. A edição é permitida **a qualquer momento, inclusive com o item correndo** — nesse caso a contagem segue a partir do novo valor.
>
> Adicionar abaixo abre um diálogo com o nome e a escolha entre parte e sub-item, e insere logo abaixo do item de origem. Remover pede confirmação, avisando que o tempo daquele item será perdido.
>
> Sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Widgets e na ligação em `meeting_screen.dart`; não modifique arquivos de outras camadas.

---

### Task 15 — Relatório para impressão e exportação em PNG

**Objetivo:** Gerar e compartilhar o print longo do relatório completo.
**Camadas:** Widgets, Screens
**Modo:** direto
**Depende de:** Tasks 02, 08, 09, 11
**Instrução para o subagente:**
> Spec 0001 — Task 15: Implemente `lib/widgets/report_sheet.dart`, o widget que desenha o relatório inteiro para virar imagem, e o botão que dispara a exportação a partir da `meeting_screen.dart`.
>
> O `ReportSheet` recebe um `MeetingReport` e desenha, em fundo branco e coluna única: o título "Relatório da reunião", a data da semana (`weekLabel`), `Início da reunião: HH:MM`, a linha de Comentários iniciais, as três seções com cabeçalho colorido e seus itens, a linha de Comentários finais e `Fim da reunião: HH:MM`. Reaproveite os widgets da Task 11 em modo estático. Use o layout dos prints de referência descrito em "Estrutura do relatório" no `CLAUDE.md`.
>
> A exportação usa `ScreenshotController.captureFromLongWidget` do pacote `screenshot`, com `pixelRatio` alto o bastante para o texto sair legível, para renderizar o `ReportSheet` **fora da tela em uma imagem única sem corte** — a altura da tela não pode limitar o resultado. Os bytes vão para o `ImageExportRepository` da Task 08, que salva na galeria e abre o compartilhamento. Mostre progresso durante a geração e um `SnackBar` de sucesso ou de erro ao final.
>
> Sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas nas camadas Widgets e Screens; não modifique arquivos de outras camadas.

---

### Task 16 — Teste de integração do fluxo completo

**Objetivo:** Garantir que as camadas conversam ponta a ponta, do HTML ao relatório final.
**Camadas:** Services, Repositories, Models (integração)
**Modo:** TDD
**Depende de:** Tasks 03, 04, 05, 07
**Instrução para o subagente:**
> Spec 0001 — Task 16: Implemente por TDD o teste de integração em `test/integration/meeting_flow_test.dart`, cobrindo o caminho que nenhuma task unitária cobre: HTML real → parser → `ReportBuilder` → `MeetingTimerService` → persistência → restauração. Use as fixtures `test/fixtures/meetings_week_2026_31.html` e `test/fixtures/mwb_2026_31.html`, um `MockClient` no lugar da rede e um `Clock` falso que você faz avançar manualmente. Nada de rede e nada de `DateTime.now()` real.
>
> Critérios de aceite (comportamentos observáveis):
> - Partindo das fixtures, o relatório montado tem, na ordem canônica: Comentários iniciais, as 3 partes de Tesouros com seus sub-itens, as 3 de Faça Seu Melhor com Conselho e Transição, o "Presidente" avulso e as 2 partes de Nossa Vida Cristã, e Comentários finais — batendo com a regra de sub-itens do `CLAUDE.md`.
> - Simulando a reunião inteira com o relógio falso (`start`, e um `next` por item até o fim), cada item termina com exatamente a duração que o relógio avançou enquanto ele corria, e a soma dos itens bate com o tempo total decorrido.
> - Usar as setas no meio da reunião muda a seleção sem alterar o tempo do item que está correndo.
> - Após `endMeeting`, `startedAt` e `endedAt` refletem os instantes do relógio falso e nenhum item continua com `runningSince` preenchido.
> - Salvar o relatório no meio da reunião e recarregá-lo devolve um relatório equivalente, e o cronômetro continua correndo corretamente a partir dele.
>
> Toque apenas em arquivos de teste; não modifique código de produção — se um teste revelar um defeito, relate-o em vez de corrigir fora do escopo.

---

## Como executar

Recomendado — orquestração automática:

```
/centaur-driven-run 0001
```

O run lança um subagente por task, paraleliza as independentes e respeita as dependências.

Alternativa manual — para cada task, abra um subagente e invoque a skill correspondente ao `Modo` da task:

```
/centaur-driven-tdd [instrução da task, se Modo: TDD]
/centaur-driven-implement [instrução da task, se Modo: direto]
```

Execute as tasks na ordem indicada, respeitando as dependências.

## Ciclo de vida

- `Pendente` → nenhuma task iniciada
- `Em andamento` → definido pela skill de execução da task (`/centaur-driven-tdd` ou `/centaur-driven-implement`) ao iniciar a primeira task, ou pelo `/centaur-driven-run` ao montar o plano
- `Concluída` → definido pela skill de execução quando a última task do checklist for marcada
- Tasks bloqueadas ficam anotadas no checklist com o motivo

## Checklist de conclusão

_Atualizado automaticamente pela skill de execução de cada task (`/centaur-driven-tdd` ou `/centaur-driven-implement`)._

- [x] Task 01 — Utilitários de formatação de tempo → implements/0003
- [x] Task 02 — Models do domínio com serialização JSON → implements/0005
- [x] Task 03 — Parser do HTML do wol.jw.org → implements/0008
- [x] Task 04 — Montagem do relatório com itens fixos e sub-itens automáticos → implements/0007
- [x] Task 05 — Máquina de estados do cronômetro e edição de itens → implements/0009
- [x] Task 06 — Repositório HTTP do wol.jw.org → implements/0004
- [x] Task 07 — Repositório de persistência do relatório → implements/0006
- [x] Task 08 — Repositório de exportação de imagem → implements/0001
- [x] Task 09 — Providers Riverpod → implements/0011
- [x] Task 10 — Bootstrap do app e tema → implements/0002
- [x] Task 11 — Widgets de linha de item e cabeçalho de seção → implements/0010
- [x] Task 12 — Tela principal com a lista da reunião → implements/0013
- [x] Task 13 — Painel de controle do tempo → implements/0014
- [x] Task 14 — Diálogos de edição, inclusão e remoção de itens → implements/0015
- [x] Task 15 — Relatório para impressão e exportação em PNG → implements/0016
- [x] Task 16 — Teste de integração do fluxo completo → implements/0012
