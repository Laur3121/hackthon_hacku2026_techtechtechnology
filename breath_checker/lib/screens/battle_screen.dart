import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  // ステータス管理
  int world = 1;
  int stage = 1;
  int enemyCurrentHp = 100;
  int enemyMaxHp = 100;
  final int maxStage = 5;
  
  double? beforeScore;
  bool isMeasuring = false;
  final String apiUrl = "https://breath-checker-api-476724390420.asia-northeast1.run.app";

  @override
  void initState() {
    super.initState();
    _loadGameStatus(); // 起動時にセーブデータを読み込む
  }

  // --- API連携関数 ---

  Future<void> _loadGameStatus() async {
    try {
      final res = await http.get(Uri.parse("$apiUrl/game-status"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          world = data['world'] ?? 1;
          stage = data['stage'] ?? 1;
          enemyCurrentHp = data['current_hp'] ?? 100;
          enemyMaxHp = data['max_hp'] ?? 100;
        });
      }
    } catch (e) { print("読み込みエラー: $e"); }
  }

  // 本当のダメージを計算して攻撃する
  void _processAttack() async {
    setState(() => isMeasuring = true);
    
    try {
      // 1. 磨いた後の数値を取得
      final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
      double afterScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
      
      // 2. ダメージ計算 (磨く前 - 磨いた後) * 10
      // 例: 40%から10%に減ったら 30 * 10 = 300ダメージ
      double diff = (beforeScore ?? 0) - afterScore;
      int damage = diff > 0 ? (diff * 10).toInt() : 5; // 最低5ダメ

      // 3. Pythonにダメージを送ってセーブ＆更新
      final attackRes = await http.post(Uri.parse("$apiUrl/attack?damage=$damage"));
      if (attackRes.statusCode == 200) {
        final newData = json.decode(attackRes.body);
        
        setState(() {
          enemyCurrentHp = newData['current_hp'];
          stage = newData['stage'];
          world = newData['world'];
          enemyMaxHp = newData['max_hp'];
          
          _showResultDialog(diff, damage); // 何ダメ出たか表示！
          beforeScore = null; 
          isMeasuring = false;
        });
      }
    } catch (e) {
      print("攻撃エラー: $e");
      setState(() => isMeasuring = false);
    }
  }

  // --- UIウィジェット ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ワールド $world")),
      body: Column(
        children: [
          const SizedBox(height: 30),
          _buildStageIndicator(), // 横軸インジケーター
          const Spacer(),
          Text("Stage $world-$stage", style: const TextStyle(fontSize: 18, color: Colors.grey)),
          const Text("よごれモンスター", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildHpBar(),
          const SizedBox(height: 40),
          // 敵の画像（stageに合わせて変える）
          Image.asset('assets/monster_$stage.png', height: 220, 
            errorBuilder: (context, error, stack) => const Icon(Icons.auto_fix_high, size: 100, color: Colors.purple)),
          const Spacer(),
          _buildActionButton(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // 横軸のステージ表示
  Widget _buildStageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(height: 2, color: Colors.grey[300]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(maxStage, (index) {
              int s = index + 1;
              bool isCurrent = s == stage;
              bool isCleared = s < stage;
              return CircleAvatar(
                radius: 12,
                backgroundColor: isCurrent ? Colors.blue : (isCleared ? Colors.green : Colors.grey[300]),
                child: isCleared 
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : Text('$s', style: const TextStyle(color: Colors.white, fontSize: 10)),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHpBar() {
    return Column(
      children: [
        Container(
          width: 250, height: 15,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: enemyCurrentHp / enemyMaxHp,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
            ),
          ),
        ),
        Text('$enemyCurrentHp / $enemyMaxHp', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: beforeScore == null
        ? ElevatedButton(
            onPressed: isMeasuring ? null : () async {
              setState(() => isMeasuring = true);
              final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
              beforeScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
              setState(() => isMeasuring = false);
            },
            child: Text(isMeasuring ? "スキャン中..." : "1. 磨く前の汚れを測る"),
          )
        : ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: isMeasuring ? null : _processAttack,
            child: Text(isMeasuring ? "判定中..." : "2. 磨き終わった！攻撃！"),
          ),
    );
  }

  void _showResultDialog(double diff, int damage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ナイス・ブレス！"),
        content: Text("汚れを ${diff.toStringAsFixed(1)}% 浄化した！\n敵に $damage のダメージ！"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }
}