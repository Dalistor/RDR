# Status das Implementações

Histórico de todas as implementações realizadas neste projeto.

| # | Título | Data | Status | Arquivos Afetados |
|---|--------|------|--------|-------------------|
| 0001 | Repositório de exportação da imagem do relatório | 2026-07-30 | Concluído | `lib/repositories/image_export_repository.dart` |
| 0002 | Bootstrap do app e tema claro com as cores das seções | 2026-07-30 | Concluído | `lib/main.dart`, `lib/utils/app_theme.dart`, `test/widget_test.dart` (removido) |
| 0003 | Utilitários de formatação de tempo | 2026-07-30 | Concluído | `lib/utils/time_format.dart`, `test/utils/time_format_test.dart` |
| 0004 | Repositório HTTP do wol.jw.org | 2026-07-30 | Concluído | `lib/repositories/wol_repository.dart`, `test/repositories/wol_repository_test.dart` |
| 0005 | Models do domínio com serialização JSON | 2026-07-30 | Concluído | `lib/models/section_kind.dart`, `lib/models/timed_item.dart`, `lib/models/meeting_section.dart`, `lib/models/meeting_report.dart`, `lib/models/json_decoding.dart`, `test/models/timed_item_test.dart`, `test/models/meeting_section_test.dart`, `test/models/meeting_report_test.dart` |
| 0006 | Repositório de persistência do relatório | 2026-07-30 | Concluído | `lib/repositories/report_storage_repository.dart`, `test/repositories/report_storage_repository_test.dart` |
| 0007 | Montagem do relatório com itens fixos e sub-itens automáticos | 2026-07-30 | Concluído | `lib/services/report_builder.dart`, `test/services/report_builder_test.dart` |
| 0008 | Parser do HTML do wol.jw.org | 2026-07-30 | Concluído | `lib/services/schedule_parser.dart`, `test/services/schedule_parser_test.dart` |
| 0009 | Máquina de estados do cronômetro e edição de itens | 2026-07-30 | Concluído | `lib/services/meeting_timer_service.dart`, `test/services/meeting_timer_service_test.dart` |
| 0010 | Widgets de cabeçalho de seção e linha de item | 2026-07-30 | Concluído | `lib/widgets/section_header.dart`, `lib/widgets/item_row.dart` |
| 0011 | Providers Riverpod: estado do relatório, tick do cronômetro e estado da busca | 2026-07-30 | Concluído | `lib/providers/dependencies_provider.dart`, `lib/providers/meeting_provider.dart`, `lib/providers/tick_provider.dart` |
| 0012 | Teste de integração do fluxo completo da reunião | 2026-07-30 | Concluído | `test/integration/meeting_flow_test.dart` |
| 0013 | Tela principal com a lista da reunião | 2026-07-30 | Concluído | `lib/screens/meeting_screen.dart`, `lib/main.dart` |
| 0014 | Painel de controle do tempo no rodapé da reunião | 2026-07-30 | Concluído | `lib/widgets/control_panel.dart`, `lib/screens/meeting_screen.dart` |
| 0015 | Diálogos de edição, inclusão e remoção de itens | 2026-07-30 | Concluído | `lib/widgets/item_actions_menu.dart`, `lib/widgets/edit_item_dialog.dart`, `lib/widgets/add_item_dialog.dart`, `lib/widgets/remove_item_dialog.dart`, `lib/screens/meeting_screen.dart` |
| 0016 | Relatório para impressão e exportação em PNG | 2026-07-30 | Concluído | `lib/widgets/report_sheet.dart`, `lib/screens/meeting_screen.dart` |

---

_Atualizado automaticamente pelas skills `/centaur-driven-tdd` e `/centaur-driven-implement`_
