# [0003] Utilitários de formatação de tempo

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 01

## Solicitação

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

## Contexto

Primeira task da spec 0001, sem dependências. Todo o app exibe tempo: a lista da reunião mostra `MM:SS` por item, o cabeçalho e o rodapé do relatório mostram `HH:MM` do relógio do sistema, e o diálogo de edição da Task 14 recebe minutos e segundos em dois campos numéricos separados que precisam virar uma `Duration`.

Centralizar isso na camada Utils evita que Widgets, Screens e o `ReportSheet` do print repitam a mesma aritmética de padding — e garante que o print longo e a tela mostrem exatamente o mesmo texto.

O formato `MM:SS` sem campo de hora é uma decisão de domínio: a reunião dura ~1h45, e o relatório impresso mostra os tempos por parte em minutos corridos, não em `HH:MM:SS`.

## Critérios de aceite

- `formatDuration` devolve `MM:SS` com zero à esquerda nos dois campos.
- Minutos continuam crescendo além de 59 em vez de virar hora (`75:03`, `60:00`).
- Duração negativa vira `"00:00"`, sem sinal de menos — inclusive quando o negativo passa de um minuto.
- Milissegundos são truncados, nunca arredondados para cima (`00:05`, `03:59`).
- `formatClock` devolve `HH:MM` em 24 horas com zero à esquerda, cobrindo meia-noite e `23:59`, ignorando os segundos do instante.
- `parseDurationInput` devolve a `Duration` correspondente e normaliza segundos ≥ 60 somando aos minutos.
- `parseDurationInput` trata cada valor negativo como zero e nunca devolve duração negativa.

## Ciclos TDD

| # | Caso de teste | Arquivo de teste | Código que passou a existir |
|---|---------------|------------------|------------------------------|
| 1 | formata segundos abaixo de um minuto com zero à esquerda | `test/utils/time_format_test.dart` | `formatDuration` com padding de segundos |
| 2 | formata minutos e segundos com dois dígitos | `test/utils/time_format_test.dart` | cálculo dos minutos e do resto em segundos |
| 3 | formata duração zero como 00:00 | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 4 | mantém os minutos crescendo além de 59 em vez de virar hora | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 5 | formata uma hora exata como 60:00, sem campo de hora | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 6 | trata duração negativa de segundos como 00:00 | `test/utils/time_format_test.dart` | clamp `duration.isNegative ? Duration.zero : duration` |
| 7 | não mostra sinal de menos em duração negativa de minutos | `test/utils/time_format_test.dart` | — (coberto pelo clamp do ciclo 6) |
| 8 | trunca milissegundos em vez de arredondar para cima | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 9 | trunca milissegundos na virada de minuto | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 10 | formata hora da tarde em 24 horas | `test/utils/time_format_test.dart` | `formatClock` com padding de hora e minuto |
| 11 | preenche hora e minuto com zero à esquerda | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 12 | formata meia-noite como 00:00, sem virar 12 ou 24 | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 13 | formata o último minuto do dia como 23:59 | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 14 | ignora os segundos do instante | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 15 | devolve a duração correspondente a minutos e segundos | `test/utils/time_format_test.dart` | `parseDurationInput` montando a `Duration` |
| 16 | devolve duração zero quando minutos e segundos são zero | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 17 | normaliza segundos maiores que 59 somando aos minutos | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 18 | normaliza segundos equivalentes a uma hora inteira | `test/utils/time_format_test.dart` | — (já verde; mantido como regressão) |
| 19 | trata minutos negativos como zero, preservando os segundos | `test/utils/time_format_test.dart` | clamp por valor em `parseDurationInput` |
| 20 | trata segundos negativos como zero, preservando os minutos | `test/utils/time_format_test.dart` | — (coberto pelo clamp do ciclo 19) |
| 21 | devolve duração zero quando minutos e segundos são negativos | `test/utils/time_format_test.dart` | — (coberto pelo clamp do ciclo 19) |
| 22 | nunca devolve duração negativa | `test/utils/time_format_test.dart` | — (invariante; guarda de regressão) |

Ciclos com "já verde" são critérios de aceite explícitos da task que a implementação mínima do ciclo anterior já satisfazia (a normalização de `Duration` do próprio Dart, ou o clamp recém-introduzido). Foram escritos, executados e mantidos como guardas de regressão — nenhum deles foi contado como código novo.

Refatoração final (suíte verde antes e depois): extração do helper privado `_twoDigits`, que estava duplicado entre `formatDuration` e `formatClock`, e da constante `_secondsPerMinute` no lugar do literal `60`.

## O que foi feito

Criado o módulo de formatação de tempo da camada Utils com três funções puras de nível superior — sem classe, sem estado, sem I/O:

- `formatDuration(Duration)` → `MM:SS`, com clamp de negativo e truncamento de milissegundos.
- `formatClock(DateTime)` → `HH:MM` em 24 horas.
- `parseDurationInput(int, int)` → `Duration`, com normalização de segundos ≥ 60 e clamp de negativos.

## Arquivos modificados

Nenhum.

## Arquivos criados

- `lib/utils/time_format.dart` — as três funções puras de formatação de tempo usadas pela UI, pelo diálogo de edição e pelo relatório impresso.
- `test/utils/time_format_test.dart` — 22 testes cobrindo caminho feliz, bordas e valores negativos das três funções.

## Decisões técnicas

**Funções de nível superior em vez de classe com métodos estáticos.** São helpers puros sem estado; uma classe só adicionaria cerimônia na chamada (`TimeFormat.formatDuration(...)`) sem ganho. O `CLAUDE.md` descreve a camada Utils exatamente como "helpers puros de formatação", e a proibição de estado reforça a escolha.

**Aritmética manual em vez de `intl` / `DateFormat`.** O `intl` está no projeto, mas `DateFormat` não resolve o requisito central: ele viraria 75 minutos em `01:15`, e o relatório precisa de `75:03`. Como os minutos não podem transbordar para horas, o cálculo direto (`inMinutes` + resto em segundos) é mais simples e mais fiel ao domínio do que lutar contra o formatador.

**`formatClock` também sem `intl`.** Padding manual de `hour`/`minute` é suficiente para `HH:MM` em 24 horas e mantém a função sem dependência de locale — o relógio do relatório não muda de forma conforme a localidade do aparelho.

**Truncamento de milissegundos vem de graça pelo `inSeconds`.** `Duration.inSeconds` já trunca em direção a zero; não foi preciso escrever código para isso. O comportamento ficou explicitamente coberto por dois testes (`00:05` e a virada `03:59`) justamente para que uma refatoração futura que trocasse por arredondamento seja pega pela suíte.

**Clamp de negativo em `formatDuration`, e não no chamador.** O tempo decorrido efetivo de um item é `elapsed + now.difference(runningSince)`; se o relógio do sistema recuar durante a reunião, esse cálculo pode ficar negativo por um instante. A UI mostrando `00:00` é muito melhor do que mostrar `-0:-5`, e concentrar a proteção no formatador evita que cada tela precise lembrar disso.

**Negativos em `parseDurationInput` tratados valor a valor, não no total.** "Valores negativos viram zero" foi lido literalmente: cada campo negativo vira zero de forma independente, então `parseDurationInput(-1, 30)` devolve 30 s em vez de zero total. É o comportamento mais previsível para o diálogo de edição da Task 14, onde os dois campos numéricos são digitados separadamente e um sinal de menos acidental em um campo não deve descartar o que foi digitado no outro. O invariante que realmente importa — nunca devolver duração negativa — está coberto por teste próprio.

**Normalização de segundos ≥ 60 é do próprio `Duration`.** O construtor de `Duration` já soma os campos, então `Duration(minutes: 1, seconds: 90)` é 2 min 30 s sem código adicional. O critério de aceite ficou coberto por testes explícitos (`1, 90` e `0, 3600`) para travar o comportamento.

**Nada foi deixado deliberadamente sem teste.** Não há mocks nesta implementação: as três funções são puras e determinísticas, sem relógio real, rede ou aleatoriedade — os testes passam `DateTime` construído à mão, nunca `DateTime.now()`.

## Como validar

```bash
flutter test test/utils/time_format_test.dart
flutter analyze lib/utils/time_format.dart test/utils/time_format_test.dart
```

## Resultado da validação

- `flutter test test/utils/time_format_test.dart` → **22 testes, todos passando**.
- `flutter analyze lib/utils/time_format.dart test/utils/time_format_test.dart` → **No issues found**.
- `dart format` aplicado nos dois arquivos.
- Cobertura (`flutter test --coverage --branch-coverage` sobre o arquivo de teste): `lib/utils/time_format.dart` com **LF 12 / LH 12 = 100% de linha** e **4/4 branches reportados cobertos (100%)**. Os três operadores ternários do arquivo têm os dois lados exercitados por testes distintos (duração negativa e positiva; minutos negativos e positivos; segundos negativos e positivos).
- A suíte completa do projeto (`flutter test`) apresentava, no momento desta task, falhas em `test/models/meeting_section_test.dart` e `test/repositories/wol_repository_test.dart`, e `flutter analyze` acusava um erro em `lib/repositories/wol_repository.dart`. São arquivos das Tasks 02 e 06 da mesma spec, executadas em paralelo e ainda em andamento — **nenhum deles foi tocado por esta task**, cujo escopo se limitou à camada Utils.
