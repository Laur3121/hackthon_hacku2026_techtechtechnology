import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
// ここで分けたファイルをインポートする
import 'screens/home_screen.dart';
import 'screens/measure_screen.dart';
import 'screens/battle_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ToothbrushBattleApp());
}

class ToothbrushBattleApp extends StatelessWidget {
  const ToothbrushBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/battle': (context) => const BattleScreen(),
        '/measure': (context) => const MeasureScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}