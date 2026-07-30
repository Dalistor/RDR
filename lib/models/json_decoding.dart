/// Exceção de domínio da decodificação de um relatório persistido, e os
/// leitores tipados usados pelos models para nunca deixar vazar um `TypeError`.
library;

/// Lançada quando o JSON de um relatório está malformado, tem campo obrigatório
/// ausente ou valor de tipo inesperado.
class ReportDecodeException implements Exception {
  const ReportDecodeException(this.message);

  /// Mensagem em português, exibível ao usuário.
  final String message;

  @override
  String toString() => 'ReportDecodeException: $message';
}

/// Garante que [json] é um objeto JSON.
Map<String, dynamic> readJsonMap(Object? json, String contexto) {
  if (json is! Map<String, dynamic>) {
    throw ReportDecodeException('$contexto: esperava um objeto JSON.');
  }
  return json;
}

/// Lê um campo obrigatório do tipo [T].
T readField<T>(Map<String, dynamic> map, String chave, String contexto) {
  if (!map.containsKey(chave)) {
    throw ReportDecodeException('$contexto: campo "$chave" ausente.');
  }
  final valor = map[chave];
  if (valor is! T) {
    throw ReportDecodeException(
      '$contexto: campo "$chave" deveria ser $T, veio ${valor.runtimeType}.',
    );
  }
  return valor;
}

/// Lê um texto opcional; `null` continua `null`.
String? readOptionalString(
  Map<String, dynamic> map,
  String chave,
  String contexto,
) {
  final valor = map[chave];
  if (valor == null) return null;
  if (valor is! String) {
    throw ReportDecodeException(
      '$contexto: campo "$chave" deveria ser texto, veio ${valor.runtimeType}.',
    );
  }
  return valor;
}

/// Lê uma data ISO-8601 opcional; `null` continua `null`.
DateTime? readOptionalDateTime(
  Map<String, dynamic> map,
  String chave,
  String contexto,
) {
  final valor = map[chave];
  if (valor == null) return null;
  if (valor is! String) {
    throw ReportDecodeException(
      '$contexto: campo "$chave" deveria ser uma data ISO-8601 em texto.',
    );
  }
  final data = DateTime.tryParse(valor);
  if (data == null) {
    throw ReportDecodeException(
      '$contexto: campo "$chave" não é uma data ISO-8601 válida ("$valor").',
    );
  }
  return data;
}

/// Lê uma lista obrigatória e a decodifica item a item com [decodificar].
List<T> readList<T>(
  Map<String, dynamic> map,
  String chave,
  String contexto,
  T Function(Object? item) decodificar,
) {
  final valor = readField<List<dynamic>>(map, chave, contexto);
  return valor.map(decodificar).toList(growable: false);
}
