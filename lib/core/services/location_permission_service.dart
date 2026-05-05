import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// Requests location **while in use**, then **always / background** on mobile so
/// updates can continue when the app is not in the foreground (within OS limits;
/// Android may still require a foreground service for uninterrupted tracking).
Future<bool> requestLocationForBackgroundTracking() async {
  if (kIsWeb) return false;

  final whenInUse = await Permission.locationWhenInUse.request();
  if (!whenInUse.isGranted) return false;

  final always = await Permission.locationAlways.status;
  if (!always.isGranted) {
    await Permission.locationAlways.request();
  }

  return Permission.locationWhenInUse.isGranted;
}
