import 'dart:convert';

import 'package:rdr/models/json_decoding.dart';
import 'package:rdr/models/meeting_report.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local do relatório em andamento, em `shared_preferences`.
class ReportStorageRepository {
  /// Chave única sob a qual o relatório inteiro é gravado.
  static const String storageKey = 'rdr.meeting_report';

  /// Grava o relatório, substituindo o que estiver salvo.
  Future<void> save(MeetingReport report) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(report.toJson()));
  }

  /// Apaga o relatório salvo. Não faz nada se não houver nada gravado.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  /// Devolve o relatório salvo, ou `null` quando não há nada gravado.
  Future<MeetingReport?> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final gravado = prefs.getString(storageKey);
      if (gravado == null) return null; // nada salvo ainda
      return MeetingReport.fromJson(jsonDecode(gravado));
    } on FormatException {
      // Texto que não é JSON.
      return _descartarLixo(prefs);
    } on ReportDecodeException {
      // JSON válido, mas de um formato que o app não entende mais.
      return _descartarLixo(prefs);
    } on TypeError {
      // A chave existe, mas guarda outro tipo (int, lista, booleano...).
      return _descartarLixo(prefs);
    }
  }

  /// Uma reunião não pode ser bloqueada por lixo em disco: o valor ilegível é
  /// apagado para que o app volte ao estado "sem relatório salvo".
  Future<MeetingReport?> _descartarLixo(SharedPreferences prefs) async {
    await prefs.remove(storageKey);
    return null;
  }
}
