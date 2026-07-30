import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:rdr/models/meeting_section.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/services/report_builder.dart';

const _semana = '27 de julho–2 de agosto';

/// Programação da semana de exemplo, igual à das fixtures do projeto.
List<ParsedSection> _programacaoDeExemplo() => const [
  ParsedSection(
    kind: SectionKind.treasures,
    title: 'TESOUROS DA PALAVRA DE DEUS',
    partTitles: [
      '1. Ele pregou com coragem',
      '2. Joias espirituais',
      '3. Leitura da Bíblia',
    ],
  ),
  ParsedSection(
    kind: SectionKind.ministry,
    title: 'FAÇA SEU MELHOR NO MINISTÉRIO',
    partTitles: [
      '4. Iniciando conversas',
      '5. Cultivando o interesse',
      '6. Explicando suas crenças',
    ],
  ),
  ParsedSection(
    kind: SectionKind.christianLife,
    title: 'NOSSA VIDA CRISTÃ',
    partTitles: [
      '7. Seja adaptável — mostre interesse pessoal',
      '8. Estudo bíblico de congregação',
    ],
  ),
];

MeetingReport _relatorioDeExemplo() => const ReportBuilder().build(
  weekLabel: _semana,
  sections: _programacaoDeExemplo(),
);

/// A seção de [kind] dentro do relatório montado.
MeetingSection _secao(MeetingReport relatorio, SectionKind kind) =>
    relatorio.sections.firstWhere((secao) => secao.kind == kind);

/// Rótulos dos itens de [kind], sub-itens inclusive, na ordem.
List<String> _rotulos(MeetingReport relatorio, SectionKind kind) => [
  for (final item in _secao(relatorio, kind).items) item.label,
];

/// Rótulos apenas das linhas que não são sub-item.
List<String> _partes(MeetingReport relatorio, SectionKind kind) => [
  for (final item in _secao(relatorio, kind).items)
    if (!item.isSubItem) item.label,
];

/// Rótulos dos sub-itens que seguem imediatamente a parte [parte].
List<String> _subItensDe(
  MeetingReport relatorio,
  SectionKind kind,
  String parte,
) {
  final itens = _secao(relatorio, kind).items;
  final indiceDaParte = itens.indexWhere((item) => item.label == parte);
  final subItens = <String>[];
  for (var i = indiceDaParte + 1; i < itens.length; i++) {
    if (!itens[i].isSubItem) break;
    subItens.add(itens[i].label);
  }
  return subItens;
}

void main() {
  group('itens fixos', () {
    test('abre com "Comentários iniciais" e fecha com "Comentários finais", '
        'fora das seções', () {
      final relatorio = _relatorioDeExemplo();

      expect(relatorio.openingComments.label, 'Comentários iniciais');
      expect(relatorio.openingComments.isSubItem, isFalse);
      expect(relatorio.closingComments.label, 'Comentários finais');
      expect(relatorio.closingComments.isSubItem, isFalse);
      expect(relatorio.orderedItems.first, relatorio.openingComments);
      expect(relatorio.orderedItems.last, relatorio.closingComments);
      final rotulosDasSecoes = [
        for (final secao in relatorio.sections)
          for (final item in secao.items) item.label,
      ];
      expect(rotulosDasSecoes, isNot(contains('Comentários iniciais')));
      expect(rotulosDasSecoes, isNot(contains('Comentários finais')));
    });
  });

  group('estado inicial', () {
    test('nasce com o rótulo da semana recebido e sem estado de cronômetro',
        () {
      final relatorio = _relatorioDeExemplo();

      expect(relatorio.weekLabel, _semana);
      expect(relatorio.startedAt, isNull);
      expect(relatorio.endedAt, isNull);
      expect(relatorio.runningItemId, isNull);
      expect(relatorio.selectedItemId, isNull);
    });
  });

  group('seções', () {
    test('preserva as seções recebidas na ordem, com tipo e título', () {
      final relatorio = _relatorioDeExemplo();

      expect(
        relatorio.sections.map((secao) => secao.kind),
        [SectionKind.treasures, SectionKind.ministry, SectionKind.christianLife],
      );
      expect(relatorio.sections.map((secao) => secao.title), [
        'TESOUROS DA PALAVRA DE DEUS',
        'FAÇA SEU MELHOR NO MINISTÉRIO',
        'NOSSA VIDA CRISTÃ',
      ]);
    });

    test('cada parte vira um item da sua seção, na ordem e sem ser sub-item',
        () {
      final relatorio = _relatorioDeExemplo();

      expect(_partes(relatorio, SectionKind.treasures), [
        '1. Ele pregou com coragem',
        '2. Joias espirituais',
        '3. Leitura da Bíblia',
      ]);
      expect(_partes(relatorio, SectionKind.ministry), [
        '4. Iniciando conversas',
        '5. Cultivando o interesse',
        '6. Explicando suas crenças',
      ]);
    });
  });

  group('sub-itens de Tesouros da Palavra de Deus', () {
    test('cada parte comum ganha um sub-item "Presidente"', () {
      final relatorio = _relatorioDeExemplo();

      expect(
        _subItensDe(relatorio, SectionKind.treasures, '1. Ele pregou com coragem'),
        ['Presidente'],
      );
      expect(
        _subItensDe(relatorio, SectionKind.treasures, '2. Joias espirituais'),
        ['Presidente'],
      );
    });

    test('a parte de Leitura da Bíblia ganha "Conselho" e "Transição", nessa '
        'ordem, e não ganha "Presidente"', () {
      final relatorio = _relatorioDeExemplo();

      expect(
        _subItensDe(relatorio, SectionKind.treasures, '3. Leitura da Bíblia'),
        ['Conselho', 'Transição'],
      );
    });
  });

  group('sub-itens de Faça Seu Melhor no Ministério', () {
    test('toda parte ganha "Conselho" e "Transição", nessa ordem', () {
      final relatorio = _relatorioDeExemplo();

      expect(_rotulos(relatorio, SectionKind.ministry), [
        '4. Iniciando conversas',
        'Conselho',
        'Transição',
        '5. Cultivando o interesse',
        'Conselho',
        'Transição',
        '6. Explicando suas crenças',
        'Conselho',
        'Transição',
      ]);
    });
  });

  group('sub-itens de Nossa Vida Cristã', () {
    test('a seção abre com um "Presidente" avulso, que não é sub-item, antes '
        'da primeira parte', () {
      final relatorio = _relatorioDeExemplo();

      final primeiro = _secao(relatorio, SectionKind.christianLife).items.first;
      expect(primeiro.label, 'Presidente');
      expect(primeiro.isSubItem, isFalse);
      expect(_partes(relatorio, SectionKind.christianLife), [
        'Presidente',
        '7. Seja adaptável — mostre interesse pessoal',
        '8. Estudo bíblico de congregação',
      ]);
    });

    test('cada parte ganha um sub-item "Presidente", menos a última parte da '
        'seção, que fica sem nenhum', () {
      final relatorio = _relatorioDeExemplo();

      expect(_rotulos(relatorio, SectionKind.christianLife), [
        'Presidente',
        '7. Seja adaptável — mostre interesse pessoal',
        'Presidente',
        '8. Estudo bíblico de congregação',
      ]);
    });
  });

  group('marcação de sub-item', () {
    test('só os sub-itens automáticos são marcados; partes e itens fixos não',
        () {
      final relatorio = _relatorioDeExemplo();

      // _subItensDe só coleta itens com isSubItem verdadeiro.
      expect(
        _subItensDe(relatorio, SectionKind.ministry, '4. Iniciando conversas'),
        ['Conselho', 'Transição'],
      );
      expect(
        _subItensDe(
          relatorio,
          SectionKind.christianLife,
          '7. Seja adaptável — mostre interesse pessoal',
        ),
        ['Presidente'],
      );
      expect(
        relatorio.orderedItems
            .where((item) => item.isSubItem)
            .map((item) => item.label)
            .toSet(),
        {'Presidente', 'Conselho', 'Transição'},
      );
      expect(
        relatorio.orderedItems
            .where((item) => !item.isSubItem)
            .map((item) => item.label),
        [
          'Comentários iniciais',
          '1. Ele pregou com coragem',
          '2. Joias espirituais',
          '3. Leitura da Bíblia',
          '4. Iniciando conversas',
          '5. Cultivando o interesse',
          '6. Explicando suas crenças',
          'Presidente',
          '7. Seja adaptável — mostre interesse pessoal',
          '8. Estudo bíblico de congregação',
          'Comentários finais',
        ],
      );
    });
  });

  group('itens zerados e identificáveis', () {
    test('todo item nasce sem tempo acumulado e parado', () {
      final relatorio = _relatorioDeExemplo();

      expect(
        relatorio.orderedItems.map((item) => item.elapsed),
        everyElement(Duration.zero),
      );
      expect(
        relatorio.orderedItems.map((item) => item.runningSince),
        everyElement(isNull),
      );
    });

    test('todo item tem id único dentro do relatório', () {
      final relatorio = _relatorioDeExemplo();

      final ids = relatorio.orderedItems.map((item) => item.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, everyElement(isNotEmpty));
    });
  });

  group('seções sem partes', () {
    test('Nossa Vida Cristã sem partes gera só o "Presidente" avulso', () {
      final relatorio = const ReportBuilder().build(
        weekLabel: _semana,
        sections: const [
          ParsedSection(
            kind: SectionKind.christianLife,
            title: 'NOSSA VIDA CRISTÃ',
            partTitles: [],
          ),
        ],
      );

      expect(_rotulos(relatorio, SectionKind.christianLife), ['Presidente']);
    });

    test('as demais seções sem partes ficam vazias', () {
      final relatorio = const ReportBuilder().build(
        weekLabel: _semana,
        sections: const [
          ParsedSection(
            kind: SectionKind.treasures,
            title: 'TESOUROS DA PALAVRA DE DEUS',
            partTitles: [],
          ),
          ParsedSection(
            kind: SectionKind.ministry,
            title: 'FAÇA SEU MELHOR NO MINISTÉRIO',
            partTitles: [],
          ),
        ],
      );

      expect(_rotulos(relatorio, SectionKind.treasures), isEmpty);
      expect(_rotulos(relatorio, SectionKind.ministry), isEmpty);
      expect(relatorio.orderedItems.map((item) => item.label), [
        'Comentários iniciais',
        'Comentários finais',
      ]);
    });

    test('em Nossa Vida Cristã com uma única parte, ela é a última e fica sem '
        'sub-item', () {
      final relatorio = const ReportBuilder().build(
        weekLabel: _semana,
        sections: const [
          ParsedSection(
            kind: SectionKind.christianLife,
            title: 'NOSSA VIDA CRISTÃ',
            partTitles: ['8. Estudo bíblico de congregação'],
          ),
        ],
      );

      expect(_rotulos(relatorio, SectionKind.christianLife), [
        'Presidente',
        '8. Estudo bíblico de congregação',
      ]);
    });
  });
}
