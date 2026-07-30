import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Erro de domínio da exportação da imagem do relatório.
///
/// Toda falha de plugin (arquivo, galeria, compartilhamento) é convertida para
/// esta exceção, com [message] em português pronta para ir num `SnackBar`.
class ImageExportException implements Exception {
  const ImageExportException(this.message, {this.cause});

  /// Mensagem em português, exibível direto na interface.
  final String message;

  /// Erro original do plugin, preservado para depuração.
  final Object? cause;

  @override
  String toString() => 'ImageExportException: $message';
}

/// Salva o PNG do relatório em disco, manda para a galeria e abre o menu de
/// compartilhamento do sistema.
///
/// Recebe os bytes já renderizados — a captura da imagem é responsabilidade da
/// camada de UI.
class ImageExportRepository {
  ImageExportRepository({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Álbum criado na galeria para os relatórios.
  static const String albumName = 'RDR';

  /// Grava [pngBytes] em disco, salva na galeria e abre o compartilhamento.
  ///
  /// Devolve o caminho do arquivo gravado. Lança [ImageExportException] em
  /// qualquer falha.
  Future<String> exportReportImage(Uint8List pngBytes) async {
    if (pngBytes.isEmpty) {
      throw const ImageExportException(
        'Não foi possível gerar a imagem do relatório.',
      );
    }

    final file = await _writeToDisk(pngBytes);
    await _saveToGallery(file.path);
    await _share(file.path);

    return file.path;
  }

  Future<File> _writeToDisk(Uint8List pngBytes) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${buildFileName(_now())}');
      return await file.writeAsBytes(pngBytes, flush: true);
    } on Object catch (error) {
      throw ImageExportException(
        'Não foi possível salvar a imagem no dispositivo.',
        cause: error,
      );
    }
  }

  Future<void> _saveToGallery(String path) async {
    bool hasAccess;
    try {
      hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess(toAlbum: true);
      }
    } on Object catch (error) {
      throw ImageExportException(
        'Não foi possível verificar a permissão de acesso à galeria.',
        cause: error,
      );
    }

    if (!hasAccess) {
      throw const ImageExportException(
        'Permissão de acesso à galeria negada. '
        'Autorize o acesso às fotos nas configurações do aparelho para salvar '
        'o relatório.',
      );
    }

    try {
      await Gal.putImage(path, album: albumName);
    } on GalException catch (error) {
      throw ImageExportException(_messageForGal(error.type), cause: error);
    } on Object catch (error) {
      throw ImageExportException(
        'Não foi possível salvar o relatório na galeria.',
        cause: error,
      );
    }
  }

  Future<void> _share(String path) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'image/png')],
          subject: 'Relatório da reunião',
        ),
      );
    } on Object catch (error) {
      throw ImageExportException(
        'A imagem foi salva na galeria, mas não foi possível abrir o '
        'compartilhamento.',
        cause: error,
      );
    }
  }

  static String _messageForGal(GalExceptionType type) => switch (type) {
    GalExceptionType.accessDenied =>
      'Permissão de acesso à galeria negada. '
          'Autorize o acesso às fotos nas configurações do aparelho para '
          'salvar o relatório.',
    GalExceptionType.notEnoughSpace =>
      'Espaço insuficiente no aparelho para salvar o relatório.',
    GalExceptionType.notSupportedFormat =>
      'Formato de imagem não suportado pela galeria.',
    GalExceptionType.unexpected =>
      'Não foi possível salvar o relatório na galeria.',
  };

  /// Nome do arquivo do relatório, com a data: `relatorio-reuniao-AAAA-MM-DD.png`.
  static String buildFileName(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return 'relatorio-reuniao-$year-$month-$day.png';
  }
}
