# [0001] Repositório de exportação da imagem do relatório

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto
**Spec:** `.claude/specs/0001/` — Task 08

## Solicitação

> Spec 0001 — Task 08: Implemente em `lib/repositories/image_export_repository.dart` a exportação da imagem do relatório. A classe recebe os bytes PNG já renderizados (`Uint8List`) e faz duas coisas: grava o arquivo em disco via `path_provider` num nome com a data (ex.: `relatorio-reuniao-2026-07-30.png`), salva na galeria via `gal` (pedindo permissão antes com a API do próprio `gal` e devolvendo um erro claro se for negada) e abre o menu de compartilhamento via `share_plus` apontando para esse arquivo.
>
> Erros de plugin devem virar uma exceção de domínio própria (ex.: `ImageExportException`) com mensagem em português, para a UI conseguir mostrar um `SnackBar` útil. Esta task é estrutural e ligada a plugins de plataforma, portanto não exige testes unitários; garanta apenas que `flutter analyze` passa limpo.
>
> Toque apenas na camada Repositories; não modifique arquivos de outras camadas.

## Contexto

A Task 15 da spec vai capturar o relatório inteiro como PNG único com `screenshot`
(`captureFromLongWidget`) e precisa de um ponto de saída pronto para receber esses
bytes. A conversa com os plugins de plataforma (`path_provider`, `gal`, `share_plus`)
fica isolada aqui, na camada Repositories, para que a UI só precise tratar um tipo
de erro com mensagem já em português.

## O que foi feito

Criada a classe `ImageExportRepository` com um único ponto de entrada,
`exportReportImage(Uint8List pngBytes)`, que executa três passos em sequência e
devolve o caminho do arquivo gravado:

1. **Disco** — `getTemporaryDirectory()` do `path_provider` e gravação com
   `writeAsBytes(..., flush: true)` num nome com a data
   (`relatorio-reuniao-2026-07-30.png`).
2. **Galeria** — `Gal.hasAccess(toAlbum: true)` e, se necessário,
   `Gal.requestAccess(toAlbum: true)`; com permissão, `Gal.putImage(path, album: 'RDR')`.
3. **Compartilhamento** — `SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: 'image/png')], subject: 'Relatório da reunião'))`.

Junto vem a exceção de domínio `ImageExportException`, com `message` em português
(exibível direto num `SnackBar`) e `cause` guardando o erro original do plugin.

## Arquivos modificados

Nenhum.

## Arquivos criados

- `lib/repositories/image_export_repository.dart` — `ImageExportRepository` (gravação em disco, galeria e compartilhamento) e `ImageExportException`.

## Decisões técnicas

- **APIs verificadas no pub cache, não de memória.** `share_plus` 13.3.0 depreciou
  `Share.shareXFiles`; a forma atual é `SharePlus.instance.share(ShareParams(...))`.
  `gal` 2.3.3 expõe `hasAccess`/`requestAccess`/`putImage` estáticos e lança
  `GalException` com um `GalExceptionType` tipado.
- **`getTemporaryDirectory()` em vez de documentos.** O arquivo é descartável: a
  cópia definitiva vai para a galeria. O plugin Android do `share_plus` copia
  qualquer arquivo para `cacheDir/share_plus` antes de compartilhar, então o
  `FileProvider` funciona a partir do diretório temporário sem configuração extra.
- **Permissão pedida antes de gravar na galeria**, com a API do próprio `gal`, e
  não com um pacote de permissões à parte — em Android 13+ o `hasAccess` já devolve
  `true` sem diálogo. `toAlbum: true` porque as imagens vão para o álbum `RDR`.
- **`GalExceptionType` mapeado uma a uma** para mensagens distintas em português
  (negada / sem espaço / formato / inesperado), em vez de uma mensagem genérica: a
  ação corretiva do usuário é diferente em cada caso.
- **Falha no compartilhamento tem mensagem própria** ("a imagem foi salva na
  galeria, mas..."), já que nesse ponto o trabalho já não se perdeu.
- **Relógio injetável** (`DateTime Function()? now` no construtor, com
  `DateTime.now` como padrão) para o nome do arquivo ser determinístico se um dia
  for testado. Não se usou o `typedef Clock` da Task 05 porque ele mora em
  `services/`, e a regra de dependência do `CLAUDE.md` proíbe repositório importar
  service.
- **`buildFileName` estático e público**, com `padLeft` manual em vez de
  `DateFormat` do `intl`: é nome de arquivo, formato fixo, sem locale envolvido.
- **Guarda para bytes vazios** antes de tocar em qualquer plugin, evitando salvar
  um PNG inválido na galeria.

## Como validar

1. `flutter analyze` — deve passar limpo.
2. Depois da Task 15, no aparelho real: gerar o print, conferir o arquivo
   `relatorio-reuniao-AAAA-MM-DD.png` no álbum **RDR** da galeria e o menu de
   compartilhamento abrindo com a imagem anexada.
3. Negar a permissão de fotos e repetir: deve aparecer o `SnackBar` com a mensagem
   de permissão negada, sem crash.
4. Testar em Android < 13 e ≥ 13 — o comportamento de permissão do `gal` difere
   entre as versões (ver "Restrições e Cuidados" do `CLAUDE.md`).

## Resultado da validação

- `flutter analyze` → **No issues found!** (5.0s)
- Sem testes unitários, conforme a task determina (código totalmente acoplado a
  plugins de plataforma; `path_provider`, `gal` e `share_plus` só respondem num
  dispositivo real).
- Revisão de camadas: só `lib/repositories/` foi tocado. O repositório não importa
  services, providers nem `material.dart`, e não contém regra de negócio — apenas
  I/O e tradução de erro.
