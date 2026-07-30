# RDR — Relatório de Reunião

## Visão Geral

App Android (Flutter) que cronometra a reunião **Vida e Ministério Cristão** das Testemunhas de Jeová e gera um relatório de tempos por parte.

O app baixa a programação da semana corrente do site `wol.jw.org`, monta a lista de partes, cronometra cada uma durante a reunião e no fim exporta um print longo (PNG único) do relatório para compartilhar.

**Usuário:** irmão designado para cronometrar a reunião. Uso presencial, com o celular na mão, durante ~1h45.

**Tudo é local no dispositivo.** Sem backend, sem login, sem banco remoto, sem telemetria.

## Stack Técnica

| Item | Valor |
|------|-------|
| Linguagem | Dart 3.12.2 |
| Framework | Flutter 3.44.8 (canal stable) |
| Plataforma | Android apenas (`--platforms android`) |
| Estado | `flutter_riverpod` ^2.6.1 |
| HTTP | `http` ^1.6.0 |
| Parser HTML | `html` ^0.15.6 |
| Persistência | `shared_preferences` ^2.5.5 (JSON serializado) |
| Print longo | `screenshot` ^3.0.0 (`captureFromLongWidget`) |
| Salvar/compartilhar | `gal` ^2.3.3 + `share_plus` ^13.3.0 + `path_provider` ^2.1.6 |
| Formatação | `intl` ^0.20.3 |
| Testes | `flutter_test` + `mocktail` ^1.0.5 |
| Lint | `flutter_lints` ^6.0.0 |
| Package / org | `rdr` / `com.dalistor` |

## Estrutura do Projeto

```
lib/
  main.dart          # bootstrap: ProviderScope + MaterialApp
  models/            # entidades de domínio imutáveis
  services/          # regras de negócio puras (parser, cronômetro, relatório)
  repositories/      # acesso a dados externos (HTTP, storage, galeria)
  providers/         # Riverpod: cola entre services/repositories e UI
  screens/           # telas
  widgets/           # componentes de UI reutilizáveis
  utils/             # formatação e helpers puros
test/
  models/ services/ repositories/   # espelham lib/
  integration/       # fluxo ponta a ponta atravessando as camadas
  fixtures/          # HTML real do wol.jw.org
android/             # projeto Android nativo
.claude/
  implements/        # histórico de implementações
  specs/             # planejamentos decompostos em tasks
```

## Como Rodar

```bash
flutter pub get
flutter devices                 # confirmar celular/emulador conectado
flutter run                     # debug no dispositivo
flutter build apk --release     # APK de release em build/app/outputs/flutter-apk/
flutter analyze                 # lint
```

Celular Android precisa de **Depuração USB** ligada nas Opções do desenvolvedor.

## Como Fazer Deploy

Não há loja nem CI. Distribuição manual: `flutter build apk --release` e instalar o APK direto no celular.

## Arquitetura e Decisões Técnicas

### Scraping do wol.jw.org

A programação vem em **HTML estático** — não precisa de browser headless nem WebView. Fluxo em dois passos:

1. `GET https://wol.jw.org/pt/wol/meetings/r5/lp-t/` — redireciona (302) para a semana corrente, ex.: `.../meetings/r5/lp-t/2026/31`.
2. Nessa página, achar o link `/pt/wol/d/r5/lp-t/<docId>` cujo texto contém **"Apostila Vida e Ministério"** (o outro link é A Sentinela — ignorar).
3. `GET` esse documento e parsear.

**Enviar um `User-Agent` de navegador móvel** na requisição.

### Estrutura do documento da apostila

Percorrer os nós na ordem do documento:

| Elemento | Significado |
|----------|-------------|
| `h2.du-color--teal-700` | seção **Tesouros da Palavra de Deus** |
| `h2.du-color--gold-700` | seção **Faça Seu Melhor no Ministério** |
| `h2.du-color--maroon-600` | seção **Nossa Vida Cristã** |
| `h3` dentro/depois de uma seção | uma **parte** (o texto já vem numerado: `1. Ele pregou com coragem`) |

`h2` sem classe de cor é o texto bíblico da semana (ex.: `JEREMIAS 20-21`) — ignorar.
`h3` de cântico/oração (`Cântico 73 e oração`, `Cântico 57`) e `Comentários iniciais` / `Comentários finais` **não são partes cronometradas da lista** — ver regra do relatório abaixo.

A duração prevista (`(10 min)`) existe no HTML mas o app **ignora** — não é parseada, não é exibida, não gera alerta.

O parser vive em `lib/services/schedule_parser.dart` (`ScheduleParser.parseWeekPage` e `ScheduleParser.parseDocument`) e devolve `ParsedSection` — a programação em texto puro, que o `ReportBuilder` transforma no `MeetingReport`.

O parser deve degradar com elegância: se o layout mudar, retornar erro claro (`ScheduleParseException`, mensagem em português) e permitir montar o relatório manualmente (adicionar partes na mão). Se o wol parar de colorir os `h3`, um título que comece com numeração (`4. `) ainda é aceito como parte da seção aberta.

### Estrutura do relatório

Ordem fixa do relatório impresso:

```
Relatório da reunião
27 de julho–2 de agosto         <- semana, vinda do wol.jw.org
Início da reunião: HH:MM        <- relógio do sistema quando o cronômetro inicia
Comentários iniciais: MM:SS

TESOUROS DA PALAVRA DE DEUS
  1. <parte>            MM:SS
     • Presidente:      MM:SS
  2. <parte>            MM:SS
     • Presidente:      MM:SS
  3. Leitura da Bíblia  MM:SS
     • Conselho:        MM:SS
     • Transição:       MM:SS
FAÇA SEU MELHOR NO MINISTÉRIO
  4. <parte>            MM:SS
     • Conselho:        MM:SS
     • Transição:       MM:SS
  ...
NOSSA VIDA CRISTÃ
  Presidente            MM:SS      <- item avulso que abre a seção
  7. <parte>            MM:SS
     • Presidente:      MM:SS
  8. Estudo bíblico de congregação   MM:SS   <- última parte, sem sub-item

Comentários finais: MM:SS
Fim da reunião: HH:MM           <- relógio do sistema ao encerrar
```

### Regra dos sub-itens (automática por seção)

Ao montar o relatório, cada parte recebe sub-itens automaticamente:

| Seção | Regra |
|-------|-------|
| Tesouros da Palavra de Deus | cada parte ganha `Presidente` |
| Tesouros — **Leitura da Bíblia** | exceção: ganha `Conselho` + `Transição` |
| Faça Seu Melhor no Ministério | cada parte ganha `Conselho` + `Transição` |
| Nossa Vida Cristã | a seção abre com um item avulso `Presidente` (sem número); cada parte ganha `Presidente` |
| Nossa Vida Cristã — **última parte** | exceção: nenhum sub-item (é seguida direto pelos Comentários finais) |

Além disso, `Comentários iniciais` abre o relatório e `Comentários finais` fecha, ambos fora das seções.

Sub-itens são cronometrados no mesmo fluxo do botão **Próximo**: ao avançar de uma parte, o cronômetro passa para o sub-item seguinte dela e só depois para a próxima parte. Todos os itens — fixos, partes e sub-itens — são renomeáveis, editáveis no tempo e removíveis.

### Controle de tempo

Painel com:

- **Botão cíclico do cronômetro** — o botão apertado dezenas de vezes por noite, e quase o único usado durante a reunião:
  - parado, diz **Iniciar** e arranca o item selecionado (`start`);
  - correndo, diz **Próximo**, para o tempo do item atual e desce a seleção **sem arrancar o próximo** (`advance`).

  Depois de um `advance` nada está correndo: é o toque seguinte que arranca. Não existe pausar sem avançar.
- **Botão cíclico da reunião** — **Iniciar reunião** grava `Início da reunião` (`startMeeting`); **Encerrar reunião** grava `Fim da reunião`, para o cronômetro, **congela o relatório** e libera o print (`endMeeting`). **Ambos exigem confirmação.**
- **Zerar parte** — zera o tempo só da parte selecionada (`resetItem`). Não existe reset parcial da reunião: ou se zera uma parte, ou se apaga tudo pelo `Reiniciar tudo` do menu do topo.
- **Seta acima / seta abaixo** — muda o item selecionado **sem pausar** o item de origem (ele continua correndo).

Duas coisas distintas, não confundir: **item que está correndo** e **item selecionado na tela**. As setas mexem só na seleção; o botão cíclico mexe nos dois.

O cronômetro das partes e os horários da reunião são independentes: `start` cuida só do item, e quem grava o `Início da reunião` é o `startMeeting`, mais ninguém. Se o usuário esquecer de abrir a reunião, o horário fica em branco — e é por isso que ele é editável.

Edição de nome e de tempo é permitida **enquanto a reunião não é encerrada**, inclusive com ela correndo. Editar o tempo do item que está correndo reajusta a contagem para seguir a partir do novo valor.

As linhas `Início da reunião` e `Fim da reunião` ficam **sempre visíveis** nas duas pontas da lista, com um travessão `—` enquanto o horário não existe, e são **tocáveis** até o encerramento: abrem um diálogo de hora e minuto que grava (`setStartedAt` / `setEndedAt`) ou limpa o valor. É o conserto para quem esquecer de abrir ou encerrar a reunião no botão.

### Relatório congelado e "Reiniciar tudo"

**Encerrada a reunião, o relatório vira só leitura.** Some tudo: menu de toque longo (editar, adicionar, remover), seleção por toque, edição das linhas de horário, setas do painel e `Zerar parte` — o painel inteiro fica desabilitado. Restam só duas ações: **exportar o print** e, no menu de três pontos da barra superior, **Reiniciar tudo**.

`Reiniciar tudo` (`MeetingNotifier.resetAll`) descarta o relatório da memória e do `shared_preferences` e devolve a tela ao estado "Nenhuma programação carregada" — é como se começa a semana seguinte. Fica no menu do topo, longe do polegar que aperta `Próximo`, está disponível durante toda a reunião e **sempre pede confirmação** (`showResetAllDialog`); não há como desfazer.

A trava mora na UI: os services seguem puros e sem noção de "congelado" — a tela apenas deixa de oferecer as operações.

O service ainda expõe um `next`, que emenda direto no próximo item sem passar pelo estado parado. Não é o que o painel usa — o painel usa `advance`.

O cronômetro deve se basear em **timestamps absolutos** (`DateTime` de início do trecho + soma dos trechos anteriores), nunca em um contador incrementado por `Timer`. Caso contrário o tempo desanda quando a tela apaga ou o app vai para segundo plano.

### Persistência

O estado inteiro do relatório é serializado em JSON e gravado em `shared_preferences` a cada mudança relevante. Ao abrir, o app restaura a reunião em andamento. Uma reunião de 1h45 não pode ser perdida por um reload.

A **programação** em si não é cacheada: baixar exige internet toda vez. O que persiste é o relatório já montado — uma vez baixado, a reunião corre sem rede.

### Print longo

`screenshot` → `captureFromLongWidget` renderiza o relatório completo fora da tela em uma **imagem única sem corte**, independente da altura da tela. Salvar na galeria via `gal` e abrir o menu de compartilhamento via `share_plus`.

O PNG traz título `Relatório da reunião`, a **data da semana** no cabeçalho, e o corpo do relatório com as cores das três seções. Fundo branco.

Os cabeçalhos de seção não têm ícone: são só o título em caixa alta, na cor da seção (`SectionHeader`). Vale para a tela e para o print, que compartilham o mesmo widget.

A folha impressa é o `ReportSheet` (`lib/widgets/report_sheet.dart`), disparado pelo botão de compartilhar da barra superior da `meeting_screen.dart`. Como é renderizada fora do `MaterialApp`, ela **não pode usar `Theme.of`, `MediaQuery.of` nem `Scaffold`** — cores e estilos são sempre explícitos — e define a **própria largura** (`ReportSheet.captureWidth`), deixando a altura livre para crescer. `ReportSheet.capturePixelRatio` controla a nitidez do texto.

## Arquitetura de Camadas

| Camada | Pasta | Responsabilidade | Proibido |
|--------|-------|------------------|----------|
| Models | `lib/models/` | Entidades de domínio imutáveis (`MeetingReport`, `MeetingSection`, `TimedItem`, `SectionKind`), `copyWith` com flags `clearX` para os campos anuláveis, `toJson`/`fromJson` — JSON inválido vira `ReportDecodeException`, nunca `TypeError` | Regras de negócio, HTTP, I/O, widgets |
| Services | `lib/services/` | Regras de negócio puras: parser do HTML, geração dos sub-itens, máquina de estados do cronômetro, montagem do relatório | HTTP direto, `shared_preferences`, qualquer import de `material.dart` |
| Repositories | `lib/repositories/` | Acesso a dados externos: `http` para o wol.jw.org, `shared_preferences`, galeria, arquivos | Regras de negócio, decisões de UI |
| Providers | `lib/providers/` | Riverpod: instanciar services/repositories, expor estado à UI, orquestrar | Lógica de negócio (delegar ao service), parsing, queries |
| Screens | `lib/screens/` | Telas completas, layout, navegação | Regras de negócio, HTTP, parsing |
| Widgets | `lib/widgets/` | Componentes de UI reutilizáveis | Regras de negócio, acesso a dados |
| Utils | `lib/utils/` | Helpers puros de formatação (`Duration` → `MM:SS`, `DateTime` → `HH:MM`) | Estado, I/O |

**Regra de dependência:** `screens/widgets → providers → services → repositories → models`. Nunca no sentido inverso. `models` não importa nada das outras camadas. `services` recebe dados prontos por parâmetro ou repositório injetado — nunca busca sozinho.

Um `service` só pode ser testado sem Flutter engine: nada de `material.dart` nem plugins dentro dele.

## Testes

| Item | Valor |
|------|-------|
| Framework | `flutter_test` (+ `mocktail` para dublês) |
| Rodar tudo | `flutter test` |
| Rodar um arquivo | `flutter test test/services/schedule_parser_test.dart` |
| Rodar um teste | `flutter test --plain-name "nome do teste"` |
| Cobertura | `flutter test --coverage` (gera `coverage/lcov.info`) |
| Local e nome | `test/**/*_test.dart`, espelhando a estrutura de `lib/`; testes de integração em `test/integration/`; fixtures de HTML em `test/fixtures/` |
| Meta de cobertura | 100% em `lib/services/` e `lib/models/`. UI sem meta. |

**Escopo do TDD:** regras testáveis — parser do HTML, geração de sub-itens, cálculo e formatação de tempos, máquina de estados do cronômetro, serialização do relatório. **UI não é testada** por padrão.

**Exceção:** `test/widgets/control_panel_test.dart` cobre a tabela de estados do painel — qual rótulo, qual operação e qual botão fica desabilitado para cada combinação de `isRunning`, `hasStarted` e `hasEnded`, mais o layout em tela estreita. Isso é comportamento, não estilo: trocar um `advance()` por `next()` numa refatoração passaria despercebido sem ele. Testes de widget que verifiquem só aparência continuam fora do escopo.

**Teste de integração:** `test/integration/meeting_flow_test.dart` cobre o encaixe das camadas que nenhum teste unitário alcança — fixture de HTML real → parser → `ReportBuilder` → `MeetingTimerService` → persistência → restauração —, simulando uma reunião inteira com `MockClient` e relógio falso. Mudança em qualquer uma dessas camadas deve manter esse teste verde.

**Mocks:**
- HTTP → injetar `http.Client` no repositório e usar `MockClient` do `http/testing.dart`, ou `mocktail`.
- HTML real → guardar fixtures em `test/fixtures/*.html`. Nunca bater na rede dentro de teste.
- Relógio → **nunca chamar `DateTime.now()` direto em service**. Injetar um `Clock` (`DateTime Function()`) para poder controlar o tempo no teste.
- `shared_preferences` → `SharedPreferences.setMockInitialValues({})`.

## Regras e Convenções

- Arquivos e pastas em `snake_case`; classes em `PascalCase`; membros privados com `_`.
- Sufixo por camada no nome do arquivo: `*_service.dart`, `*_repository.dart`, `*_provider.dart`, `*_screen.dart`.
- Models imutáveis: campos `final`, construtor `const` quando possível, `copyWith` para mudanças.
- Nada de `print` — usar `debugPrint` e só em desenvolvimento.
- `flutter analyze` tem que passar limpo antes de considerar uma tarefa pronta.
- Textos da interface em **português**, no vocabulário usado pelas publicações (Tesouros da Palavra de Deus, Faça Seu Melhor no Ministério, Nossa Vida Cristã, Presidente, Conselho, Transição).
- Cores das seções seguem as do wol.jw.org: Tesouros = teal (`#26697C`), Faça Seu Melhor = dourado (`#9B6E1A`), Nossa Vida Cristã = vinho/maroon (`#A33B2A`). Ficam centralizadas em `lib/utils/app_theme.dart` (`AppTheme.sectionColor(kind)`) — nenhum widget repete o literal.
- **Tema claro apenas** — interface e print com fundo branco. Sem tema escuro.

## Restrições e Cuidados

- **Sem backend.** Nada de servidor, banco remoto, conta de usuário ou envio de dados para fora. Tudo mora no celular.
- **Uso ao vivo, uma chance só.** A reunião não se repete: perder o estado é perder o trabalho da noite. Persistir sempre; `Resetar` sempre confirmando.
- **Cronômetro à prova de tela apagada** — timestamps absolutos, nunca acumulador de `Timer`.
- **Tocar o mínimo no site.** Baixar a programação só quando o usuário pedir. Nada de polling. Baixar exige internet — não há cache de programação, mas o relatório já montado funciona offline.
- O HTML do wol.jw.org pode mudar sem aviso: o parser precisa falhar com mensagem clara e deixar o usuário montar as partes na mão.
- Tela do celular é pequena: os botões do painel de controle são tocados no escuro e às pressas. Alvos grandes, `Resetar` longe do `Próximo`.
- **`android.permission.INTERNET` fica no `android/app/src/main/AndroidManifest.xml`** e não pode sair de lá: os manifestos de `debug` e `profile` já a declaram por conta da ferramenta do Flutter, então a falta dela só aparece no **APK de release** — o download falha como se fosse falta de internet, e nenhum teste pega isso. Salvar na galeria exige permissão em Android < 13 (`gal` cuida disso, mas testar no aparelho real).

## Contexto Extra

- Versão anterior deste app foi feita com Capacitor + Go compilado para WebAssembly. Este é um reinício em Flutter — não há código a migrar.
- Vocabulário do domínio: a reunião tem três seções fixas; "parte" é um item numerado da programação; "Presidente", "Conselho" e "Transição" são falas curtas entre partes, cronometradas à parte; "Comentários iniciais/finais" abrem e fecham a reunião.
- Cânticos e orações **não entram** na lista cronometrada do relatório.
- A programação da semana muda toda segunda-feira no wol.jw.org.

## Implementações

Atualizado automaticamente pelas skills `/centaur-driven-tdd` e `/centaur-driven-implement`.
Veja `.claude/implements/status.md` para o histórico completo e `.claude/specs/index.md` para as specs planejadas.
