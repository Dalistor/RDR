# [0007] Montagem do relatório com itens fixos e sub-itens automáticos

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 04

## Solicitação

> Spec 0001 — Task 04: Implemente por TDD o montador do relatório em `lib/services/report_builder.dart`, com testes em `test/services/report_builder_test.dart`. Ele recebe a programação parseada (seções + títulos de partes) e o rótulo da semana, e devolve um `MeetingReport` zerado e pronto para cronometrar. Leia a regra dos sub-itens no `CLAUDE.md`. Não dependa do parser: monte a entrada à mão nos testes.
>
> Toque apenas na camada Services (pode importar Models); não modifique arquivos de outras camadas.

## Contexto

O parser (Task 03) entrega só a matéria bruta da programação: as três seções e os títulos das partes. Falta o passo que transforma isso na lista realmente cronometrável — os itens fixos que abrem e fecham a reunião, e os sub-itens (`Presidente`, `Conselho`, `Transição`) que a regra da seção manda inserir automaticamente entre as partes. Esse é o esqueleto que o cronômetro (Task 05) percorre e que a tela (Task 12) desenha.

A regra dos sub-itens está no `CLAUDE.md`, seção "Regra dos sub-itens (automática por seção)".

## Critérios de aceite

- O relatório abre com o item fixo `"Comentários iniciais"` e fecha com `"Comentários finais"`, ambos fora das seções e com `isSubItem == false`.
- Em Tesouros, as partes 1 e 2 recebem um sub-item `"Presidente"` cada.
- A parte cujo título contém "Leitura da Bíblia" é exceção: recebe `"Conselho"` e `"Transição"`, nessa ordem, e não recebe `"Presidente"`.
- Em Faça Seu Melhor, toda parte recebe `"Conselho"` e `"Transição"`, nessa ordem.
- Nossa Vida Cristã abre com um item avulso `"Presidente"` com `isSubItem == false`, antes da primeira parte.
- Em Nossa Vida Cristã, cada parte recebe um sub-item `"Presidente"`, exceto a última parte da seção, que fica sem nenhum.
- Todos os sub-itens têm `isSubItem == true`; partes e itens fixos têm `isSubItem == false`.
- Todo item nasce com `elapsed == Duration.zero` e `runningSince == null`; o relatório nasce com `startedAt`, `endedAt`, `runningItemId` e `selectedItemId` nulos e com o `weekLabel` recebido.
- Todo item tem `id` único dentro do relatório.
- Uma seção sem partes não quebra a montagem.

## Ciclos TDD

| # | Caso de teste | Arquivo de teste | Código que passou a existir |
|---|---------------|------------------|------------------------------|
| 1 | abre com "Comentários iniciais" e fecha com "Comentários finais", fora das seções | `test/services/report_builder_test.dart` | `ParsedSection`, `ReportBuilder.build` devolvendo o relatório só com os dois itens fixos |
| 2 | nasce com o rótulo da semana recebido e sem estado de cronômetro | idem | nenhum — passou pelos defaults do `MeetingReport` (ver Decisões técnicas) |
| 3 | preserva as seções recebidas na ordem, com tipo e título | idem | mapeamento `ParsedSection` → `MeetingSection` |
| 4 | cada parte vira um item da sua seção, na ordem e sem ser sub-item | idem | fábrica `criarItem` com contador de `id`; partes viram `TimedItem` |
| 5 | cada parte comum de Tesouros ganha um sub-item "Presidente" | idem | primeira regra de sub-item por seção |
| 6 | a parte de Leitura da Bíblia ganha "Conselho" e "Transição", nessa ordem, e não ganha "Presidente" | idem | `_subItensDaParte` com a exceção de Tesouros |
| 7 | toda parte de Faça Seu Melhor ganha "Conselho" e "Transição", nessa ordem | idem | ramo `ministry` de `_subItensDaParte` |
| 8 | Nossa Vida Cristã abre com um "Presidente" avulso, que não é sub-item | idem | item avulso no início da seção |
| 9 | cada parte de Nossa Vida Cristã ganha "Presidente", menos a última | idem | `ehUltimaParte` em `_subItensDaParte`; extração de `_montarSecao` no refactor |
| 10 | só os sub-itens automáticos são marcados; partes e itens fixos não | idem | nenhum — comportamento já garantido; fecha a verificação da flag `isSubItem` |
| 11 | todo item nasce sem tempo acumulado e parado | idem | nenhum — garantido pelos defaults de `TimedItem` |
| 12 | todo item tem id único dentro do relatório | idem | nenhum — garantido pelo contador do ciclo 4 |
| 13 | Nossa Vida Cristã sem partes gera só o "Presidente" avulso | idem | nenhum — borda já suportada pelo laço |
| 14 | as demais seções sem partes ficam vazias | idem | nenhum — idem |
| 15 | em Nossa Vida Cristã com uma única parte, ela é a última e fica sem sub-item | idem | nenhum — idem |

## O que foi feito

Criado o `ReportBuilder`, service puro que recebe `weekLabel` + `List<ParsedSection>` e devolve o `MeetingReport` zerado:

- Emite `Comentários iniciais` e `Comentários finais` como `openingComments`/`closingComments` — fora das seções, na posição fixa que a ordem canônica do model já garante.
- Copia cada seção preservando `kind`, `title` e a ordem, e transforma cada título de parte em um `TimedItem`.
- Insere os sub-itens automáticos conforme a regra do `CLAUDE.md`, centralizada em `_subItensDaParte`.
- Abre Nossa Vida Cristã com o item avulso `Presidente` (não sub-item).
- Numera os `id` com um contador (`item-1`, `item-2`, …) compartilhado por toda a montagem, garantindo unicidade dentro do relatório.

## Arquivos modificados

Nenhum arquivo pré-existente foi modificado.

## Arquivos criados

- `lib/services/report_builder.dart` — o service `ReportBuilder` e o tipo de entrada `ParsedSection`.
- `test/services/report_builder_test.dart` — 15 testes cobrindo a regra dos sub-itens, o estado inicial e as bordas de seção vazia.

## Decisões técnicas

**Tipo de entrada próprio (`ParsedSection`).** A task exige não depender do parser (Task 03, feita em paralelo), então o builder define seu próprio contrato de entrada: `kind` + `title` + `partTitles`. É o mínimo que a regra precisa, e mantém o service testável sem HTML. A Task 09 (providers) é o ponto de costura entre a saída do parser e essa entrada — se o `schedule_parser` expuser um tipo equivalente com outro nome, a adaptação é de uma linha ali, e não uma dependência cruzada entre dois services.

**`id` por contador, não UUID.** O contrato do model admite "uuid ou contador estável". Contador dá ids determinísticos, o que deixa os testes e o JSON persistido legíveis, e dispensa dependência nova. A unicidade exigida é dentro do relatório, que é exatamente o escopo do contador. A Task 05 (`addItem`) gera ids próprios para itens inseridos à mão e precisa apenas não colidir com o padrão `item-N`.

**Leitura da Bíblia identificada por `contains`, não por número da parte.** A numeração muda de semana para semana e o parser entrega o título já numerado (`3. Leitura da Bíblia`); casar por trecho do título é o que sobrevive à variação. Match sensível a maiúsculas, porque o texto vem padronizado da publicação — generalizar para case-insensitive seria especulação sem teste que a exija.

**Ciclos que passaram sem código novo (2, 10–15).** São critérios de aceite garantidos por construção: os defaults de `TimedItem`/`MeetingReport`, o contador do ciclo 4 e os limites do laço. Foram mantidos como testes de regressão porque cada um trava um comportamento que uma mudança plausível quebraria — por exemplo, um builder que já pré-selecionasse o primeiro item violaria o ciclo 2, e mexer no laço de partes violaria os ciclos 13–15. Nenhum deles é duplicata de outro teste.

**Sem `Clock` injetado.** O builder não lê o relógio: o relatório nasce zerado e sem `startedAt`. Quem grava horários é o `MeetingTimerService` (Task 05), que recebe o `Clock`.

## Como validar

```bash
flutter test test/services/report_builder_test.dart
flutter analyze
```

## Resultado da validação

- `flutter test test/services/report_builder_test.dart` → **15 testes passando**.
- `flutter test --coverage` (suíte inteira) → **132 testes passando**, nenhuma regressão.
- Cobertura de `lib/services/report_builder.dart`: **29 de 31 linhas (LH:29 / LF:31)**. As duas linhas restantes são os construtores `const` de `ParsedSection` e de `ReportBuilder`, que a VM resolve em tempo de compilação nos contextos `const` dos testes e por isso nunca aparecem como executadas — não há caminho de execução descoberto.
- Cobertura de ramo verificada manualmente (o lcov do Dart não emite `BRDA`): os cinco ramos de `_subItensDaParte` (Tesouros comum, Tesouros/Leitura da Bíblia, Ministério, Nossa Vida Cristã não-última, Nossa Vida Cristã última) têm teste dedicado, assim como os dois lados do `if` do `Presidente` avulso e o laço de partes com lista vazia.
- `flutter analyze` → **No issues found**.
