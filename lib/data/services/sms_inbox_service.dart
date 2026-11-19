import 'package:flutter/services.dart';

/// One message as it came off the phone, before any interpretation.
class RawSms {
  const RawSms({
    required this.id,
    required this.body,
    required this.receivedAt,
    this.sender,
  });

  final String id;
  final String body;
  final DateTime receivedAt;
  final String? sender;
}

/// Reads the SMS inbox through a small platform channel.
///
/// Android only. iOS gives no app access to messages at all — that is a
/// platform rule with no workaround — so every method here degrades to
/// "unsupported" rather than throwing, and the UI hides the feature.
class SmsInboxService {
  const SmsInboxService();

  static const _channel = MethodChannel('expenso/sms');

  /// False on iOS, desktop, or anywhere the channel is not registered.
  Future<bool> isSupported() async {
    try {
      await _channel.invokeMethod<bool>('hasPermission');
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system permission dialog. Returns what the person chose.
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Messages received after [since], newest first.
  ///
  /// Returns an empty list rather than throwing when the permission is not
  /// held, so a revoked permission degrades to "nothing found" instead of
  /// breaking the screen.
  Future<List<RawSms>> readInbox({
    required DateTime since,
    int limit = 200,
  }) async {
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'readInbox',
        {'sinceMillis': since.millisecondsSinceEpoch, 'limit': limit},
      );
      if (raw == null) return const [];

      return [
        for (final message in raw)
          RawSms(
            id: message['id'] as String? ?? '',
            body: message['body'] as String? ?? '',
            sender: message['sender'] as String?,
            receivedAt: DateTime.fromMillisecondsSinceEpoch(
              (message['receivedAt'] as num?)?.toInt() ?? 0,
            ),
          ),
      ]..removeWhere((message) => message.id.isEmpty || message.body.isEmpty);
    } catch (_) {
      return const [];
    }
  }
}
