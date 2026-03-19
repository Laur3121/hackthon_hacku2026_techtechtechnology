import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // 1. 追加
import 'package:firebase_database/firebase_database.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with TickerProviderStateMixin {
  // --- ユーザーID取得用のゲッター ---
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? "guest_user";

  int world = 1;
  int stage = 1;
  int enemyCurrentHp = 100; 
  int enemyMaxHp = 100;
  double? beforeScore;
  bool isMeasuring = false;
  bool isWalking = false; 
  bool isDamaged = false; 
  bool isDefeated = false;
  int lastDamage = 0;
  bool showDamageText = false;

  final List<String> monsterNames = ["スライム", "ミミック", "ミニドラゴン", "ミドルドラゴン", "ビッグドラゴン"];

  String get currentMonsterName {
    int index = stage - 1;
    if (index >= 0 && index < monsterNames.length) return monsterNames[index];
    return "未知のモンスター";
  }

  final String apiUrl = "https://breath-checker-api-476724390420.asia-northeast1.run.app";
  late AnimationController _pulupuluController;

@override
  void initState() {
    super.initState();
    _loadGameStatus(); // 最初に現在の状態をAPIから取る

    // ★ここから追加：Firebase Realtime Databaseの監視
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 自分のID専用のパスを監視する
      DatabaseReference starCountRef = 
          FirebaseDatabase.instance.ref('users/${user.uid}/status');

      starCountRef.onValue.listen((DatabaseEvent event) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            // Firebase側でHPが更新されたら、即座に画面に反映
            enemyCurrentHp = data['current_hp'] ?? enemyCurrentHp;
            enemyMaxHp = data['max_hp'] ?? enemyMaxHp;
            stage = data['stage'] ?? stage;
            world = data['world'] ?? world;
          });
        }
      });
    }
    // ★ここまで

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

  // --- 2. 自分のステータスを読み込む (UID付き) ---
  Future<void> _loadGameStatus() async {
    try {
      final res = await http.get(Uri.parse("$apiUrl/game-status/$uid")); // パス変更
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          world = data['world'] ?? 1;
          stage = data['stage'] ?? 1;
          enemyCurrentHp = data['current_hp'] ?? 100;
          enemyMaxHp = data['max_hp'] ?? 100;
        });
      }
    } catch (e) { print("Load Error: $e"); }
  }

  // --- 3. 攻撃処理 (JSONボディにUIDを入れて送る) ---
  void _processAttack() async {
    setState(() => isMeasuring = true);
    try {
      // センサー値取得
      final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
      double afterScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
      double diff = (beforeScore ?? 0) - afterScore;
      
      // ダメージ計算（ハッカソン用に固定 or 計算）
      int damage = 10000; 

      // POSTリクエストをJSON形式に変更
      final attackRes = await http.post(
        Uri.parse("$apiUrl/attack"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": uid,  // UIDを送信
          "damage": damage,
        }),
      );

      if (attackRes.statusCode == 200) {
        final newData = json.decode(attackRes.body);
        setState(() {
          lastDamage = damage;
          isMeasuring = false;
        });
        _showResultDialog(diff, damage, newData);
      }
    } catch (e) { 
      print("Attack Error: $e");
      setState(() => isMeasuring = false); 
    }
  }

  // 進捗リセットもUID対応にする
  Future<void> _resetGame() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("進捗リセット"),
        content: const Text("あなたのデータを初期化しますか？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("リセットする")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 本来はリセットAPIもUIDが必要ですが、今回は全リセット想定ならそのまま
        await http.post(Uri.parse("$apiUrl/reset-game")); 
        setState(() {
          isDefeated = false;
          isWalking = false;
          beforeScore = null;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadGameStatus(); 
      } catch (e) { print(e); }
    }
  }

  // --- 以下、演出用のコード（変更なし） ---

  void _triggerDamageEffect(Map newData) async {
    setState(() {
      isDamaged = true;
      showDamageText = true;
      enemyCurrentHp = newData['current_hp'];
    });

    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      isDamaged = false;
      showDamageText = false;
    });

    if (enemyCurrentHp <= 0) {
      setState(() => isDefeated = true);
      await Future.delayed(const Duration(milliseconds: 1000));
      _startNextStageEffect(newData);
    }
    beforeScore = null;
  }

  void _startNextStageEffect(Map newData) async {
    setState(() {
      isWalking = true;
      isDefeated = false;
    });
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      _buildTopStatus(shadowStyle),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
                        onPressed: _resetGame,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildHpBar(shadowStyle),
                const Spacer(),
                if (isWalking) ...[
                  const Icon(Icons.directions_walk, size: 80, color: Colors.white),
                  Text("次のモンスターをさがしています...", style: shadowStyle.copyWith(fontSize: 20)),
                  const SizedBox(height: 100),
                ] else ...[
                  _buildMonsterWithAnimation(shadowStyle),
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

  Widget _buildMonsterWithAnimation(TextStyle shadowStyle) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        AnimatedOpacity(
          opacity: isDefeated ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 800),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            transform: Matrix4.translationValues(0.0, isDefeated ? -100.0 : 0.0, 0.0),
            child: AnimatedBuilder(
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
                    colorFilter: ColorFilter.mode(
                      isDamaged ? Colors.red.withOpacity(0.6) : (isDefeated ? Colors.white.withOpacity(0.8) : Colors.transparent),
                      BlendMode.srcATop,
                    ),
                    child: Image.asset('assets/monster_$stage.png', height: 220, fit: BoxFit.contain),
                  ),
                );
              },
            ),
          ),
        ),
        if (showDamageText)
          Positioned(
            top: -50,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: -60.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: Text(
                    "-$lastDamage",
                    style: const TextStyle(
                      fontSize: 48,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(2, 2))],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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
          width: 340,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black54, 
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white70, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: LinearProgressIndicator(
                  value: enemyMaxHp > 0 ? enemyCurrentHp / enemyMaxHp : 0,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                ),
              ),
              Text('$enemyCurrentHp / $enemyMaxHp HP', style: style.copyWith(fontSize: 16)),
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
        onPressed: isMeasuring || isWalking || isDefeated ? null : (beforeScore == null ? () async {
          setState(() => isMeasuring = true);
          final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
          beforeScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
          setState(() => isMeasuring = false);
        } : _processAttack),
        child: Text(
          isMeasuring ? "測定中..." : (beforeScore == null ? "1. 磨く前の汚れを測定" : "2. 磨き完了！こうげき！"),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showResultDialog(double diff, int damage, Map newData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("ブラッシング完了！"),
        content: Text("汚れを ${diff.toStringAsFixed(1)}% 除去した！\n$currentMonsterName に $damage のダメージ！"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _triggerDamageEffect(newData);
            }, 
            child: const Text("OK", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }
}