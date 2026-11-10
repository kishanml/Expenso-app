import 'package:flutter/material.dart';

import 'app.dart';
import 'data/hive/hive_boxes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Everything lives on the phone. Opening the boxes here means no screen ever
  // has to deal with a not-yet-ready store.
  await HiveBoxes.init();

  runApp(const ExpensoApp());
}
