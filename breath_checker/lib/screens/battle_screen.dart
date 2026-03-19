import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with TickerProviderStateMixin {
  int world = 1;
  int stage = 1;
  int enemyCurrentHp = 85; 
  int enemyMaxHp = 100;
  double? beforeScore;
  bool isMeasuring = false;
  bool isWalking = false; 
  bool isDamaged = false; // ダメージ演出用フラグ

  final String apiUrl = "https://breath-checker-api-476724390420.asia-northeast1.run.app";
  late AnimationController _pulupuluController;

  @override
  void initState() {
    super.initState();
    _loadGameStatus();
    _pulupuluController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulupuluController.dispose();
    super.dispose();
  }

  // --- デバッグ用：進捗リセット ---
  Future<void> _resetGame() async {
    try {
      final res = await http.post(Uri.parse("$apiUrl/reset-game")); // APIにリセット用エンドポイントがあると想定
      if (res.statusCode == 200) {
        _loadGameStatus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("進捗を初期化しました")));
      }
    } catch (e) {
      // もしAPIになければローカルで初期値をセットして再読み込み
      setState(() { world = 1; stage = 1; enemyCurrentHp = 100; });
    }
  }

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
    } catch (e) { print(e); }
  }

  void _processAttack() async {
    setState(() => isMeasuring = true);
    try {
      final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
      double afterScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
      double diff = (beforeScore ?? 0) - afterScore;
      int damage = diff > 0 ? (diff * 10).toInt() : 5;

      // ダメージ演出開始（赤く光る）
      setState(() => isDamaged = true);
      Future.delayed(const Duration(milliseconds: 500), () => setState(() => isDamaged = false));

      final attackRes = await http.post(Uri.parse("$apiUrl/attack?damage=$damage"));
      if (attackRes.statusCode == 200) {
        final newData = json.decode(attackRes.body);
        setState(() {
          enemyCurrentHp = newData['current_hp'];
          if (enemyCurrentHp >= newData['max_hp'] && damage > 0) {
            _startNextStageEffect(newData);
          } else {
            _showResultDialog(diff, damage);
          }
          beforeScore = null;
          isMeasuring = false;
        });
      }
    } catch (e) { setState(() => isMeasuring = false); }
  }

  void _startNextStageEffect(Map newData) async {
    setState(() => isWalking = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      stage = newData['stage'];
      world = newData['world'];
      enemyMaxHp = newData['max_hp'];
      enemyCurrentHp = newData['max_hp'];
      isWalking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const shadowStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(blurRadius: 12, color: Colors.black87, offset: Offset(2, 2))],
    );

    return Scaffold(
      body: Stack(
        children: [
          // 背景 (.jpg)
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/background_grass.jpg'),
                fit: BoxFit.cover,
                alignment: isWalking ? const Alignment(0.8, 0.0) : const Alignment(-0.8, 0.0),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // 上部バーとリセットボタン
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40), // バランス用
                      _buildTopStatus(shadowStyle),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.white70),
                        onPressed: _resetGame,
                        tooltip: "デバッグ用リセット",
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                _buildHpBar(shadowStyle), // HPバーを上に配置
                
                const Spacer(), // ここで間を空ける
                
                if (isWalking) ...[
                  const Icon(Icons.directions_walk, size: 80, color: Colors.white),
                  Text("次の敵をさがしています...", style: shadowStyle.copyWith(fontSize: 20)),
                  const SizedBox(height: 100),
                ] else ...[
                  _buildMonsterWithAnimation(), // モンスターを下に配置
                ],
                
                const SizedBox(height: 20),
                _buildBattleButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonsterWithAnimation() {
    return AnimatedBuilder(
      animation: _pulupuluController,
      builder: (context, child) {
        double v = _pulupuluController.value;
        double scaleX = 1.0;
        double scaleY = 1.0;
        
        if (stage == 1) {
          double anim = Curves.easeInOutSine.transform(v);
          scaleY = 1.0 + (0.07 * anim);
          scaleX = 1.0 - (0.07 * anim);
        }

        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()..scale(scaleX, scaleY),
          child: ColorFiltered(
            // ダメージを受けた時に赤く光らせる演出
            colorFilter: ColorFilter.mode(
              isDamaged ? Colors.red.withOpacity(0.5) : Colors.transparent,
              BlendMode.srcATop,
            ),
            child: Image.asset(
              'assets/monster_$stage.png',
              height: 220, // 少し大きくして存在感を出す
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Icon(Icons.adb, size: 100, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopStatus(TextStyle style) {
    return Column(
      children: [
        Text("WORLD $world", style: style.copyWith(fontSize: 22, letterSpacing: 2)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            int s = i + 1;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 35, height: 35,
              decoration: BoxDecoration(
                color: s == stage ? Colors.blueAccent : (s < stage ? Colors.green : Colors.black45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(child: Text("$s", style: style.copyWith(fontSize: 14))),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHpBar(TextStyle style) {
    return Column(
      children: [
        Container(
          width: 280, height: 26,
          decoration: BoxDecoration(
            color: Colors.black45, 
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white54),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: LinearProgressIndicator(
                  value: enemyCurrentHp / enemyMaxHp,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                ),
              ),
              Text('$enemyCurrentHp / $enemyMaxHp HP', style: style.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBattleButtons() {
    return SizedBox(
      width: 320, height: 65,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: beforeScore == null ? Colors.white : Colors.orangeAccent,
          foregroundColor: beforeScore == null ? Colors.blueGrey : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
          elevation: 10,
        ),
        onPressed: isMeasuring || isWalking ? null : (beforeScore == null ? () async {
          setState(() => isMeasuring = true);
          final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
          beforeScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
          setState(() => isMeasuring = false);
        } : _processAttack),
        child: Text(
          isMeasuring ? "読み込み中..." : (beforeScore == null ? "1. 磨く前の汚れを測定" : "2. 磨き完了！こうげき！"),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showResultDialog(double diff, int damage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("結果"),
        content: Text("汚れを ${diff.toStringAsFixed(1)}% 除去！\n$damage ダメージ！"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }
}