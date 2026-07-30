import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Mensagem única de falta de conectividade: o app exige internet para baixar
/// a programação, e a UI usa este texto para orientar o usuário.
const String _noConnectionMessage =
    'Não foi possível conectar ao wol.jw.org. Verifique sua conexão com a internet e tente de novo.';

const String _timeoutMessage =
    'O site wol.jw.org demorou demais para responder. Verifique sua conexão e tente de novo.';

/// Falha ao buscar conteúdo no wol.jw.org.
///
/// A [message] é escrita em português para a UI mostrar direto ao usuário.
class WolFetchException implements Exception {
  const WolFetchException(this.message, {this.statusCode});

  final String message;

  /// Status HTTP quando a falha veio de uma resposta do servidor;
  /// nulo quando a requisição nem chegou a completar.
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? 'WolFetchException: $message' : 'WolFetchException($statusCode): $message';
}

/// Acesso HTTP ao site wol.jw.org. Só busca HTML — o parsing é do service.
class WolRepository {
  WolRepository({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? defaultTimeout;

  /// Rede de celular em salão do Reino costuma ser lenta; ainda assim a espera
  /// precisa ser finita para a UI conseguir avisar o usuário.
  static const Duration defaultTimeout = Duration(seconds: 20);

  static const String baseUrl = 'https://wol.jw.org';
  static const String currentWeekPath = '/pt/wol/meetings/r5/lp-t/';

  /// O wol.jw.org entrega layouts diferentes conforme o cliente; o app pede
  /// sempre a versão de navegador móvel.
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  final http.Client _client;
  final Duration _timeout;

  /// Busca a página que redireciona para a programação da semana corrente.
  Future<String> fetchCurrentWeekPage() => _get(_resolve(currentWeekPath));

  /// Busca um documento do wol a partir do caminho relativo achado na página
  /// da semana (ex.: `/pt/wol/d/r5/lp-t/202026244`). Uma URL já absoluta é
  /// usada como veio.
  Future<String> fetchDocument(String path) => _get(_resolve(path));

  Uri _resolve(String path) => Uri.parse(baseUrl).resolve(path);

  Future<String> _get(Uri url) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            url,
            headers: const {'User-Agent': userAgent},
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const WolFetchException(_timeoutMessage);
    } on SocketException {
      throw const WolFetchException(_noConnectionMessage);
    } on http.ClientException {
      throw const WolFetchException(_noConnectionMessage);
    }

    if (response.statusCode != 200) {
      throw WolFetchException(
        'O site wol.jw.org respondeu com erro ${response.statusCode}. Tente de novo mais tarde.',
        statusCode: response.statusCode,
      );
    }

    // O wol responde sem charset no Content-Type e o `http` cairia em latin-1,
    // o que estraga acentos e o traço `–` do rótulo da semana.
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }
}
