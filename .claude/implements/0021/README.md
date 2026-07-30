# [0021] Permissão de internet no APK de release e busca que não trava em "carregando"

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto

## Solicitação
"Não está dando para fazer o scraping após o reset geral, pode corrigir?"

## Contexto
Depois do `Reiniciar tudo` (implementação 0020), tocar em `Baixar programação` caía na tela de erro, e continuava caindo mesmo fechando e reabrindo o app.

O reset não é o culpado: reproduzir o caminho inteiro — baixar → cronometrar → encerrar → reiniciar tudo → baixar de novo — num teste de widget com `MockClient` passa sem erro, e o mesmo vale para o `MeetingNotifier` isolado. O site também está no ar: `GET https://wol.jw.org/pt/wol/meetings/r5/lp-t/` responde 200 depois de dois redirecionamentos, na semana `2026/31`, com o link da Apostila Vida e Ministério na página.

A causa é o `AndroidManifest.xml`: **`android.permission.INTERNET` só existia nos manifestos de `debug` e `profile`**, que o próprio Flutter cria para a ferramenta conversar com o app. O de `main` — o único que vale no `flutter build apk --release` — não declarava nada. Ou seja: o APK de release nunca teve rede.

Isso passou despercebido porque o relatório baixado num `flutter run` fica salvo no `shared_preferences` do mesmo pacote: o release restaurava a reunião do disco e nunca precisava da rede. O `Reiniciar tudo` apagou esse relatório e escancarou o problema.

## O que foi feito
1. **`<uses-permission android:name="android.permission.INTERNET"/>`** no `android/app/src/main/AndroidManifest.xml`, com um comentário explicando por que a falta dela só aparece no release.
2. **Rede de segurança no `downloadSchedule`.** Só `WolFetchException` e `ScheduleParseException` eram tratadas; qualquer outra exceção escapava e deixava o `ScheduleFetchState` parado em `loading` — a tela ficaria girando o "Baixando a programação…" para sempre, sem nem o botão de tentar de novo. Agora um `on Object` final registra o erro com `debugPrint` e transforma qualquer falha inesperada em mensagem na tela.

## Arquivos modificados
- `android/app/src/main/AndroidManifest.xml` — permissão de internet
- `lib/providers/meeting_provider.dart` — catch-all no `downloadSchedule`
- `CLAUDE.md` — a seção de Restrições dizia que o app "não precisa de permissão de internet além da padrão do Android", o que é falso e foi o que produziu o bug

## Decisões técnicas
- **Permissão no `main`, não nos outros manifestos.** É o único que entra no release; `debug` e `profile` já a têm e não devem ser tocados — são gerados pela ferramenta.
- **Catch-all em vez de tratar cada exceção nova.** Uma reunião ao vivo não pode ficar presa num indicador de progresso por causa de uma `PlatformException` que ninguém previu. A mensagem é genérica de propósito: o texto exato vai para o log, não para o irmão que está com o celular na mão.
- **Nenhum teste novo.** Manifesto do Android não é alcançável por `flutter test`, e é justamente por isso que o bug sobreviveu; o registro fica no `CLAUDE.md`. O catch-all foi validado pela build de release.

## Como validar
1. `flutter build apk --release` e conferir a permissão no manifesto empacotado:
   `grep -c 'android.permission.INTERNET' build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml` → `1`.
2. Instalar o APK novo no celular, tocar em `Reiniciar tudo` e depois em `Baixar programação`: a lista da semana tem que aparecer.
3. Desligar os dados do celular e tentar baixar: agora sim a mensagem de erro é verdadeira, com o botão `Tentar de novo`.

## Resultado da validação
- `flutter analyze` — `No issues found!`
- `flutter test` — 224 testes, todos passando
- `flutter build apk --release` — `✓ Built build/app/outputs/flutter-apk/app-release.apk (53.2MB)`, e o manifesto empacotado traz `android.permission.INTERNET`
- Rede conferida fora do app: a página da semana responde 200 em `.../meetings/r5/lp-t/2026/31` e contém o link da Apostila Vida e Ministério
