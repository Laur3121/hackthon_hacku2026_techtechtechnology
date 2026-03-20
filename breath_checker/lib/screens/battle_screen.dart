import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with TickerProviderStateMixin {
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
  bool isAnimatingAttack = false;
  
  int countdown = 0;
  String measuringStatus = "";

  final String apiUrl = "https://breath-checker-api-476724390420.asia-northeast1.run.app";
  
  late AnimationController _pulupuluController;
  late AnimationController _ascentController;

  @override
  void initState() {
    super.initState();
    _loadGameStatus();
    _setupFirebaseListener();

    _pulupuluController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ascentController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  void _setupFirebaseListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseReference starCountRef = FirebaseDatabase.instance.ref('users/${user.uid}/status');
      starCountRef.onValue.listen((DatabaseEvent event) {
        if (event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          if (mounted && !isAnimatingAttack) {
            setState(() {
              enemyCurrentHp = data['current_hp'] ?? enemyCurrentHp;
              enemyMaxHp = data['max_hp'] ?? enemyMaxHp;
              stage = data['stage'] ?? stage;
              world = data['world'] ?? world;
            });
          }
        }
      });
    }
  }

  Future<void> _loadGameStatus() async {
    try {
      final res = await http.get(Uri.parse("$apiUrl/game-status/$uid"));
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

  // --- 測定開始 (磨く前・攻撃時 共通) ---
  void _startMeasurement(bool isBeforeAttack) async {
    setState(() {
      isMeasuring = true;
      countdown = 8; // 8秒間、息を吐く時間を与える
      measuringStatus = isBeforeAttack 
          ? "【磨く前】の息を測定中...\nセンサーにゆっくり吐き続けて！" 
          : "【磨き後】の息を測定中...\n汚れを吹き飛ばせ！";
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 0) {
        setState(() => countdown--);
      } else {
        timer.cancel();
        if (isBeforeAttack) {
          _getInitialScore();
        } else {
          _processAttack();
        }
      }
    });
  }

  void _getInitialScore() async {
    setState(() => measuringStatus = "データを受信中...");
    try {
      final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
      setState(() {
        beforeScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
        isMeasuring = false;
      });
      _showSimpleDialog("準備完了", "今の状態を記録しました。さあ、歯を磨いてください！");
    } catch (e) { setState(() => isMeasuring = false); }
  }

  void _processAttack() async {
    setState(() {
      measuringStatus = "ダメージ計算中...";
      isAnimatingAttack = true;
    });
    try {
      final res = await http.get(Uri.parse("$apiUrl/check-firebase"));
      double afterScore = double.parse(json.decode(res.body)['firebase_data']['diff_percent'].toString());
      double diff = (beforeScore ?? 0) - afterScore;
      
      // ダメージ計算：減少率 × 係数
      int damage = (diff * beforeScore!).toInt(); 
      if (damage < 10) damage = 1000; 

      final attackRes = await http.post(
        Uri.parse("$apiUrl/attack"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": uid, "damage": damage}),
      );

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

  void _showResultDialog(double diff, int damage, Map newData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("ブラッシング終了！"),
        content: Text("汚れ除去率: ${diff.toStringAsFixed(1)}%\nモンスターに $damage のダメージ！"),
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

  void _triggerDamageEffect(Map newData) async {
    bool died = (enemyCurrentHp - lastDamage) <= 0;

    setState(() {
      isDamaged = true;
      showDamageText = true;
      if (!died) {
        enemyCurrentHp = newData['current_hp'] ?? enemyCurrentHp;
      } else {
        enemyCurrentHp = 0;
      }
    });

    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      isDamaged = false;
      showDamageText = false;
    });

    if (died) {
      setState(() => isDefeated = true);
      _ascentController.forward(); // 昇天アニメーション
      await Future.delayed(const Duration(seconds: 2));
      _startNextStageEffect(newData);
    } else {
      setState(() => isAnimatingAttack = false);
    }
    beforeScore = null;
  }

  void _startNextStageEffect(Map newData) async {
    setState(() => isWalking = true);
    _ascentController.reset();
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      stage = newData['stage'];
      world = newData['world'];
      enemyMaxHp = newData['max_hp'];
      enemyCurrentHp = newData['max_hp'];
      isWalking = false;
      isDefeated = false;
      isAnimatingAttack = false;
    });
  }

  void _showSimpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildBattleUI(),
          if (isMeasuring) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedContainer(
      duration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/background_grass.jpg'),
          fit: BoxFit.cover,
          alignment: isWalking ? const Alignment(0.8, 0.0) : const Alignment(-0.8, 0.0),
        ),
      ),
    );
  }

  Future<void> _resetGame() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("データを初期化"),
        content: const Text("ゲームの進捗を最初からやり直しますか？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("キャンセル")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("はい", style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 全リセットAPIをコール
        final res = await http.post(Uri.parse("$apiUrl/reset-game"));
        if (res.statusCode == 200) {
          _loadGameStatus();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("進捗を初期化しました", style: TextStyle(color: Colors.white)))
            );
          }
        }
      } catch (e) {
        print("Reset error: $e");
      }
    }
  }

  Widget _buildBattleUI() {
    const shadowStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(blurRadius: 12, color: Colors.black87, offset: Offset(2, 2))],
    );

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildTopStatus(shadowStyle),
              ),
              _buildHpBar(shadowStyle),
              const Spacer(),
              if (isWalking) 
                _buildWalkingInfo(shadowStyle)
              else 
                _buildMonsterDisplay(shadowStyle),
              const SizedBox(height: 20),
              _buildBattleButtons(),
              const SizedBox(height: 40),
            ],
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
              tooltip: "データを初期化",
              onPressed: _resetGame,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildMonsterDisplay(TextStyle shadowStyle) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // 1. 昇天用のアニメーションBuilder
        AnimatedBuilder(
          animation: _ascentController,
          builder: (context, child) {
            double verticalOffset = -_ascentController.value * 300;
            double opacity = 1.0 - _ascentController.value;

            // 2. ぷるぷる用のアニメーションBuilder（入れ子にする）
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, verticalOffset),
                child: AnimatedBuilder(
                  animation: _pulupuluController,
                  builder: (context, child) {
                    // スライムっぽい弾力を出す計算
                    double v = _pulupuluController.value;
                    double anim = Curves.easeInOutSine.transform(v);
                    double scaleY = 1.0 + (0.07 * anim); // 縦に伸びる
                    double scaleX = 1.0 - (0.07 * anim); // 横に縮む

                    return Transform(
                      alignment: Alignment.bottomCenter,
                      transform: Matrix4.identity()..scale(scaleX, scaleY),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          isDamaged ? Colors.red.withOpacity(0.6) : Colors.transparent,
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          'assets/monster_$stage.png', 
                          height: stage == 5 ? 400 : 220,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        // ダメージテキスト
        if (showDamageText)
          Positioned(
            top: -50, 
            child: Text(
              "-$lastDamage", 
              style: const TextStyle(
                fontSize: 48, 
                color: Colors.redAccent, 
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)]
              )
            )
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
          elevation: 8,
        ),
        onPressed: isMeasuring || isWalking || isDefeated ? null : () => _startMeasurement(beforeScore == null),
        child: Text(
          beforeScore == null ? "1. 磨く前の汚れを測定" : "2. 磨き完了！こうげき！",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildTopStatus(TextStyle style) {
    return Column(
      children: [
        Text("WORLD $world", style: style.copyWith(fontSize: 22)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 30, height: 30,
            decoration: BoxDecoration(color: (i + 1) == stage ? Colors.blue : Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
            child: Center(child: Text("${i + 1}", style: style.copyWith(fontSize: 12))),
          )),
        ),
      ],
    );
  }

  Widget _buildHpBar(TextStyle style) {
    return Container(
      width: 300, height: 25,
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white30)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          LinearProgressIndicator(
            value: enemyMaxHp > 0 ? enemyCurrentHp / enemyMaxHp : 0,
            backgroundColor: Colors.transparent,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
          Text('$enemyCurrentHp / $enemyMaxHp HP', style: style.copyWith(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildWalkingInfo(TextStyle style) {
    return Column(
      children: [
        const Icon(Icons.directions_walk, size: 80, color: Colors.white),
        Text("次のモンスターをさがしています...", style: style.copyWith(fontSize: 18)),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      // Colors.black90 ではなく、透明度を指定した黒を使います
      color: Colors.black.withOpacity(0.9),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blueAccent, strokeWidth: 6),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              measuringStatus, 
              textAlign: TextAlign.center, 
              style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ),
          const SizedBox(height: 30),
          // カウントダウンの数字
          Text(
            "$countdown", 
            style: const TextStyle(
              fontSize: 120, 
              color: Colors.orangeAccent, 
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 20, color: Colors.orange)]
            )
          ),
          const SizedBox(height: 20),
          const Text(
            "センサーがあなたの息を解析中...", 
            style: TextStyle(color: Colors.white70, fontSize: 16)
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulupuluController.dispose();
    _ascentController.dispose();
    super.dispose();
  }
}