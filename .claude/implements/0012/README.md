# [0012] Teste de integração do fluxo completo da reunião

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 16

## Solicitação

> Implemente por TDD o teste de integração em `test/integration/meeting_flow_test.dart`, cobrindo o caminho que nenhuma task unitária cobre: HTML real → parser → `ReportBuilder` → `MeetingTimerService` → persistência → restauração. Use as fixtures `test/fixtures/meetings_week_2026_31.html` e `test/fixtures/mwb_2026_31.html`, um `MockClient` no lugar da rede e um `Clock` falso que você faz avançar manualmente. Nada de rede e nada de `DateTime.now()` real.
>
> Toque apenas em arquivos de teste; não modifique código de produção — se um teste revelar um defeito, relate-o em vez de corrigir fora do escopo.

## Contexto

As tasks 03, 04, 05 e 07 entregaram parser, montador, cronômetro e persistência com testes unitários próprios, cada um com a entrada montada à mão. Ninguém verificava que as quatro peças encaixam: que o texto que o parser extrai do HTML real é o que o `ReportBuilder` espera receber, que os ids gerados na montagem sobrevivem ao JSON, e que uma reunião de ponta a ponta fecha com a conta de tempo batendo.

É o risco mais caro do app: a reunião acontece uma vez e não se repete. Um desencontro entre camadas só apareceria ao vivo, no salão, com o irmão segurando o celular.

## Critérios de aceite

- Partindo das fixtures, o relatório montado tem, na ordem canônica: Comentários iniciais, as 3 partes de Tesouros com seus sub-itens, as 3 de Faça Seu Melhor com Conselho e Transição, o "Presidente" avulso e as 2 partes de Nossa Vida Cristã, e Comentários finais — batendo com a regra de sub-itens do `CLAUDE.md`.
- Simulando a reunião inteira com o relógio falso (`start`, e um `next` por item até o fim), cada item termina com exatamente a duração que o relógio avançou enquanto ele corria, e a soma dos itens bate com o tempo total decorrido.
- Usar as setas no meio da reunião muda a seleção sem alterar o tempo do item que está correndo.
- Após `endMeeting`, `startedAt` e `endedAt` refletem os instantes do relógio falso e nenhum item continua com `runningSince` preenchido.
- Salvar o relatório no meio da reunião e recarregá-lo devolve um relatório equivalente, e o cronômetro continua correndo corretamente a partir dele.

## Ciclos TDD

Todo o código de produção envolvido já existia (tasks 03, 04, 05 e 07), então o RED clássico — teste falhando por falta de implementação — não se aplica. Para não aceitar teste que passa vazio, cada ciclo terminou com uma **prova de falsificação**: a expectativa foi deliberadamente perturbada, o teste foi rodado e observado em vermelho, e só então restaurada. As duas provas mais importantes estão registradas na coluna da direita.

| # | Caso de teste | Arquivo de teste | Verificação |
|---|---------------|------------------|-------------|
| 1 | monta os itens na ordem canônica da semana 2026/31 | `test/integration/meeting_flow_test.dart` | Falsificado: mover o "Presidente" avulso de Nossa Vida Cristã uma posição para frente falha em `[17]`. Confirma que o avulso abre a seção, antes da parte 7 |
| 2 | aplica a regra de sub-itens de cada seção às partes reais | idem | Pares `(label, isSubItem)` por seção: Leitura da Bíblia com Conselho+Transição, avulso com `isSubItem == false`, parte 8 sem sub-item |
| 3 | as três seções vêm com o tipo e o título do wol | idem | `SectionKind` e títulos em caixa alta na ordem do documento |
| 4 | herda o rótulo da semana e nasce zerado, pronto para cronometrar | idem | `weekLabel` com o traço `–` (U+2013) atravessando HTTP e parser; tudo zerado; ids únicos |
| 5 | busca só a página da semana e a apostila, nunca A Sentinela | idem | Lista exata das duas URLs requisitadas |
| 6 | cada item fica com exatamente o tempo que correu no relógio | idem | Falsificado: trocar as durações esperadas de dois itens de lugar falha. Confirma atribuição exata por item, não só o total |
| 7 | a soma dos itens bate com o tempo total decorrido da reunião | idem | Soma dos 22 itens == `agora - startedAt`: nenhum segundo se perde nem é contado duas vezes |
| 8 | o Próximo no último item para o cronômetro sem estourar a lista | idem | Sem item correndo, lista intacta, seleção no último |
| 9 | mudam a seleção sem tocar no item que está correndo | idem | `runningItemId`, `runningSince` e `elapsed` do item corrente intocados |
| 10 | a seta para cima também não interrompe a contagem | idem | Mesma garantia no sentido inverso |
| 11 | o item corrente segue acumulando por cima do uso das setas | idem | 20s antes das setas + 40s depois = 1min |
| 12 | startedAt e endedAt são os instantes do relógio falso | idem | Instantes absolutos e a diferença entre eles |
| 13 | nenhum item continua correndo depois de encerrar | idem | `runningSince` limpo em todos; o trecho aberto no encerramento entra no acumulado |
| 14 | recarregar devolve um relatório equivalente ao salvo | idem | Igualdade por valor do relatório inteiro |
| 15 | o item que corria volta correndo, do mesmo instante | idem | Campo a campo, sem depender do `==` do model |
| 16 | o cronômetro continua contando a partir do relatório restaurado | idem | `effectiveElapsed` já correto antes de fechar o trecho; `next` fecha com 1min |
| 17 | a reunião terminada depois do reload fecha com os tempos certos | idem | A conta total continua fechando através do round-trip de JSON |

## O que foi feito

Criado o arquivo de teste de integração, com quatro grupos que percorrem o fluxo inteiro do app sem rede e sem relógio real:

1. **Das fixtures ao relatório montado** — `WolRepository` (com `MockClient` servindo as fixtures em bytes) → `ScheduleParser.parseWeekPage` → `WolRepository.fetchDocument` → `ScheduleParser.parseDocument` → `ReportBuilder.build`. Verifica os 22 itens da semana 2026/31 na ordem canônica e a regra de sub-itens.
2. **Cronometrando a reunião inteira** — `start` e um `next` por item, com o relógio falso avançando uma duração distinta em cada um.
3. **Setas no meio da reunião** — a distinção entre item que corre e item selecionado.
4. **Salvar e restaurar no meio da reunião** — `ReportStorageRepository` com `SharedPreferences.setMockInitialValues({})`, e o cronômetro seguindo em frente a partir do relatório desserializado.

Nenhum arquivo de produção foi tocado.

## Arquivos modificados

Nenhum. A task é exclusivamente de teste.

## Arquivos criados

- `test/integration/meeting_flow_test.dart` — teste de integração das quatro camadas, 17 casos.

## Decisões técnicas

- **Fixtures servidas em bytes, não em texto.** `http.Response(String, int)` codifica o corpo em latin-1 quando o `Content-Type` não traz charset, que é justamente o caso do wol. Passar a fixture como `String` produziria mojibake artificial no teste. Usando `http.Response.bytes(File(...).readAsBytesSync(), 200)` o `WolRepository` recebe exatamente os bytes que receberia do site e exercita de verdade o `utf8.decode` dele — é o que faz o traço `–` do `weekLabel` chegar íntegro ao relatório.
- **Relógio falso como classe com `ler()`, não como closure sobre variável.** `MeetingTimerService` recebe `relogio.ler`; o teste chama `relogio.avancar(...)`. Fica explícito no corpo do teste quanto tempo passou em cada trecho, que é o dado sob asserção.
- **Uma duração distinta por posição** (`23 + indice * 7` segundos). Se todos os itens durassem o mesmo, uma troca de atribuição entre itens vizinhos passaria despercebida — e é exatamente esse o erro mais provável numa máquina de estados de cronômetro. A prova de falsificação do ciclo 6 confirmou que a asserção pega essa troca.
- **Relatório da semana montado uma vez em `setUpAll`.** Os models são imutáveis e os services são puros, então não há estado compartilhado entre testes; só o custo de parsear duas fixtures 17 vezes foi evitado. O teste que verifica as URLs requisitadas monta o seu próprio, porque precisa observar as chamadas HTTP.
- **Provas de falsificação em vez de RED por ausência de implementação.** Como a task proíbe tocar em produção e as camadas já existiam, o RED honesto é demonstrar que a asserção sabe falhar. Feito e observado nos dois ciclos de maior risco (ordem canônica e atribuição de tempo).
- **Deixado sem teste de propósito:** os caminhos de erro de cada camada (HTML sem apostila, HTTP fora do ar, JSON corrompido). Já são cobertos pelos testes unitários das tasks 03, 06 e 07; repeti-los aqui só duplicaria cobertura sem exercitar integração nova.

## Como validar

```bash
flutter test test/integration/meeting_flow_test.dart
```

## Resultado da validação

- `flutter test test/integration/meeting_flow_test.dart` → **17 testes passando**.
- `flutter test` (suíte inteira) → **190 testes passando** (173 antes desta task, +17).
- `flutter analyze` → `No issues found!`.
- `flutter test --coverage`, arquivos exercitados por este fluxo:

| Arquivo | Linhas |
|---------|--------|
| `lib/services/meeting_timer_service.dart` | 118/118 (100%) |
| `lib/services/report_builder.dart` | 30/30 (100%) |
| `lib/services/schedule_parser.dart` | 44/45 (97,8%) |
| `lib/models/meeting_report.dart` | 69/69 (100%) |
| `lib/models/timed_item.dart` | 40/40 (100%) |
| `lib/models/meeting_section.dart` | 29/29 (100%) |
| `lib/models/section_kind.dart` | 4/4 (100%) |
| `lib/models/json_decoding.dart` | 29/29 (100%) |
| `lib/repositories/report_storage_repository.dart` | 18/18 (100%) |
| `lib/repositories/wol_repository.dart` | 20/20 (100%) |

A única linha descoberta é `schedule_parser.dart:64`, o construtor `const ScheduleParser()`: construtores `const` são canonizados em tempo de compilação e nunca aparecem como executados no lcov. Não é caso de teste faltando, e a situação é anterior a esta task.

O `lcov` gerado pelo `flutter test --coverage` não emite dados de branch (`BRF`/`BRH` vêm zerados) — não há, nesta toolchain, número de cobertura de branch a reportar.

## Defeitos encontrados

Nenhum. As quatro camadas encaixam sem ajuste: os 22 itens saem das fixtures na ordem canônica esperada, a conta de tempo fecha exatamente, as setas não interferem no cronômetro e o round-trip de JSON preserva a reunião em andamento.
