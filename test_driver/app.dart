import 'dart:async';

import 'package:flutter_driver/driver_extension.dart';

import 'package:dnd_prod/main.dart' as app;

void main() {
  enableFlutterDriverExtension();
  unawaited(app.main());
}
