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
| primeiro `<p>` após o `h3`, casando `\((\d+)\s*min\)` | **duração prevista** da parte |

`h2` sem classe de cor é o texto bíblico da semana (ex.: `JEREMIAS 20-21`) — ignorar.
`h3` de cântico/oração (`Cântico 73 e oração`, `Cântico 57`) e `Comentários iniciais` / `Comentários finais` **não são partes cronometradas da lista** — ver regra do relatório abaixo.

O parser deve degradar com elegância: se o layout mudar, retornar erro claro e permitir montar o relatório manualmente (adicionar partes na mão).

### Estrutura do relatório

Ordem fixa do relatório impresso:

```
Relatório da reunião
Início da reunião: HH:MM        <- relógio do sistema quando o cronômetro inicia
Comentários iniciais: MM:SS

TESOUROS DA PALAVRA DE DEUS
  1. <parte>            MM:SS
     • Presidente:      MM:SS
  ...
FAÇA SEU MELHOR NO MINISTÉRIO
  4. <parte>            MM:SS
     • Conselho:        MM:SS
     • Transição:       MM:SS
  ...
NOSSA VIDA CRISTÃ
  Presidente            MM:SS
  7. <parte>            MM:SS
     • Presidente:      MM:SS
  8. Estudo bíblico de congregação   MM:SS

Comentários finais: MM:SS
Fim da reunião: HH:MM           <- relógio do sistema ao encerrar
```

### Regra dos sub-itens (automática por seção)

Cada parte cronometrada recebe sub-itens automaticamente conforme a seção:

| Seção | Sub-itens gerados |
|-------|-------------------|
| Tesouros da Palavra de Deus | `Presidente` |
| Tesouros — **Leitura da Bíblia** | `Conselho` + `Transição` |
| Faça Seu Melhor no Ministério | `Conselho` + `Transição` |
| Nossa Vida Cristã | `Presidente` |

Sub-itens são cronometrados no mesmo fluxo do botão **Próximo**: ao avançar de uma parte, o cronômetro passa para o sub-item seguinte dela e só depois para a próxima parte. Todos os sub-itens são editáveis e removíveis como qualquer item.

### Controle de tempo

Painel com:

- **Iniciar** — arranca o cronômetro; na primeira vez grava `Início da reunião` do relógio do sistema.
- **Pausar** — congela o item atual.
- **Resetar** — zera tudo. **Exige diálogo de confirmação** (ação destrutiva, apaga a reunião em andamento).
- **Próximo** — pausa o item atual e inicia o próximo da lista.
- **Seta acima / seta abaixo** — muda o item selecionado **sem pausar** o item de origem (ele continua correndo).

Duas coisas distintas, não confundir: **item que está correndo** e **item selecionado na tela**. As setas mexem só na seleção; o Próximo mexe nos dois.

O cronômetro deve se basear em **timestamps absolutos** (`DateTime` de início do trecho + soma dos trechos anteriores), nunca em um contador incrementado por `Timer`. Caso contrário o tempo desanda quando a tela apaga ou o app vai para segundo plano.

### Persistência

O estado inteiro do relatório é serializado em JSON e gravado em `shared_preferences` a cada mudança relevante. Ao abrir, o app restaura a reunião em andamento. Uma reunião de 1h45 não pode ser perdida por um reload.

### Print longo

`screenshot` → `captureFromLongWidget` renderiza o relatório completo fora da tela em uma **imagem única sem corte**, independente da altura da tela. Salvar na galeria via `gal` e abrir o menu de compartilhamento via `share_plus`.

## Arquitetura de Camadas

| Camada | Pasta | Responsabilidade | Proibido |
|--------|-------|------------------|----------|
| Models | `lib/models/` | Entidades de domínio imutáveis (`MeetingReport`, `MeetingSection`, `MeetingPart`, `TimedItem`), `copyWith`, `toJson`/`fromJson` | Regras de negócio, HTTP, I/O, widgets |
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
| Local e nome | `test/**/*_test.dart`, espelhando a estrutura de `lib/` |
| Meta de cobertura | 100% em `lib/services/` e `lib/models/`. UI sem meta. |

**Escopo do TDD:** regras testáveis — parser do HTML, geração de sub-itens, cálculo e formatação de tempos, máquina de estados do cronômetro, serialização do relatório. **UI não é testada** por padrão.

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
- Cores das seções seguem as do wol.jw.org: Tesouros = teal, Faça Seu Melhor = dourado, Nossa Vida Cristã = vinho/maroon.

## Restrições e Cuidados

- **Sem backend.** Nada de servidor, banco remoto, conta de usuário ou envio de dados para fora. Tudo mora no celular.
- **Uso ao vivo, uma chance só.** A reunião não se repete: perder o estado é perder o trabalho da noite. Persistir sempre; `Resetar` sempre confirmando.
- **Cronômetro à prova de tela apagada** — timestamps absolutos, nunca acumulador de `Timer`.
- **Tocar o mínimo no site.** Uma requisição por semana, cacheada localmente. Nada de polling.
- O HTML do wol.jw.org pode mudar sem aviso: o parser precisa falhar com mensagem clara e deixar o usuário montar as partes na mão.
- Tela do celular é pequena: os botões do painel de controle são tocados no escuro e às pressas. Alvos grandes, `Resetar` longe do `Próximo`.
- O app não precisa de permissão de internet além da padrão do Android; salvar na galeria exige permissão em Android < 13 (`gal` cuida disso, mas testar no aparelho real).

## Contexto Extra

- Versão anterior deste app foi feita com Capacitor + Go compilado para WebAssembly. Este é um reinício em Flutter — não há código a migrar.
- Vocabulário do domínio: a reunião tem três seções fixas; "parte" é um item numerado da programação; "Presidente", "Conselho" e "Transição" são falas curtas entre partes, cronometradas à parte; "Comentários iniciais/finais" abrem e fecham a reunião.
- Cânticos e orações **não entram** na lista cronometrada do relatório.
- A programação da semana muda toda segunda-feira no wol.jw.org.

## Implementações

Atualizado automaticamente pelas skills `/centaur-driven-tdd` e `/centaur-driven-implement`.
Veja `.claude/implements/status.md` para o histórico completo e `.claude/specs/index.md` para as specs planejadas.
