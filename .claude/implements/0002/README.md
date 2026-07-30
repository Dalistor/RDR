# [0002] Bootstrap do app e tema claro com as cores das seções

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto
**Spec:** `.claude/specs/0001/` — Task 10

## Solicitação

> Spec 0001 — Task 10: Substitua o contador padrão do Flutter em `lib/main.dart` pelo bootstrap real do RDR: `runApp` com `ProviderScope` envolvendo um `MaterialApp` de título "RDR", `debugShowCheckedModeBanner: false`, locale `pt_BR`, e um tema **claro apenas** (sem `darkTheme`, `themeMode: ThemeMode.light`) definido em `lib/utils/app_theme.dart`.
>
> O tema centraliza as três cores de seção usadas em todo o app, iguais às do wol.jw.org: Tesouros teal (`#26697C`), Faça Seu Melhor dourado (`#9B6E1A`), Nossa Vida Cristã vinho (`#A33B2A`). Exponha-as como constantes nomeadas, mais uma função que mapeia `SectionKind` para a cor, para que os widgets não repitam literais de cor.
>
> A `home` deve ser um placeholder mínimo (um `Scaffold` vazio com o título) — a tela real chega na Task 12. Remova também o teste padrão `test/widget_test.dart`, que testa o contador e vai quebrar. Esta task é estrutural, sem testes próprios; garanta que `flutter analyze` passa limpo.
>
> Toque apenas em `lib/main.dart`, `lib/utils/app_theme.dart` e na remoção de `test/widget_test.dart`; não modifique arquivos de outras camadas.

## Contexto

O projeto ainda estava com o scaffold do `flutter create` (contador de cliques e tema roxo padrão). Nada do app real podia rodar: faltava o `ProviderScope` no topo da árvore (todas as tasks de UI dependem dos providers Riverpod) e faltava um lugar único para as cores das três seções, que aparecem no cabeçalho de seção (Task 11), na tela principal (Task 12) e no print do relatório (Task 15).

## O que foi feito

- `lib/main.dart` reescrito: `main()` fixa o locale do `intl` em `pt_BR`, carrega os dados de data desse locale e chama `runApp(const ProviderScope(child: RdrApp()))`. `RdrApp` monta um `MaterialApp` com título "RDR", `debugShowCheckedModeBanner: false`, `locale: Locale('pt', 'BR')`, `theme: AppTheme.light`, `themeMode: ThemeMode.light` e **sem** `darkTheme`. A `home` é um `_HomePlaceholder` privado — `Scaffold` com `AppBar` "RDR" e corpo vazio — que a Task 12 substitui pela `MeetingScreen`.
- `lib/utils/app_theme.dart` criado: classe `AppTheme` (`abstract final`) com as três cores como `static const`, o mapeamento `SectionKind → Color` e o `ThemeData` claro do app.
- `test/widget_test.dart` removido (testava o contador do scaffold).

## Arquivos modificados

- `lib/main.dart` — contador padrão substituído pelo bootstrap real (ProviderScope + MaterialApp + placeholder).

## Arquivos criados

- `lib/utils/app_theme.dart` — cores das seções, mapeamento por `SectionKind` e tema claro único.

## Arquivos removidos

- `test/widget_test.dart` — teste padrão do contador do `flutter create`.

## Decisões técnicas

- **Cores como `static const` dentro de `AppTheme`**, não como constantes soltas de topo de arquivo: mantém um único ponto de importação (`AppTheme.treasuresColor`, `AppTheme.sectionColor(kind)`) e deixa claro na chamada de onde a cor vem. `AppTheme` é `abstract final class` — só existe para agrupar, nunca é instanciada.
- **`sectionColor` usa `switch` expression sem `default`**: se um dia entrar um quarto `SectionKind`, o analisador aponta o mapeamento incompleto em vez de devolver uma cor errada em silêncio.
- **`ColorScheme.fromSeed` com semente teal + `surface`/`scaffoldBackgroundColor` brancos**: o requisito do `CLAUDE.md` é fundo branco na interface e no print, então a superfície é forçada para branco em vez de ficar com o tom levemente tingido que o Material 3 gera a partir da semente.
- **Não foi adicionado `flutter_localizations`.** Ele seria o caminho normal para localizar os textos do Material em pt_BR, mas a versão do SDK **fixa `intl` em 0.20.2** e o `pubspec.yaml` do projeto declara `intl: ^0.20.3` — a resolução falha (`flutter pub add flutter_localizations --sdk=flutter --dry-run` confirma). Baixar a restrição do `intl` está fora do escopo desta task. Consequência prática: o `locale` declarado é `pt_BR`, mas como `supportedLocales` continua no padrão (`en_US`), a resolução do `WidgetsApp` cai em `en_US` para as *strings do Material* (rótulos de diálogo etc). Isso é intencional: forçar `supportedLocales: [pt_BR]` sem os delegates faria os diálogos das Tasks 13/14 estourarem com "No MaterialLocalizations found". Todos os textos escritos pelo app já são português literal, então o efeito visível é nulo hoje. Se no futuro os rótulos nativos precisarem sair em português, o caminho é alinhar a versão do `intl` e então adicionar `flutter_localizations` + `supportedLocales`.
- **`Intl.defaultLocale = 'pt_BR'` e `initializeDateFormatting('pt_BR')` no `main()`**: é o que efetivamente faz o `pt_BR` valer para formatação de datas do pacote `intl`. Sem o `initializeDateFormatting`, qualquer `DateFormat(..., 'pt_BR')` de uma task futura lançaria `LocaleDataException` em tempo de execução.
- **`home` como widget privado `_HomePlaceholder`**: sinaliza que é descartável e evita que outra camada passe a depender dele antes da Task 12.

## Como validar

```bash
flutter analyze          # deve passar limpo em lib/main.dart e lib/utils/app_theme.dart
flutter run              # o app sobe com AppBar teal "RDR", fundo branco, sem banner de debug
```

Visualmente: barra superior teal `#26697C`, corpo branco, nenhuma faixa "DEBUG" no canto, e o contador do Flutter não existe mais.

## Resultado da validação

- `flutter analyze`: **nenhum problema** em `lib/main.dart` nem em `lib/utils/app_theme.dart`. A única mensagem da rodada (`unused_import` em `test/models/meeting_section_test.dart`) pertence à Task 02, que rodava em paralelo, e está fora do escopo desta task.
- Sem testes próprios: task estrutural, conforme definido na spec. `test/widget_test.dart` foi removido justamente porque quebraria.
- Camadas: `lib/utils/app_theme.dart` importa apenas `material.dart` e `models/section_kind.dart` — respeita a regra de dependência (`utils` não conhece providers, services nem repositories). `lib/main.dart` é bootstrap e não contém regra de negócio.
