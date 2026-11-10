import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/backup.dart';

/// Where an export ended up, so the UI can say something specific.
sealed class ExportOutcome {
  const ExportOutcome();
}

/// Handed to the system share sheet — the user chose where it went.
class ExportShared extends ExportOutcome {
  const ExportShared();
}

/// Written straight to disk, because this platform has no share sheet.
class ExportSaved extends ExportOutcome {
  const ExportSaved(this.path);
  final String path;
}

class ExportCancelled extends ExportOutcome {
  const ExportCancelled();
}

/// Reads and writes backup files.
///
/// Export prefers the platform's own "where do you want this?" flow — a save
/// dialog on desktop, the share sheet on a phone — and only falls back to
/// writing into the app's own directory when neither exists.
class BackupService {
  const BackupService();

  static const _typeGroup = XTypeGroup(
    label: 'Expenso backup',
    extensions: ['json'],
    uniformTypeIdentifiers: ['public.json'],
    mimeTypes: ['application/json'],
  );

  bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  Future<ExportOutcome> export(Backup backup, {DateTime? now}) async {
    final json = const JsonEncoder.withIndent('  ').convert(backup.toJson());
    final fileName = Backup.fileNameFor(now ?? DateTime.now());

    if (_isDesktop) {
      final location = await getSaveLocation(suggestedName: fileName);
      if (location == null) return const ExportCancelled();

      final file = File(location.path);
      await file.writeAsString(json);
      return ExportSaved(file.path);
    }

    // On a phone the share sheet is the way out of the app sandbox: Files,
    // Drive, email, a chat — all of them are a valid home for the backup.
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(json);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [fileName],
        subject: 'Expenso backup',
      ),
    );

    return result.status == ShareResultStatus.dismissed
        ? const ExportCancelled()
        : const ExportShared();
  }

  /// Returns null when the user backs out of the file picker.
  Future<Backup?> pickAndRead() async {
    final file = await openFile(acceptedTypeGroups: const [_typeGroup]);
    if (file == null) return null;

    final contents = await file.readAsString();

    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      throw const BackupFormatException(
        'That file is not valid JSON, so it is not an Expenso backup.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException('That file is not an Expenso backup.');
    }
    return Backup.fromJson(decoded);
  }
}
