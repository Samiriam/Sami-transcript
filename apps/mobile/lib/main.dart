import 'dart:async';

import 'package:flutter/material.dart';

import 'app/sami_app.dart';
import 'core/services/app_logger.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final logger = AppLogger.instance;
    await logger.init();
    AppLogger.initGlobalErrorHandlers();
    logger.info('Main', 'App starting');
    runApp(SamiApp());
  }, (error, stack) {
    AppLogger.instance.error('ZoneError', error.toString(), stack.toString());
  });
}
