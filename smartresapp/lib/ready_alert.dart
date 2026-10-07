import 'package:flutter/services.dart';

/// Tracks completed IDs, not the count: replacing one dish with another still alerts.
class ReadyTracker {
  final Set<int> announced = {};
  List<Map<String, dynamic>> update(List<Map<String, dynamic>> items) {
    final fresh = items
        .where(
          (i) => i['status'] == 'completed' && !announced.contains(i['id']),
        )
        .toList();
    announced.addAll(fresh.map((i) => i['id'] as int));
    return fresh;
  }
}

class ReadyAlert {
  static const channel = MethodChannel('smartres/ready_alert');
  Future<bool> enabled() async {
    try {
      return await channel.invokeMethod<bool>('enabled') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  Future<void> setEnabled(bool value) async {
    try {
      await channel.invokeMethod<void>('setEnabled', value);
    } on MissingPluginException {
      /* Web preview has no native sound settings. */
    }
  }

  Future<bool> play() async {
    try {
      return await channel.invokeMethod<bool>('play') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
