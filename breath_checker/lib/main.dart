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
            _buildMenuButton(context, 
                title: '⚔️ バトル開始', 
                icon: Icons.sports_esports, 
                color: Colors.redAccent, 
                routeName: '/battle'),
            const SizedBox(height: 20),
            _buildMenuButton(context, 
                title: '📊 数値チェック', 
                icon: Icons.analytics_outlined, 
                color: Colors.orangeAccent, 
                routeName: '/measure'),
            const SizedBox(height: 20),
            _buildMenuButton(context, 
                title: '📜 履歴', 
                icon: Icons.history_edu, 
                color: Colors.greenAccent, 
                routeName: '/history'),
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
        style: ElevatedButton.styleFrom(
          backgroundColor: color, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
        ),
        onPressed: () => Navigator.pushNamed(context, routeName),
      ),
    );
  }
}

// ==========================================================
// 2. 数値チェック画面（ESP32からの全データを表示）
// ==========================================================
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('sensor');
  
  double _temp = 0.0;
  double _hum = 0.0;
  double _gas = 0.0;
  double _diff = 0.0;

  @override
  void initState() {
    super.initState();
    // JSON全体を監視してパースする
    _dbRef.onValue.listen((DatabaseEvent event) {
      if (mounted && event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          _temp = double.parse(data['temperature'].toString());
          _hum  = double.parse(data['humidity'].toString());
          _gas  = double.parse(data['gas_resistance'].toString());
          _diff = double.parse(data['diff_percent'].toString());
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📊 数値チェック')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text('汚れ度 (変化率)', style: TextStyle(fontSize: 20)),
            Text(
              '${_diff.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 80, 
                fontWeight: FontWeight.bold, 
                color: _diff > 20 ? Colors.red : Colors.blue
              ),
            ),
            const Divider(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoCard('温度', '${_temp.toStringAsFixed(1)}℃', Icons.thermostat),
                  _infoCard('湿度', '${_hum.toStringAsFixed(1)}%', Icons.water_drop),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _infoCard('ガス抵抗値', '${_gas.toStringAsFixed(1)} kΩ', Icons.air),
            const SizedBox(height: 40),
            Text(
              _diff > 20 ? '⚠️ 空気が汚れています！換気か歯磨きを！' : '✅ 空気はクリーンです',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: _diff > 20 ? Colors.red : Colors.green
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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