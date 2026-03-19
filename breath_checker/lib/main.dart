import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ← ★これが必要
import 'firebase_options.dart'; 
import 'screens/home_screen.dart';
import 'screens/measure_screen.dart';
import 'screens/battle_screen.dart';
import 'screens/history_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 現在のユーザーを取得
  final user = FirebaseAuth.instance.currentUser;

  runApp(ToothbrushBattleApp(
    // ログイン済みなら '/home'、未ログインなら '/'
    initialRoute: user == null ? '/' : '/home', 
  ));
}

class ToothbrushBattleApp extends StatelessWidget {
  final String initialRoute; 
  const ToothbrushBattleApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '口臭王者歯磨キング',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // ★重複していた 'initialRoute: "/",' を削除し、コンストラクタから受け取ったものだけを使用
      initialRoute: initialRoute, 
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(), // もし赤線が出るなら const を外してください
        '/battle': (context) => const BattleScreen(),   
        '/measure': (context) => const MeasureScreen(), 
        '/history': (context) => const HistoryScreen(), 
      },
      debugShowCheckedModeBanner: false,
    );
  }
}