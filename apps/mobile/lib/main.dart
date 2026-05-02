import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/sami_app.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint(
          '[FlutterError] ${details.exceptionAsString()}\n${details.stack}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[PlatformError] $error\n$stack');
      return true;
    };
    runApp(SamiApp());
  }, (error, stack) {
    debugPrint('[ZoneError] $error\n$stack');
  });
}
