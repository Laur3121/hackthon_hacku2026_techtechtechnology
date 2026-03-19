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
  int enemyCurrentHp = 100; 
  int enemyMaxHp = 100;
  double? beforeScore;
  bool isMeasuring = false;
  bool isWalking = false; 
  bool isDamaged = false; 
  bool isDefeated = false;
  int lastDamage = 0;
  bool showDamageText = false;

  final List<String> monsterNames = [
    "スライム",     // stage 1
    "ミミック",     // stage 2
    "ミニドラゴン",     // stage 3
    "ミドルドラゴン",   // stage 4
    "ビッグドラゴン",   // stage 5
  ];

  String get currentMonsterName {
    // stageは1から始まるため、配列のインデックス（0から始まる）に合わせるために -1 します
    int index = stage - 1;
    // 用意した配列の数よりステージが進んでしまった場合の安全対策（エラー回避）
    if (index >= 0 && index < monsterNames.length) {
      return monsterNames[index];
    } else {
      return "ункноwн монстер"; // 用意した数を超えた場合のデフォルト名
    }
  }

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

  // --- デバッグ用：進捗リセット（ここをまるごと差し替え） ---
  Future<void> _resetGame() async {
    // 1. まず確認ダイアログを表示して、結果を confirm に入れる
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("進捗リセット"),
        content: const Text("サーバーのデータを初期化して、ステージ1に戻しますか？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("リセットする")),
        ],
      ),
    );

    // 2. confirm が true（リセットボタン押下）の場合のみ実行
    if (confirm == true) {
      try {
        print("Sending reset request to: $apiUrl/reset-game");
        
        // サーバーにリセットを命令
        final res = await http.post(Uri.parse("$apiUrl/reset-game"));
        
        if (res.statusCode == 200) {
          // 成功したらアプリの状態を整える
          setState(() {
            isDefeated = false;
            isWalking = false;
            beforeScore = null;
          });
          
          // サーバーの反映を少し待ってから読み込む（保険）
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadGameStatus(); 

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("サーバーと同期してリセット完了！"))
          );
        } else {
          print("Server error: ${res.body}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("サーバー側でエラーが発生しました (${res.statusCode})"))
          );
        }
      } catch (e) {
        print("Connection error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("通信エラー：APIが起動しているか確認してください"))
        );
      }
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

  // 攻撃関係
  void _processAttack() async {
    setState(() => isMeasuring = true);
    try {
      final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
      double afterScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
      double diff = (beforeScore ?? 0) - afterScore;
      // int damage = diff>0 ? diff*beforeScore.toInt() : 5;
      int damage= 10000;

      final attackRes = await http.post(Uri.parse("$apiUrl/attack?damage=$damage"));
      if (attackRes.statusCode == 200) {
        final newData = json.decode(attackRes.body);
        setState(() {
          lastDamage = damage;
          isMeasuring = false;
        });
        _showResultDialog(diff, damage, newData);
      }
    } catch (e) { setState(() => isMeasuring = false); }
  }

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

    if ((enemyCurrentHp >= newData['max_hp'] && lastDamage > 0) || enemyCurrentHp <= 0) {
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
                      fontWeight: FontWeight.w900, // Error: .black ではなく .w900 に修正済み
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
          width: 340, // ロング化
          height: 30, // 厚型
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
                  value: enemyCurrentHp / enemyMaxHp,
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