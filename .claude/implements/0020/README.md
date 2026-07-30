# [0020] Relatório congelado ao encerrar a reunião e "Reiniciar tudo" no menu do topo

**Data:** 2026-07-30
**Status:** Concluído
**Modo:** direto

## Solicitação
"Ao encerrar a reunião não dá para editar depois. Em um menu no canto superior, deverá ter um botão de reiniciar tudo."

## Contexto
Até aqui, encerrar a reunião só desligava o botão cíclico do cronômetro e o botão da reunião — a lista continuava editável (toque longo, renomear, adicionar, remover) e os horários de início e fim seguiam tocáveis. Depois do encerramento não há mais nada legítimo a mexer: o relatório é o documento final e cada toque acidental na tela — que é usada no escuro, com o celular na mão — corria o risco de estragar tempos já cronometrados.

Congelar o relatório, porém, deixaria o app sem saída para a semana seguinte: sem edição e sem reset, a reunião salva ficaria presa em disco para sempre. Daí o segundo pedido — um "Reiniciar tudo" fora do painel de controle, no menu da barra superior.

Decisões confirmadas com o usuário antes de implementar:
- ao encerrar, **trava tudo**: só sobram exportar o print e o menu do topo;
- "Reiniciar tudo" **apaga tudo** e devolve a tela ao estado "Nenhuma programação carregada";
- o item do menu fica **sempre habilitado** enquanto houver relatório, com confirmação.

## O que foi feito
1. **Trava pós-encerramento.** Com `report.endedAt != null`, a tela da reunião passa `onTap`/`onLongPress` nulos a cada `ItemRow` (sem seleção, sem menu de manutenção) e às duas linhas de horário, que perdem o lápis e viram só leitura. No painel, as setas de seleção e o `Zerar parte` passam a seguir a mesma flag `hasEnded` que já desabilitava o alvo central e o botão da reunião — agora o painel inteiro fica inerte.
2. **Menu do canto superior.** A `AppBar` ganhou um `PopupMenuButton` ao lado do botão de exportar, com a única entrada `Reiniciar tudo`. Ele aparece sempre que existe relatório e é desabilitado enquanto o PNG está sendo gerado.
3. **`resetAll` no notifier.** Nova operação de provider que zera o estado (`state = null`), volta a busca da programação para ocioso e apaga a chave do `shared_preferences` pelo `ReportStorageRepository.clear()` — que já existia e não tinha chamador.
4. **Diálogo de confirmação.** `showResetAllDialog` diz exatamente o que vai embora (lista, tempos e horários), avisa que não dá para desfazer e lembra de gerar o print antes.
5. **Texto do encerramento corrigido.** A confirmação de "Encerrar a reunião?" prometia que ainda daria para corrigir os tempos depois; agora avisa que o relatório fica congelado e pede para conferir antes.

## Arquivos modificados
- `lib/screens/meeting_screen.dart` — `PopupMenuButton` com `Reiniciar tudo` na `AppBar`, método `_reiniciarTudo`, flag `congelado` propagada para as linhas de item e para as duas linhas de horário; `_LinhaDeHorario.onTap` virou anulável e esconde o ícone de lápis quando nulo
- `lib/providers/meeting_provider.dart` — método `resetAll()` no `MeetingNotifier`
- `lib/widgets/control_panel.dart` — setas e `Zerar parte` desabilitados com `hasEnded`; texto da confirmação de encerramento reescrito; documentação da flag `hasEnded` atualizada
- `test/widgets/control_panel_test.dart` — o teste do estado encerrado passou a exigir o painel inteiro desabilitado, e um teste novo garante que em andamento os secundários seguem ativos
- `test/integration/meeting_flow_test.dart` — teste do `resetAll` limpando memória e disco

## Arquivos criados
- `lib/widgets/reset_all_dialog.dart` — `showResetAllDialog`, a confirmação da ação mais destrutiva do app

## Decisões técnicas
- **A trava mora na UI, não no service.** As operações do `MeetingTimerService` continuam puras e sem noção de "congelado"; a tela simplesmente deixa de oferecê-las. Colocar a regra no service exigiria espalhar guardas em quinze operações para o mesmo efeito, e tiraria do usuário a única correção legítima que resta: `resetAll`.
- **`resetAll` no notifier, não no service.** Não é operação de cronômetro — é descarte de estado e de disco, exatamente o que a camada de providers orquestra. Publica `null` antes de apagar o disco, pela mesma razão do `_replace`: a tela responde na hora e a escrita vem logo atrás.
- **Menu na `AppBar` em vez de um botão no painel.** O painel é tocado no escuro e às pressas; a ação que apaga a reunião inteira precisa ficar longe do polegar que aperta `Próximo`. O `PopupMenuButton` exige dois toques e ainda pede confirmação.
- **Item sempre habilitado.** Escolha do usuário: preferível ter a saída disponível a qualquer momento — protegida pelo diálogo — do que descobrir no meio da reunião que só dá para recomeçar encerrando antes.
- **Seleção também trava.** Com o relatório congelado, mover a seleção não serve para nada e o destaque só confundiria; `onTap` nulo já deixa a `ItemRow` puramente estática, sem área de toque, pelo comportamento que ela documenta.

## Como validar
1. `flutter run`, baixar a programação, iniciar a reunião e cronometrar algumas partes.
2. Tocar em `Encerrar reunião` e confirmar. Verificar que: o toque longo em qualquer item não abre mais o menu; tocar num item não muda a seleção; as linhas `Início da reunião` / `Fim da reunião` não abrem o diálogo e perderam o lápis; as setas, o `Zerar parte` e o botão da reunião estão apagados.
3. O botão de exportar continua funcionando e gera o PNG normalmente.
4. Abrir o menu de três pontos no canto superior direito → `Reiniciar tudo` → `Cancelar`: nada muda. Repetir e confirmar em `Reiniciar`: a tela volta para "Nenhuma programação carregada".
5. Fechar e reabrir o app: nada é restaurado, confirmando que o disco também foi limpo.

## Resultado da validação
- `flutter analyze` — `No issues found!`
- `flutter test` — 224 testes, todos passando (eram 223; um teste do painel foi reescrito e dois novos entraram: o painel travado/ativo e o `resetAll` limpando memória e disco)
