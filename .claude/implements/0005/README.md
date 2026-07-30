# [0005] Models do domínio com serialização JSON

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 02

## Solicitação

> Spec 0001 — Task 02: Implemente por TDD os models do domínio em `lib/models/` (sugestão: `section_kind.dart`, `timed_item.dart`, `meeting_section.dart`, `meeting_report.dart`), com testes em `test/models/`. Use exatamente o contrato de models descrito na seção "Contexto técnico" da spec `.claude/specs/0001/README.md` — leia esse arquivo antes de começar. Não invente campos além dos listados.
>
> Toque apenas na camada Models; não modifique arquivos de outras camadas.

## Contexto

Todas as demais tasks da spec 0001 dependem deste contrato: o parser devolve seções, o `ReportBuilder` monta um `MeetingReport`, o `MeetingTimerService` transforma relatórios em novos relatórios, a persistência serializa e restaura o relatório inteiro, e a UI lê a ordem canônica dos itens. Uma reunião dura ~1h45 e não se repete: o round-trip JSON precisa ser fiel e a decodificação de um JSON estragado não pode derrubar o app com um `TypeError`.

## Critérios de aceite

- `TimedItem`, `MeetingSection` e `MeetingReport` imutáveis (campos `final`) com `copyWith` que troca só o que foi passado e preserva o resto.
- `TimedItem.effectiveElapsed(DateTime now)` devolve `elapsed` quando parado e `elapsed + now.difference(runningSince!)` quando correndo.
- `MeetingReport.orderedItems`: `openingComments` → itens de cada seção na ordem → `closingComments`.
- `MeetingReport.itemById(String id)` acha item fixo, de seção ou sub-item; `null` quando não existe.
- `toJson`/`fromJson` com round-trip fiel (ids, labels, `elapsed`, `isSubItem`, seções e ordem); `startedAt`, `endedAt` e `runningSince` sobrevivem como `DateTime` em ISO-8601 e continuam nulos quando eram nulos.
- `fromJson` com JSON malformado ou campo obrigatório ausente lança `ReportDecodeException`, nunca `TypeError`.
- Igualdade por valor (`==` e `hashCode`) nos três models.

## Ciclos TDD

| # | Caso de teste | Arquivo de teste | Código que passou a existir |
|---|---------------|------------------|------------------------------|
| 1 | devolve o elapsed acumulado quando o item está parado | `test/models/timed_item_test.dart` | `TimedItem` (campos finais) + `effectiveElapsed` |
| 2 | soma o trecho aberto ao elapsed quando o item está correndo | `test/models/timed_item_test.dart` | ramo de `runningSince` em `effectiveElapsed` |
| 3 | copyWith sem argumentos preserva todos os campos | `test/models/timed_item_test.dart` | `TimedItem.copyWith` |
| 4 | limpa o runningSince quando clearRunningSince é usado | `test/models/timed_item_test.dart` | flag `clearRunningSince` |
| 5 | itens com os mesmos valores são iguais / diferem em qualquer campo | `test/models/timed_item_test.dart` | `==`, `hashCode` e `toString` de `TimedItem` |
| 6 | round-trip fiel com data em ISO-8601 e com `runningSince` nulo | `test/models/timed_item_test.dart` | `TimedItem.toJson`/`fromJson` |
| 7 | campo ausente, tipo errado, data inválida e JSON não-objeto lançam `ReportDecodeException` | `test/models/timed_item_test.dart` | `json_decoding.dart`: exceção + `readJsonMap`/`readField`/`readOptionalDateTime` |
| 8 | copyWith da seção sem argumentos preserva todos os campos | `test/models/meeting_section_test.dart` | `SectionKind`, `MeetingSection` e `copyWith` |
| 9 | seções com os mesmos itens são iguais / diferem em um item | `test/models/meeting_section_test.dart` | `==`, `hashCode` com igualdade profunda da lista |
| 10 | round-trip da seção, seção desconhecida, `items` inválido, item inválido | `test/models/meeting_section_test.dart` | `MeetingSection.toJson`/`fromJson`, `SectionKind.fromName`, `readList` |
| 11 | orderedItems percorre abertura, seções e fechamento | `test/models/meeting_report_test.dart` | `MeetingReport` + `orderedItems` |
| 12 | itemById acha fixo, parte e sub-item; null quando não existe | `test/models/meeting_report_test.dart` | `itemById` + `copyWith` do relatório |
| 13 | copyWith preserva, troca só o informado e limpa pelos `clearX` | `test/models/meeting_report_test.dart` | flags `clearStartedAt`/`clearEndedAt`/`clearRunningItemId`/`clearSelectedItemId` |
| 14 | relatórios iguais por valor / diferentes em qualquer campo | `test/models/meeting_report_test.dart` | `==`, `hashCode` e `toString` de `MeetingReport` |
| 15 | round-trip completo por texto, datas ISO-8601, nulos continuam nulos | `test/models/meeting_report_test.dart` | `MeetingReport.toJson`/`fromJson`, `readOptionalString` |
| 16 | JSON não-objeto, campo ausente, tipo errado, item aninhado inválido, mensagem descritiva | `test/models/meeting_report_test.dart` | (comportamento já garantido pelos leitores tipados — testes de guarda) |
| 17 | data que não vem como texto lança `ReportDecodeException` | `test/models/timed_item_test.dart` | (branch já existente em `readOptionalDateTime` — fechou lacuna de cobertura) |
| 18 | `toString` descreve item, seção e relatório | os três arquivos | cobertura dos `toString` diagnósticos |

## O que foi feito

Criada a camada Models inteira, em Dart puro (sem nenhum import de Flutter), seguindo o contrato da spec sem acrescentar campos:

- `SectionKind` com `fromName`, que rejeita seção desconhecida.
- `TimedItem` com `effectiveElapsed`, `copyWith`, igualdade por valor e serialização.
- `MeetingSection` com igualdade profunda da lista de itens.
- `MeetingReport` com `orderedItems`, `itemById`, `copyWith` e o round-trip do relatório inteiro.
- `json_decoding.dart` com a exceção de domínio `ReportDecodeException` e leitores tipados (`readJsonMap`, `readField`, `readOptionalString`, `readOptionalDateTime`, `readList`) usados pelos três models, para que nenhum `TypeError` vaze da decodificação.

## Arquivos criados

- `lib/models/section_kind.dart` — enum das três seções + decodificação por nome
- `lib/models/timed_item.dart` — item cronometrável (fixo, parte ou sub-item)
- `lib/models/meeting_section.dart` — seção com sua lista de itens
- `lib/models/meeting_report.dart` — relatório completo, ordem canônica e busca por id
- `lib/models/json_decoding.dart` — `ReportDecodeException` + leitores tipados de JSON
- `test/models/timed_item_test.dart` — 16 testes
- `test/models/meeting_section_test.dart` — 12 testes
- `test/models/meeting_report_test.dart` — 20 testes

## Arquivos modificados

Nenhum. A task só acrescentou arquivos à camada Models.

## Decisões técnicas

- **`copyWith` com flags `clearX` para os campos anuláveis.** Em Dart, `copyWith(runningSince: null)` é indistinguível de "não passei nada". Como a Task 05 precisa parar o cronômetro (`runningSince` → nulo) e o `reset` precisa zerar `startedAt`/`endedAt`/`runningItemId`/`selectedItemId`, cada campo anulável ganhou uma flag `clearX`. É a alternativa mais simples a um sentinel object, e mantém `copyWith` sem argumentos preservando tudo.
- **`elapsed` serializado como `elapsedMicroseconds` (int).** `Duration` tem precisão de microssegundos e nasce de `DateTime.difference`; gravar segundos ou milissegundos perderia precisão e quebraria o round-trip fiel exigido pelo critério de aceite.
- **Datas em ISO-8601 via `toIso8601String`/`DateTime.tryParse`.** `tryParse` em vez de `parse` para transformar data inválida em `ReportDecodeException` em vez de `FormatException`.
- **Leitores tipados centralizados em `json_decoding.dart`.** Todo acesso a campo passa por `readField<T>`, que distingue "campo ausente" de "tipo errado" e monta a mensagem em português. Isso é o que garante o critério do `ReportDecodeException` em vez de `TypeError` — verificado por mutação: trocando um `readField<String>` por um cast cru, os testes de guarda falham com `_TypeError`.
- **Igualdade profunda escrita à mão (`_mesmosItens`, `_mesmosSecoes`).** Preferido a `listEquals` de `package:flutter/foundation.dart` para manter a camada Models em Dart puro, sem depender do Flutter engine.
- **Fixtures de teste sem `const`.** Os primeiros testes de igualdade passaram antes de `==` existir: o compilador canoniza objetos `const` idênticos, e a comparação caía em `identical`. As fixtures foram trocadas para construtores não-`const`, o que produziu o RED legítimo. Fica registrado porque é uma armadilha que vai reaparecer nos testes das próximas tasks.
- **`toString` nos três models** — não é exigido pelos critérios, mas as falhas de teste mostravam `Instance of 'TimedItem'`, inútil para depurar. Está coberto por testes.
- **Ciclos 16 e 17 passaram no primeiro RED.** São testes de guarda de comportamento já implementado pelos leitores tipados em ciclos anteriores; foram mantidos por cobrirem branches distintos (item aninhado inválido, data não-textual) e por serem exatamente os critérios de aceite da task. A mutação descrita acima confirma que eles falham se a proteção sumir.

## Como validar

```bash
flutter test test/models/
flutter test --coverage test/models/
flutter analyze
```

## Resultado da validação

- `flutter test test/models/` → **48 testes, todos passando**.
- `flutter test` (suíte inteira do projeto, incluindo as tasks paralelas) → **84 testes, todos passando**.
- Cobertura de linha em `lib/models/` (lcov de `flutter test --coverage test/models/`): **100% nos 5 arquivos** — `timed_item.dart` 40/40, `meeting_report.dart` 69/69, `meeting_section.dart` 29/29, `json_decoding.dart` 29/29, `section_kind.dart` 4/4.
- Cobertura de branch: a cobertura do Dart VM não emite registros `BRDA`, então os ramos foram auditados um a um contra os testes. Todas as saídas condicionais têm teste dedicado (parado/correndo, cada `clearX` ligado e desligado, campo ausente vs. tipo errado vs. data inválida, lista vazia vs. preenchida, igualdade por identidade vs. por valor).
- `flutter analyze` → **No issues found**.
