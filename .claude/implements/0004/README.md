# [0004] Repositório HTTP do wol.jw.org

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** TDD
**Spec:** `.claude/specs/0001/` — Task 06

## Solicitação

> Spec 0001 — Task 06: Implemente por TDD o repositório HTTP em `lib/repositories/wol_repository.dart`, com testes em `test/repositories/wol_repository_test.dart`. Ele faz **apenas HTTP** — nada de parsing, que é responsabilidade do service. Receba um `http.Client` por construtor para poder injetar o `MockClient` de `package:http/testing.dart` nos testes. Nenhum teste pode acessar a rede.
>
> A URL de entrada é `https://wol.jw.org/pt/wol/meetings/r5/lp-t/`, que redireciona para a semana corrente; caminhos relativos como `/pt/wol/d/r5/lp-t/202026244` devem ser resolvidos contra `https://wol.jw.org`.
>
> Toque apenas na camada Repositories; não modifique arquivos de outras camadas.

## Contexto

O app baixa a programação da semana do wol.jw.org em dois passos (página de semana → documento da apostila). A Task 03 fará o parsing; esta task entrega só o transporte: buscar HTML com o header certo, decodificar em UTF-8 e transformar qualquer falha de rede em erro tipado que a UI consiga mostrar. Como o app **exige internet** para baixar e não cacheia a programação, a mensagem de falta de conexão é parte do contrato com a UI.

## Critérios de aceite

- Buscar a página de semana devolve o corpo em texto e envia um header `User-Agent` de navegador móvel (não o padrão do Dart).
- O corpo é decodificado como UTF-8: acentos e o traço `–` chegam íntegros, sem mojibake.
- Buscar um caminho relativo monta a URL absoluta corretamente contra o host do wol.
- Resposta com status diferente de 200 lança `WolFetchException` trazendo o status; não devolve corpo vazio.
- Falha de rede (`SocketException`/`ClientException`) vira a mesma `WolFetchException`, com mensagem indicando falta de conexão.
- Um timeout razoável é aplicado à requisição e também resulta em `WolFetchException`.

## Ciclos TDD

| # | Caso de teste | Arquivo de teste | Código que passou a existir |
|---|---------------|------------------|------------------------------|
| 1 | busca a página da semana no wol e devolve o corpo em texto | `test/repositories/wol_repository_test.dart` | Classe `WolRepository` com `http.Client` injetável, constantes `baseUrl`/`currentWeekPath` e `fetchCurrentWeekPage()` |
| 2 | envia um User-Agent de navegador móvel em vez do padrão do Dart | idem | Constante `WolRepository.userAgent` (Chrome Mobile em Android) enviada como header |
| 3 | decodifica o corpo como UTF-8, preservando acentos e o traço – | idem | `utf8.decode(response.bodyBytes)` no lugar de `response.body` |
| 4 | byte inválido no meio do HTML não derruba a decodificação | idem | `allowMalformed: true` na decodificação |
| 5 | resolve o caminho relativo contra o host do wol | idem | `fetchDocument(path)` + extração do `_get(Uri)` compartilhado |
| 6 | não duplica o host quando já recebe uma URL absoluta | idem | Resolução por `Uri.parse(baseUrl).resolve(path)` |
| 7 | status diferente de 200 lança WolFetchException com o status (404 na semana, 500 no documento) | idem | Exceção `WolFetchException` com `message` + `statusCode` e a checagem de status em `_get` |
| 8 | SocketException / ClientException viram WolFetchException avisando da falta de conexão | idem | `catch` dos dois erros de transporte → `WolFetchException` com mensagem única de conectividade |
| 9 | requisição que passa do timeout vira WolFetchException; o timeout padrão é finito e razoável | idem | `Duration? timeout` no construtor, `defaultTimeout = 20s`, `.timeout(_timeout)` e `catch (TimeoutException)` |
| 10 | sem client injetado, cria o próprio http.Client sem tocar a rede (teste derivado da análise de cobertura) | idem | Nenhum — fechou a única linha descoberta (o fallback `client ?? http.Client()`) |

## O que foi feito

Criado o `WolRepository`, único ponto do app que fala com o wol.jw.org. Duas operações públicas — `fetchCurrentWeekPage()` e `fetchDocument(path)` — compartilham um `_get(Uri)` privado que aplica o `User-Agent` móvel, o timeout, a checagem de status e a decodificação UTF-8. Toda falha sai como `WolFetchException`, definida no mesmo arquivo, com mensagem em português pronta para a UI e `statusCode` preenchido só quando o servidor chegou a responder.

## Arquivos modificados

Nenhum.

## Arquivos criados

- `lib/repositories/wol_repository.dart` — repositório HTTP do wol.jw.org e a exceção de domínio `WolFetchException`.
- `test/repositories/wol_repository_test.dart` — 14 testes com `MockClient`, sem nenhum acesso à rede.

## Decisões técnicas

- **`http.Client` injetável por construtor, com fallback para um client real.** É o que permite o `MockClient` nos testes sem nenhuma chamada de rede, conforme a seção "Mocks" do `CLAUDE.md`.
- **Timeout injetável (`Duration? timeout`) com `defaultTimeout = 20s`.** Um teste de timeout com o valor de produção levaria 20 segundos; injetando 30 ms o comportamento é verificado em milissegundos. O valor padrão é coberto por um teste separado que garante que ele é finito e está numa faixa razoável (5 s a 30 s) — a alternativa (assertar o número exato) travaria o teste num detalhe de ajuste fino.
- **`utf8.decode(bodyBytes)` em vez de `response.body`.** O wol responde sem `charset` no `Content-Type` e o pacote `http` cai em latin-1 nesse caso — o teste do ciclo 3 reproduziu o mojibake (`ComentÃ¡rios`) antes da correção. `allowMalformed: true` evita que um único byte ruim derrube o download inteiro de uma reunião.
- **`Uri.resolve` em vez de concatenar strings.** Concatenação gerava `https://wol.jw.orghttps//wol...` quando o parser devolvesse um link já absoluto; `resolve` trata os dois formatos.
- **`WolFetchException` mora no próprio arquivo do repositório.** A task proíbe tocar outras camadas, e a exceção é parte do contrato desta camada.
- **Mensagem única de falta de conexão** para `SocketException` e `ClientException`: da perspectiva do usuário os dois casos são "sem internet", e a UI depende desse texto para orientar o download.
- **Sem `close()` e sem parsing.** Nenhum teste exigiu `close()` (o client vive junto com o app), e parsing é da Task 03 por decisão da Arquitetura de Camadas.
- **Deliberadamente sem teste:** o comportamento de redirecionamento 302 da URL de entrada, que é responsabilidade do próprio `http.Client` e só seria observável com rede real.

## Como validar

```bash
flutter test test/repositories/wol_repository_test.dart
flutter analyze lib/repositories/wol_repository.dart test/repositories/wol_repository_test.dart
```

## Resultado da validação

- `flutter test test/repositories/wol_repository_test.dart` → **14 testes, todos passando** (< 1 s, nenhum acesso à rede).
- `flutter test --coverage` → `lib/repositories/wol_repository.dart` com **LF:20 / LH:20 = 100% de linhas**.
- Cobertura de branch: o `lcov` do `flutter test` não emite registros `BRDA`, então os ramos foram conferidos um a um — `client ?? http.Client()` (ambos), `timeout ?? defaultTimeout` (ambos), `statusCode != 200` (ambos), o ternário de `toString()` com e sem status, e os três `catch` (`TimeoutException`, `SocketException`, `ClientException`) têm teste próprio.
- `flutter analyze` nos dois arquivos → **No issues found!**
