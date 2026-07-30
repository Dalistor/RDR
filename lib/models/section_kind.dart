import 'package:rdr/models/json_decoding.dart';

/// As três seções fixas da reunião Vida e Ministério Cristão.
enum SectionKind {
  /// Tesouros da Palavra de Deus.
  treasures,

  /// Faça Seu Melhor no Ministério.
  ministry,

  /// Nossa Vida Cristã.
  christianLife;

  /// Reconstrói a seção a partir do nome serializado por [name].
  static SectionKind fromName(String nome) {
    for (final kind in SectionKind.values) {
      if (kind.name == nome) return kind;
    }
    throw ReportDecodeException('Seção desconhecida: "$nome".');
  }
}
