import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rdr/models/section_kind.dart';
import 'package:rdr/services/schedule_parser.dart';

/// HTML real capturado do wol.jw.org. Nenhum teste toca a rede.
String loadFixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  late String weekPageHtml;
  late String documentHtml;

  setUpAll(() {
    weekPageHtml = loadFixture('meetings_week_2026_31.html');
    documentHtml = loadFixture('mwb_2026_31.html');
  });

  group('ScheduleParser.parseWeekPage', () {
    test('acha o caminho do documento da Apostila Vida e Ministério', () {
      const parser = ScheduleParser();

      final week = parser.parseWeekPage(weekPageHtml);

      expect(week.documentPath, '/pt/wol/d/r5/lp-t/202026244');
    });

    test('ignora o documento de A Sentinela, mesmo vindo antes na página', () {
      const parser = ScheduleParser();
      const html = '''
        <ul>
          <li><a href="/pt/wol/d/r5/lp-t/2026403">
            <div class="cardLine1">Continue espiritualmente forte</div>
            <div class="cardLine2">A Sentinela (Estudo) — 2026 | maio</div>
          </a></li>
          <li><a href="/pt/wol/d/r5/lp-t/202026244">
            <div class="cardLine1">27 de julho–2 de agosto</div>
            <div class="cardLine2">Apostila Vida e Ministério — 2026 | julho</div>
          </a></li>
        </ul>''';

      final week = parser.parseWeekPage(html);

      expect(week.documentPath, '/pt/wol/d/r5/lp-t/202026244');
    });

    test('extrai o rótulo da semana com o traço – (U+2013)', () {
      const parser = ScheduleParser();

      final week = parser.parseWeekPage(weekPageHtml);

      expect(week.weekLabel, '27 de julho–2 de agosto');
    });

    test('sem link da apostila, lança ScheduleParseException explicando', () {
      const parser = ScheduleParser();
      const html = '''
        <ul><li><a href="/pt/wol/d/r5/lp-t/2026403">
          A Sentinela (Estudo) — 2026 | maio
        </a></li></ul>''';

      expect(
        () => parser.parseWeekPage(html),
        throwsA(
          isA<ScheduleParseException>()
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('Apostila Vida e Ministério'),
                  contains('wol.jw.org'),
                  contains('manualmente'),
                ),
              )
              .having(
                (e) => e.toString(),
                'toString',
                startsWith('ScheduleParseException: Não achei o link'),
              ),
        ),
      );
    });

    test(
      'com link mas sem o rótulo da semana, lança ScheduleParseException',
      () {
        const parser = ScheduleParser();
        const html = '''
        <ul><li><a href="/pt/wol/d/r5/lp-t/202026244">
          Apostila Vida e Ministério — 2026 | julho
        </a></li></ul>''';

        expect(
          () => parser.parseWeekPage(html),
          throwsA(
            isA<ScheduleParseException>().having(
              (e) => e.message,
              'message',
              contains('semana'),
            ),
          ),
        );
      },
    );

    test('normaliza o rótulo da semana com &nbsp; e quebras de linha', () {
      const parser = ScheduleParser();
      const html = '''
        <ul><li><a href="/pt/wol/d/r5/lp-t/202026244">
          <div class="cardLine1">27&nbsp;de&nbsp;julho–2
             de   agosto
          </div>
          <div class="cardLine2">Apostila Vida e Ministério — 2026 | julho</div>
        </a></li></ul>''';

      final week = parser.parseWeekPage(html);

      expect(week.weekLabel, '27 de julho–2 de agosto');
    });
  });

  group('ScheduleParser.parseDocument', () {
    test('devolve as três seções na ordem do documento, com kind e título', () {
      const parser = ScheduleParser();

      final sections = parser.parseDocument(documentHtml);

      expect(sections.map((s) => s.kind), [
        SectionKind.treasures,
        SectionKind.ministry,
        SectionKind.christianLife,
      ]);
      expect(sections.map((s) => s.title), [
        'TESOUROS DA PALAVRA DE DEUS',
        'FAÇA SEU MELHOR NO MINISTÉRIO',
        'NOSSA VIDA CRISTÃ',
      ]);
    });

    test('lista as partes de Tesouros já numeradas pelo wol', () {
      const parser = ScheduleParser();

      final sections = parser.parseDocument(documentHtml);

      expect(sections[0].partTitles, [
        '1. Ele pregou com coragem',
        '2. Joias espirituais',
        '3. Leitura da Bíblia',
      ]);
    });

    test('lista as partes de Faça Seu Melhor no Ministério', () {
      const parser = ScheduleParser();

      final sections = parser.parseDocument(documentHtml);

      expect(sections[1].partTitles, [
        '4. Iniciando conversas',
        '5. Cultivando o interesse',
        '6. Explicando suas crenças',
      ]);
    });

    test('lista as partes de Nossa Vida Cristã', () {
      const parser = ScheduleParser();

      final sections = parser.parseDocument(documentHtml);

      expect(sections[2].partTitles, [
        '7. Seja adaptável — mostre interesse pessoal',
        '8. Estudo bíblico de congregação',
      ]);
    });

    test('não transforma cântico, oração e comentários em partes', () {
      const parser = ScheduleParser();

      final allParts = parser
          .parseDocument(documentHtml)
          .expand((section) => section.partTitles);

      expect(
        allParts,
        everyElement(
          allOf(
            isNot(contains('Cântico')),
            isNot(contains('oração')),
            isNot(contains('Comentários')),
          ),
        ),
      );
    });

    test('parte numerada sem classe de cor ainda entra na seção aberta', () {
      const parser = ScheduleParser();
      const html = '''
        <div>
          <h2 class="du-color--gold-700"><strong>FAÇA SEU MELHOR NO MINISTÉRIO</strong></h2>
          <h3><strong>4. Iniciando conversas</strong></h3>
          <h3><strong>Cântico 57</strong></h3>
        </div>''';

      final sections = parser.parseDocument(html);

      expect(sections.single.partTitles, ['4. Iniciando conversas']);
    });

    test('seção sem nenhuma parte vem com a lista de partes vazia', () {
      const parser = ScheduleParser();
      const html = '''
        <div>
          <h2 class="du-color--teal-700"><strong>TESOUROS DA PALAVRA DE DEUS</strong></h2>
          <h3><strong>Cântico 57</strong></h3>
        </div>''';

      final sections = parser.parseDocument(html);

      expect(sections.single.kind, SectionKind.treasures);
      expect(sections.single.partTitles, isEmpty);
    });

    test('sem nenhuma das três seções, lança ScheduleParseException', () {
      const parser = ScheduleParser();
      const html = '''
        <div>
          <h2><strong>JEREMIAS 20-21</strong></h2>
          <h3><strong>Cântico 73 e oração | Comentários iniciais</strong></h3>
        </div>''';

      expect(
        () => parser.parseDocument(html),
        throwsA(
          isA<ScheduleParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('seç'), contains('manualmente')),
          ),
        ),
      );
    });

    test('decodifica entidades e normaliza os espaços dos títulos', () {
      const parser = ScheduleParser();
      const html = '''
        <div>
          <h2 class="du-color--teal-700"><strong>TESOUROS&nbsp;DA
             PALAVRA   DE DEUS</strong></h2>
          <h3 class="du-color--teal-700"><strong>1. Perguntas
             &amp;&nbsp;respostas</strong> </h3>
        </div>''';

      final sections = parser.parseDocument(html);

      expect(sections.single.title, 'TESOUROS DA PALAVRA DE DEUS');
      expect(sections.single.partTitles, ['1. Perguntas & respostas']);
    });

    test(
      'ignora o h2 do texto bíblico da semana, que não tem classe de cor',
      () {
        const parser = ScheduleParser();

        final sections = parser.parseDocument(documentHtml);

        expect(sections, hasLength(3));
        expect(
          sections.map((section) => section.title),
          isNot(contains('JEREMIAS 20-21')),
        );
      },
    );
  });
}
