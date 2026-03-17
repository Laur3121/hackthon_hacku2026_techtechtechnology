import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ToothbrushBattleApp());
}

class ToothbrushBattleApp extends StatelessWidget {
  const ToothbrushBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '歯磨きバトル',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        // ここで const を外して定義します
        '/battle': (context) => const BattleScreen(),
        '/measure': (context) => const MeasureScreen(),
        '/history': (context) => const HistoryScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==========================================================
// 1. ホーム画面
// ==========================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歯磨きバトル', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.brush, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text('息をキレイにして敵を倒せ！', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 50),
            _buildMenuButton(context, title: '⚔️ バトル開始', icon: Icons.sports_esports, color: Colors.redAccent, routeName: '/battle'),
            const SizedBox(height: 20),
            _buildMenuButton(context, title: '📊 数値チェック', icon: Icons.analytics_outlined, color: Colors.orangeAccent, routeName: '/measure'),
            const SizedBox(height: 20),
            _buildMenuButton(context, title: '📜 履歴', icon: Icons.history_edu, color: Colors.greenAccent, routeName: '/history'),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required String title, required IconData icon, required Color color, required String routeName}) {
    return SizedBox(
      width: 280,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(title, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: () => Navigator.pushNamed(context, routeName),
      ),
    );
  }
}

// ==========================================================
// 2. 数値チェック画面（生データを表示）
// ==========================================================
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('sensor');
  int _rawValue = 0; 

  @override
  void initState() {
    super.initState();
    // ESP32側でFirebaseに送るキー名を 'rawValue' に想定しています
    _dbRef.child('rawValue').onValue.listen((DatabaseEvent event) {
      if (mounted && event.snapshot.value != null) {
        setState(() {
          _rawValue = int.parse(event.snapshot.value.toString());
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📊 数値チェック')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('現在のセンサー数値', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 10),
            Text(
              '$_rawValue',
              style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text('※この数値が低いほど、息がクリーンな状態です。', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 3. バトル画面（土台）
// ==========================================================
class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚔️ バトル')),
      body: const Center(
        child: Text('ここに戦闘画面を作っていきます！', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}

// ==========================================================
// 4. 履歴画面（土台）
// ==========================================================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📜 履歴')),
      body: const Center(
        child: Text('ここに過去の記録を表示します！', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}