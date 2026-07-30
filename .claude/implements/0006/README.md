# [0006] Repositório de persistência do relatório

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 07

## Solicitação

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

## Contexto

Uma reunião dura ~1h45 e não se repete: perder o estado por um reload ou por o Android matar o app é perder o trabalho da noite (`CLAUDE.md`, "Restrições e Cuidados"). Esta é a camada que grava o `MeetingReport` inteiro no dispositivo a cada mudança relevante e o restaura na abertura do app.

O outro lado da moeda é igualmente crítico: um valor ilegível gravado em disco — resto de uma versão antiga, escrita interrompida — não pode impedir o irmão de cronometrar a reunião. Por isso `load()` degrada para "sem relatório salvo" em vez de propagar exceção.

## Critérios de aceite

Comportamentos observáveis derivados da task:

1. `load` sem nada salvo devolve `null`, sem lançar.
2. `save` seguido de `load` devolve um relatório igual ao original.
3. O round-trip preserva o estado do cronômetro: `elapsed` de cada item, `startedAt`/`endedAt`, `runningItemId`, `selectedItemId` e o `runningSince` do item que estava correndo.
4. O round-trip preserva a estrutura: seções, ordem canônica dos itens, `isSubItem` dos sub-itens e itens acrescentados manualmente durante a reunião.
5. Um relatório ainda não iniciado (datas e ids nulos, seções vazias) volta com os campos nulos intactos.
6. Salvar duas vezes sobrescreve: `load` devolve o último relatório.
7. Salvar duas vezes não acumula chaves no armazenamento — o relatório mora sob uma única chave.
8. Valor corrompido (JSON inválido) faz `load` devolver `null` em vez de propagar exceção.
9. Valor corrompido é apagado da chave, para não travar a próxima reunião.
10. JSON válido mas de formato antigo (campos que o app não entende mais) devolve `null` e é apagado.
11. Valor de outro tipo sob a chave (ex.: um `int`) devolve `null` e é apagado.
12. `clear` remove o relatório salvo e `load` depois dela devolve `null`.
13. `clear` não deixa a chave para trás no armazenamento.
14. `clear` sem nada salvo não lança.
15. Depois de limpar, salvar de novo funciona normalmente.

## Ciclos TDD

Todos os testes estão em `test/repositories/report_storage_repository_test.dart`.

| # | Caso de teste | RED real? | Código que passou a existir |
|---|---------------|-----------|------------------------------|
| 1 | sem nada salvo devolve null, sem lançar | sim (classe inexistente) | `ReportStorageRepository`, `storageKey`, esqueleto de `load` |
| 2 | carregar depois de salvar devolve um relatório igual ao original | sim (`save` inexistente) | `save` com `jsonEncode(report.toJson())`; `load` com `jsonDecode` + `MeetingReport.fromJson` |
| 3 | salvar duas vezes deixa apenas o último relatório | não — verde de primeira | nenhum: o `setString` sob chave única já sobrescreve |
| 4 | salvar duas vezes não acumula chaves no armazenamento | não — verde de primeira | nenhum: idem |
| 5 | JSON inválido devolve null em vez de propagar exceção | sim (`FormatException`) | `catch on FormatException` devolvendo `null` |
| 6 | JSON inválido é apagado, para não travar a próxima reunião | sim (chave permanecia) | `prefs.remove(storageKey)` no tratamento |
| 7 | JSON de formato antigo devolve null e é apagado | sim (`ReportDecodeException`) | `catch on ReportDecodeException` |
| 8 | valor de outro tipo sob a chave devolve null e é apagado | sim (`TypeError` no `getString`) | `getString` movido para dentro do `try` + `catch on TypeError` |
| 9 | remove o relatório salvo e carregar depois devolve null | sim (`clear` inexistente) | `clear()` |
| 10 | preserva o estado do cronômetro: tempos, início e item correndo | não — verde de primeira | nenhum (ver Decisões técnicas) |
| 11 | preserva seções, ordem dos itens, sub-itens e itens adicionados na mão | não — verde de primeira | nenhum (ver Decisões técnicas) |
| 12 | relatório ainda não iniciado volta com os campos nulos intactos | não — verde de primeira | nenhum: cobertura de borda |
| 13 | não deixa a chave para trás no armazenamento | não — verde de primeira | nenhum: cobertura do efeito colateral de `clear` |
| 14 | limpar sem nada salvo não lança | não — verde de primeira | nenhum: cobertura de borda |
| 15 | depois de limpar dá para salvar de novo | não — verde de primeira | nenhum: cobertura de borda |

Dois refactors com a suíte verde:

- Após o ciclo 8, os três `catch` idênticos viraram chamadas a um único `_descartarLixo(prefs)`.
- Na validação de cobertura, o guarda `if (!prefs.containsKey(storageKey))` foi removido: com ele, o `if (gravado == null)` logo abaixo virava código morto (com a chave presente, `getString` ou devolve a `String` ou lança). Sem o guarda, os dois ramos do null-check são alcançáveis e exercitados.

## O que foi feito

Criado o `ReportStorageRepository`, única porta de gravação e leitura do relatório em andamento no dispositivo. Três operações:

- `save(MeetingReport)` — serializa com `toJson()` e grava a string JSON sob a chave `rdr.meeting_report`.
- `load()` — lê a chave e reconstrói o `MeetingReport`; devolve `null` quando não há nada salvo **ou** quando o valor gravado é ilegível, apagando-o nesse caso.
- `clear()` — remove a chave.

O repositório não tem estado próprio nem regra de negócio: só traduz `MeetingReport` ↔ JSON e conversa com o `shared_preferences`, como manda a Arquitetura de Camadas.

## Arquivos criados

- `lib/repositories/report_storage_repository.dart` — persistência do relatório em `shared_preferences`.
- `test/repositories/report_storage_repository_test.dart` — 15 testes cobrindo round-trip, sobrescrita, corrupção e limpeza.

## Arquivos modificados

Nenhum. A task é aditiva e não tocou em outras camadas.

## Decisões técnicas

**Uma única chave, `rdr.meeting_report`.** A task pede explicitamente uma chave só. Ela é exposta como `static const storageKey` para o teste poder plantar lixo sob ela sem duplicar o literal — e é isso que torna testável o critério de corrupção.

**API legada do `shared_preferences` (`getInstance()`), sem injeção de dependência.** A task manda usar `SharedPreferences.setMockInitialValues({})`, que é o mecanismo de dublê da API legada. Como esse mock já isola completamente o teste do disco, injetar a instância pelo construtor seria complexidade sem ganho — o repositório continua 100% testável sem Flutter engine além do `TestWidgetsFlutterBinding`.

**Três exceções tratadas, não um `catch` genérico.** O critério exige que lixo em disco não bloqueie a reunião, mas um `catch (_)` engoliria também defeitos reais do app. Foram tratados exatamente os três modos de falha possíveis na leitura, cada um com seu teste:

| Exceção | Origem | Cenário real |
|---------|--------|--------------|
| `FormatException` | `jsonDecode` | escrita interrompida, texto que não é JSON |
| `ReportDecodeException` | `MeetingReport.fromJson` | JSON válido de um formato antigo do app |
| `TypeError` | `prefs.getString` | a chave guarda outro tipo (`int`, lista, booleano) |

**Apagar o valor corrompido, e não apenas ignorá-lo.** Se a chave ficasse lá, toda abertura do app repetiria a decodificação que falha e o próximo `save` disputaria com lixo. Apagar devolve o app ao estado limpo "sem relatório salvo", que é exatamente o estado em que a tela oferece baixar a programação.

**Testes 10 e 11 mantidos apesar de nascerem verdes.** Eles não são duplicata do teste 2: aquele compara com `equals(original)` e portanto depende do `==` do `MeetingReport`, definido em outra camada. Se um dia esse `==` deixar de comparar um campo, o teste 2 passaria vazio sem ninguém notar. Os testes 10 e 11 afirmam os valores restaurados campo a campo e são imunes a isso. O comentário no arquivo de teste registra essa razão.

**Nenhum teste depende de `DateTime.now()`, de rede ou de ordem de execução.** Todas as datas dos fixtures são literais; o `setUp` reinicia o `shared_preferences` com `setMockInitialValues({})` antes de cada teste, e os testes de corrupção replantam os valores mock que precisam.

## Como validar

```bash
flutter test test/repositories/report_storage_repository_test.dart
flutter analyze lib/repositories/report_storage_repository.dart test/repositories/report_storage_repository_test.dart
```

## Resultado da validação

- `flutter test test/repositories/report_storage_repository_test.dart` → **15 testes, todos passando**.
- `flutter test` (suíte inteira) → **123 testes, todos passando**, nenhuma regressão. O número inclui testes de outras tasks da spec 0001 executadas em paralelo.
- `flutter test --coverage` → `lib/repositories/report_storage_repository.dart` com **LF:18 / LH:18 — 100% de linha**. O `lcov` do Dart não emite registros `BRDA`; a análise manual dos ramos confirma cobertura total: os dois ramos do `if (gravado == null)` e cada um dos três `catch` têm teste próprio, e o código morto que existia foi removido no refactor final.
- `flutter analyze` nos dois arquivos desta task → **No issues found!**
