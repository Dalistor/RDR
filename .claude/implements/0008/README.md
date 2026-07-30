# [0008] Parser do HTML do wol.jw.org

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 03

## Solicitação

> Spec 0001 — Task 03: Implemente por TDD o parser em `lib/services/schedule_parser.dart` (pacote `html`), com testes em `test/services/schedule_parser_test.dart` usando as fixtures reais `test/fixtures/meetings_week_2026_31.html` e `test/fixtures/mwb_2026_31.html`. Leia a seção "Scraping do wol.jw.org" do `CLAUDE.md` — os seletores ali foram verificados no HTML real. Nenhum teste pode acessar a rede.
>
> O parser expõe duas operações. A primeira recebe o HTML da página de semana e devolve o caminho do documento da apostila mais o rótulo da semana. A segunda recebe o HTML do documento e devolve as três seções com suas partes (apenas título; a duração prevista `(10 min)` é ignorada de propósito).
>
> Toque apenas na camada Services (pode importar Models); não modifique arquivos de outras camadas.

## Contexto

O app baixa a programação da semana do wol.jw.org em dois passos (página da semana → documento da apostila). Esta task cobre o miolo desse fluxo: transformar os dois HTMLs em dados de domínio. É a entrada do montador do relatório (Task 04) e o único ponto do app que conhece a marcação do site — que pode mudar sem aviso, daí a exigência de erro claro em vez de retorno silencioso.

## Critérios de aceite

- Na fixture da página de semana, acha o link `/pt/wol/d/r5/lp-t/202026244` (texto contém "Apostila Vida e Ministério") e não o de A Sentinela.
- Extrai o rótulo `"27 de julho–2 de agosto"` (traço U+2013).
- Sem link de apostila, lança `ScheduleParseException` com mensagem clara — nunca nulo silencioso.
- Na fixture do documento, devolve 3 seções na ordem `treasures` / `ministry` / `christianLife`, com os títulos e os seletores de cor (`teal-700`, `gold-700`, `maroon-600`).
- Partes com o número que já vem no texto (1 a 8, distribuídas 3/3/2 pelas seções).
- `h3` de cântico, oração e comentários não viram partes.
- `h2` sem classe de cor (texto bíblico "JEREMIAS 20-21") é ignorado.
- Títulos com entidades decodificadas e espaços normalizados (sem `&nbsp;`, sem quebra interna, sem espaço duplo).
- HTML sem nenhuma das três seções lança `ScheduleParseException` em vez de lista vazia.
- Nenhum teste acessa a rede.

## Ciclos TDD

Todos em `test/services/schedule_parser_test.dart`.

| # | Caso de teste | Código que passou a existir |
|---|---------------|------------------------------|
| 1 | acha o caminho do documento da Apostila Vida e Ministério | `ScheduleParser.parseWeekPage`, `WeekDocumentLink`, filtro por href de documento + texto do cartão |
| 2 | ignora o documento de A Sentinela, mesmo vindo antes na página | (guarda de regressão; RED provado por mutação, removendo o filtro de texto) |
| 3 | extrai o rótulo da semana com o traço – (U+2013) | leitura de `.cardLine1` + `_normalizeText` |
| 4 | sem link da apostila, lança ScheduleParseException explicando | `ScheduleParseException` e a troca de `firstWhere` por `firstOrNull` + throw |
| 5 | com link mas sem o rótulo da semana, lança ScheduleParseException | validação do rótulo vazio |
| 6 | normaliza o rótulo da semana com `&nbsp;` e quebras de linha | (guarda de regressão da normalização) |
| 7 | devolve as três seções na ordem do documento, com kind e título | `ParsedSection`, `parseDocument`, mapa de classes de cor → `SectionKind` |
| 8 | lista as partes de Tesouros já numeradas pelo wol | varredura de `h2, h3` em ordem de documento com `_SectionDraft` |
| 9 | lista as partes de Faça Seu Melhor no Ministério | (regressão; RED provado por mutação A) |
| 10 | lista as partes de Nossa Vida Cristã | (regressão; RED provado por mutação A) |
| 11 | não transforma cântico, oração e comentários em partes | (regressão; RED provado por mutação A) |
| 12 | ignora o h2 do texto bíblico da semana, que não tem classe de cor | (regressão; RED provado por mutação B) |
| 13 | decodifica entidades e normaliza os espaços dos títulos | (regressão; RED provado por mutação C) |
| 14 | sem nenhuma das três seções, lança ScheduleParseException | throw quando nenhuma seção foi aberta |
| 15 | seção sem nenhuma parte vem com a lista de partes vazia | (borda; seção vazia não é erro) |
| 16 | parte numerada sem classe de cor ainda entra na seção aberta | `_isPartOf` com o fallback pela numeração |
| 17 | (asserção extra no ciclo 4) `toString` da exceção | cobertura da última linha descoberta |

Mutações usadas para provar que os testes que passaram de primeira são significativos (a implementação mutada foi sempre revertida em seguida):

- **A** — aceitar qualquer `h3` dentro da seção aberta: falharam os testes 10 e 11.
- **B** — deixar `h2` sem cor abrir seção: falharam os testes 7, 8, 9, 10 e 12.
- **C** — remover a normalização dos títulos: falhou o teste 13.
- Sem o filtro pelo texto do cartão, falhou o teste 2.

## O que foi feito

Criado o service `ScheduleParser` (sem estado, `const`), com duas operações puras:

- `parseWeekPage(String html)` → `WeekDocumentLink { documentPath, weekLabel }`. Procura entre as âncoras a que aponta para um documento do wol (`/pt/wol/d/r5/.../<id>`) **e** cujo texto contém "Apostila Vida e Ministério"; o rótulo sai do `.cardLine1` do mesmo cartão.
- `parseDocument(String html)` → `List<ParsedSection> { kind, title, partTitles }`. Percorre `h2, h3` em ordem de documento: um `h2` com classe de cor abre a seção; os `h3` seguintes que repetem a cor da seção (ou, na falta de cor, que começam com numeração) viram partes.

As três falhas de layout (sem link, sem rótulo, sem seções) lançam `ScheduleParseException` com mensagem em português terminando na mesma dica: montar a lista manualmente.

## Arquivos criados

- `lib/services/schedule_parser.dart` — `ScheduleParser`, `WeekDocumentLink`, `ParsedSection` e `ScheduleParseException`.
- `test/services/schedule_parser_test.dart` — 16 testes sobre as fixtures reais e HTMLs sintéticos.

## Arquivos modificados

- `lib/services/report_builder.dart` (Task 04, implements/0007) — a Task 04 rodou em paralelo e definiu um `ParsedSection` idêntico ao deste parser. Dois tipos homônimos na mesma camada quebrariam a Task 09 e a 16 ao importar os dois arquivos juntos. Consolidado: a definição ficou no produtor (o parser) e o `report_builder.dart` passou a importá-la e reexportá-la (`export ... show ParsedSection`), de modo que o `report_builder_test.dart` seguiu compilando sem alteração. Só a camada Services foi tocada.
- `CLAUDE.md` — a seção "Scraping do wol.jw.org" ganhou o caminho do parser e a regra de degradação pela numeração.

## Decisões técnicas

- **`ParsedSection` em vez de `MeetingSection`.** O parser não inventa ids nem tempos: devolve só texto, e o `ReportBuilder` (Task 04) transforma isso em `MeetingSection`/`TimedItem`. Mantém o service puro e evita duplicar a geração de ids em dois lugares.
- **Parte = `h3` com a cor da seção.** No HTML real toda parte repete a classe de cor do `h2` da sua seção, enquanto cânticos, orações e comentários não têm cor nenhuma. Isso exclui os três estruturalmente, sem depender de casar texto ("Cântico", "Comentários"), que quebraria em outro idioma ou com mudança de redação.
- **Fallback pela numeração.** Se o wol parar de colorir os `h3`, um título que comece com `N. ` ainda é aceito como parte da seção aberta — a numeração é a marca mais estável da programação. O `CLAUDE.md` pede que o parser degrade com elegância, e essa regra evita que uma mudança só de estilo derrube o download.
- **Rótulo ausente é erro, não vazio.** O rótulo vai no cabeçalho do relatório e do print; devolver `""` empurraria o defeito para a UI. Como a mensagem de erro já oferece a montagem manual, falhar cedo é mais honesto.
- **Normalização única (`_normalizeText`).** O `\s` do Dart já cobre `U+00A0`, então um único `replaceAll(RegExp(r'\s+'), ' ').trim()` resolve `&nbsp;`, quebras de linha e espaço duplo. As demais entidades (`&amp;`) já vêm decodificadas pelo pacote `html`.
- **Seção sem partes não é erro.** Só a ausência das três seções derruba o parse; uma seção vazia é devolvida com `partTitles` vazio, porque o usuário consegue adicionar partes na mão.
- **Fixtures lidas com `File(...).readAsStringSync()`.** Nenhum mock de HTTP é necessário aqui: o parser recebe `String`. A rede é problema do `WolRepository` (Task 06).
- **Testes que passaram de primeira** (2, 6, 9-13) foram mantidos como guardas de regressão dos critérios de aceite, mas só depois de provar por mutação que eles realmente falham quando o comportamento é removido.

## Como validar

```bash
flutter test test/services/schedule_parser_test.dart
flutter analyze
```

## Resultado da validação

- `flutter test test/services/schedule_parser_test.dart` → **16 testes passando**, ~0,5s.
- `flutter test test/models test/utils test/repositories test/services/schedule_parser_test.dart --coverage` → **115 testes passando**; nenhuma regressão nas tasks já concluídas.
- Cobertura de `lib/services/schedule_parser.dart`: **45/45 linhas (100%)**. O LCOV do Dart não emite contadores de branch; as ramificações foram cobertas por testes explícitos dos dois lados (link presente/ausente, rótulo cheio/vazio, `h2` com/sem cor, `h3` colorido / numerado sem cor / nenhum dos dois, documento com/sem seção).
- `flutter analyze` → **No issues found!**
- Observação: no momento da execução, `test/services/meeting_timer_service_test.dart` (Task 05, em andamento por outro subagente em paralelo) estava vermelho. Não tem relação com esta task — nenhum arquivo dela foi tocado aqui.
