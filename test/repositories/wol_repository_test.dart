import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rdr/repositories/wol_repository.dart';

const String weekPageUrl = 'https://wol.jw.org/pt/wol/meetings/r5/lp-t/';
const String documentPath = '/pt/wol/d/r5/lp-t/202026244';
const String documentUrl = 'https://wol.jw.org$documentPath';

/// Guarda a requisição que o repositório enviou, para as asserções de URL e
/// de header. Nenhum teste toca a rede: tudo passa pelo [MockClient].
class RequestRecorder {
  http.BaseRequest? _lastRequest;

  MockClient clientRespondingWith(String body) {
    return MockClient((request) async {
      _lastRequest = request;
      return http.Response(body, 200);
    });
  }

  Uri get requestedUrl => _lastRequest!.url;

  String? get sentUserAgent =>
      _lastRequest!.headers['User-Agent'] ?? _lastRequest!.headers['user-agent'];
}

MockClient clientReturningStatus(int statusCode) =>
    MockClient((request) async => http.Response('erro', statusCode));

MockClient clientThrowing(Object error) => MockClient((request) async => throw error);

Matcher isNoConnectionFailure() => isA<WolFetchException>()
    .having((e) => e.statusCode, 'statusCode', isNull)
    .having((e) => e.message.toLowerCase(), 'message', contains('conexão'))
    .having((e) => e.toString(), 'toString', contains('internet'));

void main() {
  group('WolRepository — construção', () {
    test('sem client injetado, cria o próprio http.Client sem tocar a rede', () {
      expect(WolRepository.new, returnsNormally);
    });
  });

  group('WolRepository.fetchCurrentWeekPage', () {
    test('busca a página da semana no wol e devolve o corpo em texto', () async {
      final recorder = RequestRecorder();
      final repository = WolRepository(
        client: recorder.clientRespondingWith('<html>semana</html>'),
      );

      final body = await repository.fetchCurrentWeekPage();

      expect(recorder.requestedUrl.toString(), weekPageUrl);
      expect(body, '<html>semana</html>');
    });

    test('envia um User-Agent de navegador móvel em vez do padrão do Dart', () async {
      final recorder = RequestRecorder();
      final repository = WolRepository(client: recorder.clientRespondingWith('<html></html>'));

      await repository.fetchCurrentWeekPage();

      expect(recorder.sentUserAgent, isNotNull);
      expect(recorder.sentUserAgent, isNot(contains('Dart')));
      expect(recorder.sentUserAgent, contains('Mozilla/5.0'));
      expect(recorder.sentUserAgent, contains('Android'));
      expect(recorder.sentUserAgent, contains('Mobile'));
    });

    test('decodifica o corpo como UTF-8, preservando acentos e o traço –', () async {
      const html = '<h1>Comentários iniciais</h1><p>27 de julho–2 de agosto</p>';
      // O wol responde sem charset no Content-Type; os bytes são UTF-8.
      final client = MockClient((request) async => http.Response.bytes(utf8.encode(html), 200));
      final repository = WolRepository(client: client);

      final body = await repository.fetchCurrentWeekPage();

      expect(body, html);
      expect(body, contains('Comentários'));
      expect(body, contains('–'));
    });

    test('byte inválido no meio do HTML não derruba a decodificação', () async {
      final corruptedBytes = [...utf8.encode('<p>ok'), 0xFF, ...utf8.encode('</p>')];
      final client = MockClient((request) async => http.Response.bytes(corruptedBytes, 200));
      final repository = WolRepository(client: client);

      final body = await repository.fetchCurrentWeekPage();

      expect(body, startsWith('<p>ok'));
      expect(body, endsWith('</p>'));
    });
  });

  group('WolRepository.fetchDocument', () {
    test('resolve o caminho relativo contra o host do wol', () async {
      final recorder = RequestRecorder();
      final repository = WolRepository(
        client: recorder.clientRespondingWith('<html>apostila</html>'),
      );

      final body = await repository.fetchDocument(documentPath);

      expect(recorder.requestedUrl.toString(), documentUrl);
      expect(body, '<html>apostila</html>');
    });

    test('não duplica o host quando já recebe uma URL absoluta', () async {
      final recorder = RequestRecorder();
      final repository = WolRepository(
        client: recorder.clientRespondingWith('<html>apostila</html>'),
      );

      await repository.fetchDocument(documentUrl);

      expect(recorder.requestedUrl.toString(), documentUrl);
    });

    test('envia o mesmo User-Agent de navegador móvel ao buscar o documento', () async {
      final recorder = RequestRecorder();
      final repository = WolRepository(client: recorder.clientRespondingWith('<html></html>'));

      await repository.fetchDocument(documentPath);

      expect(recorder.sentUserAgent, WolRepository.userAgent);
      expect(recorder.sentUserAgent, isNot(contains('Dart')));
    });
  });

  group('WolRepository — erros', () {
    test('status diferente de 200 na página da semana lança WolFetchException com o status',
        () async {
      final repository = WolRepository(client: clientReturningStatus(404));

      await expectLater(
        repository.fetchCurrentWeekPage(),
        throwsA(
          isA<WolFetchException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.toString(), 'toString', contains('404')),
        ),
      );
    });

    test('status diferente de 200 no documento lança WolFetchException com o status', () async {
      final repository = WolRepository(client: clientReturningStatus(500));

      await expectLater(
        repository.fetchDocument(documentPath),
        throwsA(isA<WolFetchException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('SocketException vira WolFetchException avisando da falta de conexão', () async {
      final repository = WolRepository(
        client: clientThrowing(const SocketException('Failed host lookup: wol.jw.org')),
      );

      await expectLater(repository.fetchCurrentWeekPage(), throwsA(isNoConnectionFailure()));
    });

    test('ClientException vira WolFetchException avisando da falta de conexão', () async {
      final repository = WolRepository(
        client: clientThrowing(http.ClientException('Connection closed')),
      );

      await expectLater(repository.fetchDocument(documentPath), throwsA(isNoConnectionFailure()));
    });

    test('requisição que passa do timeout vira WolFetchException', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('<html>tarde demais</html>', 200);
      });
      final repository = WolRepository(
        client: client,
        timeout: const Duration(milliseconds: 30),
      );

      await expectLater(
        repository.fetchCurrentWeekPage(),
        throwsA(
          isA<WolFetchException>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having((e) => e.message.toLowerCase(), 'message', contains('demor')),
        ),
      );
    });

    test('o timeout padrão é finito e razoável para uma rede de celular', () {
      expect(WolRepository.defaultTimeout, greaterThanOrEqualTo(const Duration(seconds: 5)));
      expect(WolRepository.defaultTimeout, lessThanOrEqualTo(const Duration(seconds: 30)));
    });
  });
}
