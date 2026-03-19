import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // これは lib 直下にあるはずです
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
      title: '口臭王者歯磨キング',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/battle': (context) => BattleScreen(),   // constを外す
        '/measure': (context) => MeasureScreen(), // constを外す
        '/history': (context) => HistoryScreen(), // constを外す
      },
      debugShowCheckedModeBanner: false,
    );
  }
}