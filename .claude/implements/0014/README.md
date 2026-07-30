# [0014] Painel de controle do tempo no rodapé da reunião

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto
**Spec:** `.claude/specs/0001/` — Task 13

## Solicitação

> Spec 0001 — Task 13: Implemente `lib/widgets/control_panel.dart` e encaixe-o no rodapé fixo de `lib/screens/meeting_screen.dart`. Ele chama as operações do notifier da Task 09.
>
> Botões: **Iniciar/Pausar** (alterna conforme houver item correndo), **Próximo**, **seta para cima**, **seta para baixo**, **Resetar** e **Encerrar reunião**. Iniciar/Pausar e Próximo são os alvos grandes e centrais; as setas ficam laterais. Resetar e Encerrar são destrutivos e ficam **visualmente afastados** do Próximo, para não serem tocados por engano no escuro — leia a seção "Restrições e Cuidados" do `CLAUDE.md`.
>
> Resetar e Encerrar abrem diálogo de confirmação antes de agir; os demais agem direto. Após encerrar, Iniciar, Próximo e Pausar ficam desabilitados. Alvos de toque com no mínimo 48dp.
>
> Sem testes; garanta que `flutter analyze` passa limpo.
>
> Toque apenas na camada Widgets e no encaixe do painel em `meeting_screen.dart`; não modifique arquivos de outras camadas.

## Contexto

A Task 12 deixou no rodapé da `MeetingScreen` um `_ControlPanelSlot` vazio, de altura fixa, só reservando o espaço. Sem o painel, o `MeetingNotifier` já expunha todas as operações do cronômetro (Task 09) mas não havia como acioná-las: a reunião não podia ser cronometrada. Esta task fecha esse buraco.

O painel é o ponto de contato físico do app durante a reunião — é tocado dezenas de vezes, no escuro, com o celular na mão. A seção "Restrições e Cuidados" do `CLAUDE.md` é explícita: alvos grandes e `Resetar` longe do `Próximo`.

## O que foi feito

Criado o `ControlPanel`, um `ConsumerWidget` que recebe `isRunning` e `hasEnded` da tela e despacha cada ação para o `MeetingNotifier`. Duas fileiras:

1. **Fileira de operação** (72dp de altura): seta ↑ lateral esquerda, **Iniciar/Pausar** e **Próximo** como dois alvos grandes ocupando todo o centro, seta ↓ lateral direita.
2. **Fileira destrutiva** (48dp), separada da primeira por um vão de 14dp mais um divisor: **Resetar** encostado no canto esquerdo e **Encerrar reunião** no canto direito, ambos em estilo discreto (contorno vinho, sem preenchimento).

Comportamento:

- **Iniciar/Pausar** alterna pelo `isRunning`: rótulo, ícone (`play_arrow`/`pause`) e cor (teal/dourado) mudam juntos, para o estado ser legível de relance.
- **Próximo** chama `notifier.next()` direto.
- **Setas** chamam `selectPrevious`/`selectNext` — mexem só na seleção, e continuam habilitadas mesmo após o encerramento, para conferir os tempos.
- **Resetar** e **Encerrar** abrem `AlertDialog` de confirmação (Cancelar / ação em vinho) e só agem se confirmados.
- Com `hasEnded == true`, Iniciar/Pausar, Próximo e Encerrar ficam desabilitados; Resetar continua ativo, que é a única saída de volta.

Na `meeting_screen.dart`, o `_ControlPanelSlot` foi removido e substituído pelo `ControlPanel` real, no mesmo lugar: fora da área rolável, no rodapé fixo, e só quando existe relatório carregado.

## Arquivos modificados

- `lib/screens/meeting_screen.dart` — removida a classe `_ControlPanelSlot` (placeholder da Task 12) e encaixado o `ControlPanel` no rodapé, recebendo `isRunning` e `hasEnded` derivados do relatório observado.

## Arquivos criados

- `lib/widgets/control_panel.dart` — o painel de controle e seus três tipos de botão internos (`_BotaoPrincipal`, `_BotaoDeSeta`, `_BotaoDestrutivo`), mais os diálogos de confirmação.

## Decisões técnicas

- **`ConsumerWidget` com `isRunning`/`hasEnded` por parâmetro** em vez de o painel observar o `meetingProvider` inteiro: a tela já observa o relatório e redesenha a cada tique de 1 segundo; se o painel também observasse, reconstruiria os botões a cada segundo sem necessidade. O acesso ao notifier é por `ref.watch(meetingProvider.notifier)`, que não muda quando o estado muda.
- **Separação dos destrutivos por geometria, não só por confirmação.** O `Próximo` é o botão mais apertado da noite e fica no centro-direita da fileira de cima; `Resetar` foi para o canto inferior esquerdo, a maior distância diagonal possível dentro do painel, exatamente como o `CLAUDE.md` pede. Entre as duas fileiras há um vão morto de 14dp e um divisor, e os destrutivos usam contorno discreto contra os dois botões preenchidos de cima — a diferença de peso visual é parte da proteção.
- **`Encerrar` também desabilitado após o encerramento**, embora a task só liste Iniciar, Pausar e Próximo: um segundo `endMeeting` é no-op no service, e deixar um botão destrutivo aceso sem efeito é pior do que apagá-lo. `Resetar` continua ativo de propósito — é o caminho de volta.
- **Notifier capturado antes do `await` do diálogo.** Os handlers pegam a referência do notifier no `build` e só usam `context` antes de suspender; depois do `showDialog` não se toca em `context` nem em `ref`. Evita `use_build_context_synchronously` sem precisar de guardas de `mounted`.
- **Cores vindas do `AppTheme`.** Iniciar usa `treasuresColor`, Pausar usa `ministryColor` e os destrutivos usam `christianLifeColor` — nenhum literal de cor de seção foi repetido, conforme a convenção. O `Próximo` usa um grafite neutro (`0xFF1F2933`) para não competir com o teal do Iniciar.
- **Alvos de toque.** Os dois centrais têm 72dp de altura; as setas, 52×72dp; os destrutivos, 48dp de altura mínima. Todos acima do piso de 48dp.
- **Larguras flexíveis** (`Expanded` nos centrais, `Flexible` + `ellipsis` nos rótulos) para o painel não estourar em telas estreitas.

## Como validar

1. `flutter run` no dispositivo, com uma programação baixada ou montada na mão.
2. **Iniciar** → o primeiro item passa a correr e o botão vira **Pausar** em dourado; o topo da lista mostra `Início da reunião: HH:MM`.
3. **Próximo** → o item corrente para, o seguinte arranca e a seleção acompanha.
4. **Setas ↑/↓** → a seleção anda e a lista rola até ela, mas o item que corre continua contando.
5. **Resetar** → abre o diálogo; em "Cancelar" nada muda, em "Resetar" todos os tempos zeram e a estrutura permanece.
6. **Encerrar reunião** → abre o diálogo; confirmado, grava `Fim da reunião: HH:MM` no fim da lista e desabilita Iniciar, Próximo e Encerrar. Um **Resetar** depois disso devolve o painel ao estado inicial.

## Resultado da validação

- `flutter analyze` — **No issues found!**
- `flutter test` — **190 testes, todos passando** (nenhum teste novo: task de UI, sem testes por decisão da spec).
- Revisão de camadas: o painel vive em `lib/widgets/`, importa apenas `providers/` e `utils/` e não contém nenhuma regra de tempo — toda operação é delegada ao `MeetingNotifier`, que delega ao `MeetingTimerService`. Nenhum arquivo fora de Widgets e do encaixe em `meeting_screen.dart` foi tocado.
