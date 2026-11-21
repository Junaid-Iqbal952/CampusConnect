import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A random ID that identifies THIS browser/phone. Made once, then reused.
/// Do NOT delete it on logout, or the server would think it's a new device.
Future<String> getDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  var id = prefs.getString('device_id');
  if (id == null || id.isEmpty) {
    final random = Random.secure();                       // safe random numbers
    id = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();  // 32 hex characters
    await prefs.setString('device_id', id);
  }
  return id;
}