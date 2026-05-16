import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../env/env_check.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';

/// Loads Firebase, localization, and env before [runApp] without blocking
/// each subsystem on the others.
Future<void> prepareCoreRuntime() async {
  await Future.wait<void>([
    Firebase.initializeApp(),
    EasyLocalization.ensureInitialized(),
    _loadEnvironment(),
  ]);
}

Future<void> _loadEnvironment() async {
  await dotenv.load(fileName: '.env');
  await verifyEnv();
  // Native killed-state HTTP reads `api_base_url` from prefs — cache early.
  await ApiService.cacheNativeCallPrefs();
  AppLogger.w(
    '[Startup] api_base_url=${ApiService.baseUrl} '
    'socketOrigin=${ApiService.socketOrigin}',
  );
}
