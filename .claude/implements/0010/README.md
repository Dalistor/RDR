# [0010] Widgets de cabeçalho de seção e linha de item

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto
**Spec:** `.claude/specs/0001/` — Task 11

## Solicitação

> Spec 0001 — Task 11: Implemente em `lib/widgets/` os dois componentes de apresentação do relatório: o cabeçalho de seção e a linha de item. Ambos são puros de apresentação — recebem tudo por parâmetro, não leem provider, não têm estado.
>
> O cabeçalho de seção mostra o ícone e o título na cor da seção, no estilo dos prints de referência: quadrado colorido com ícone à esquerda (losango para Tesouros, espiga para Faça Seu Melhor, ovelha para Nossa Vida Cristã — use ícones do Material que se aproximem) e o título em caixa alta e negrito na cor da seção, vindo de `app_theme.dart`.
>
> A linha de item mostra o label à esquerda e o tempo formatado à direita, com `formatDuration` da Task 01. Sub-item (`isSubItem == true`) é indentado e prefixado por `• `, com o label seguido de dois-pontos, igual aos prints. A linha aceita flags de `selecionado` e `correndo` para destaque visual, e callbacks opcionais de toque — quando os callbacks são nulos ela fica puramente estática, que é como o widget de print vai usá-la.
>
> Fundo branco, tema claro. Esta task é de UI, sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Widgets; não modifique arquivos de outras camadas.

## Contexto

A pasta `lib/widgets/` estava vazia. A tela principal (Task 12) e o print do relatório (Task 15) precisam desenhar exatamente a mesma lista — cabeçalhos coloridos das três seções e linhas de item com tempo à direita. Extrair esses dois componentes agora evita que a tela e o print divirjam visualmente, já que o print tem que sair idêntico ao que o usuário vê.

## O que foi feito

Criados os dois componentes de apresentação, ambos `StatelessWidget` sem leitura de provider:

- **`SectionHeader`** — quadrado colorido de 30x30 com cantos arredondados e ícone branco à esquerda, seguido do título em caixa alta, negrito, na cor da seção. A cor vem sempre de `AppTheme.sectionColor(kind)`; nenhum literal de cor foi repetido. O mapeamento de ícone é exposto como `SectionHeader.iconFor(SectionKind)`, para o print poder reusá-lo sem redesenhar o cabeçalho inteiro. O `padding` é parametrizável para o print ajustar o ritmo vertical.
- **`ItemRow`** — rótulo à esquerda em `Expanded` e tempo à direita via `formatDuration`. Sub-item sai indentado em 22dp, prefixado por `• ` e com dois-pontos no fim do rótulo, em fonte um pouco menor e cinza. Aceita `isSelected`, `isRunning`, `accentColor`, `onTap` e `onLongPress`.

## Arquivos criados

- `lib/widgets/section_header.dart` — cabeçalho de seção com ícone e título na cor da seção
- `lib/widgets/item_row.dart` — linha de item com rótulo, tempo formatado e destaques de seleção/execução

## Decisões técnicas

- **Nomes das flags em inglês (`isSelected` / `isRunning`)** em vez de `selecionado` / `correndo`. A instrução da task descreve a semântica em português, mas o contrato de models da spec e todo o código de produção usam inglês nos membros públicos (`isSubItem`, `runningItemId`, `selectedItemId`). Manter o padrão evita uma API bilíngue justamente na fronteira que as Tasks 12, 13, 14 e 15 vão consumir. Os textos de interface continuam em português, como manda o `CLAUDE.md`.
- **Destaques de "selecionado" e "correndo" ortogonais e acumuláveis.** O `CLAUDE.md` insiste que item que corre e item selecionado são conceitos distintos, e a Task 12 exige que o usuário enxergue os dois ao mesmo tempo. Por isso o item que corre recebe **fundo tingido** (accent com 10% de alfa) mais negrito e tempo colorido, enquanto o selecionado recebe **barra lateral esquerda** de 4dp. Sendo canais visuais diferentes, os dois se sobrepõem sem se anular.
- **`accentColor` opcional** em vez de fixar a cor de destaque. A tela pode tingir a linha com a cor da seção a que o item pertence; sem parâmetro, cai na cor primária do tema. Mantém o widget ignorante de `SectionKind` — a linha não sabe (nem precisa saber) em que seção está.
- **Sem `InkWell` quando os dois callbacks são nulos.** A instrução pede que a linha fique "puramente estática" nesse caso; o print é renderizado fora da tela por `captureFromLongWidget` e não deve carregar `Material`/`InkWell` inúteis. A altura mínima de 48dp (alvo de toque) também só é aplicada no modo interativo, para o print não ganhar linhas espaçadas demais.
- **`FontFeature.tabularFigures()` no tempo.** Sem largura tabular, os dígitos dançam de linha para linha e a coluna `MM:SS` do print fica desalinhada.
- **Ícones do Material aproximados:** `Icons.diamond_outlined` (losango) para Tesouros, `Icons.grass` (espiga) para Faça Seu Melhor e `Icons.pets` (ovelha) para Nossa Vida Cristã — o Material não tem ovelha, e `pets` é o mais próximo de um animal.
- **`title.toUpperCase()` no cabeçalho** mesmo com o model já guardando o título em caixa alta, para a apresentação não depender de como o parser normalizou o texto.

## Como validar

Ainda não há tela que monte esses widgets (chega na Task 12). Para conferir visualmente antes disso, basta instanciar num `Scaffold`:

```dart
Column(children: [
  SectionHeader(kind: SectionKind.treasures, title: 'Tesouros da Palavra de Deus'),
  ItemRow(label: '1. Ele pregou com coragem', elapsed: Duration(minutes: 4, seconds: 12), isRunning: true),
  ItemRow(label: 'Presidente', elapsed: Duration(seconds: 11), isSubItem: true),
  ItemRow(label: '2. Joias espirituais', elapsed: Duration(minutes: 10), isSelected: true, onTap: () {}),
])
```

Esperado: cabeçalho teal com losango; primeira linha com fundo teal claro e texto em negrito; segunda linha indentada como `• Presidente:` com `00:11` à direita; terceira com barra lateral e resposta ao toque.

## Resultado da validação

- `flutter analyze` → **No issues found!**
- `flutter test` → **173 testes, todos passando** (nenhum teste novo; task de UI sem testes por decisão da spec). Rodado apenas para confirmar ausência de regressão — nenhum arquivo fora de `lib/widgets/` foi tocado.
- Revisão de camadas: os dois widgets ficam em `lib/widgets/` e importam apenas `lib/models/section_kind.dart` e `lib/utils/` (`app_theme.dart`, `time_format.dart`), respeitando a direção `widgets → utils/models`. Nenhuma regra de negócio, nenhum acesso a dados, nenhuma leitura de provider.
