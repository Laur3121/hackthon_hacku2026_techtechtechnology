import 'package:flutter/material.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // 軽くフワフワ浮くアニメーションのコントローラー
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 画面サイズ取得
    final size = MediaQuery.of(context).size;
    
    // PCやスマホにかかわらず、モンスターが大きすぎず小さすぎないように幅を計算
    // 画面幅の35%、ただし最小120px、最大220pxに制限
    final double baseMonsterSize = math.max(120.0, math.min(size.width * 0.35, 220.0));

    return Scaffold(
      body: Stack(
        children: [
          // 1. 背景画像
          Positioned.fill(
            child: Image.asset(
              'assets/background_castle.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 2. モンスターたちの配置 (PC・スマホ両対応のため Align を使用)
          
          // 上部中央: イエローのドラゴン？ (monster_1 を想定)
          _buildFloatingMonster(
            context: context,
            asset: 'assets/monster_1.png',
            alignment: const Alignment(0.0, -0.9), // X:中央 Y:上端寄り
            width: baseMonsterSize * 1.2, // トップのモンスターは少し大きめに
            delay: 0.0,
          ),
          
          // 左側: レッドのドラゴン？ (monster_2)
          _buildFloatingMonster(
            context: context,
            asset: 'assets/monster_2.png',
            alignment: const Alignment(-0.8, -0.2), // X:左寄り Y:少し上
            width: baseMonsterSize,
            delay: 0.5,
          ),

          // 右側: ダークドラゴン？ (monster_4)
          _buildFloatingMonster(
            context: context,
            asset: 'assets/monster_4.png',
            alignment: const Alignment(0.8, -0.2), // X:右寄り Y:少し上
            width: baseMonsterSize,
            delay: 1.0,
          ),

          // 左下: スライム？ (monster_3)
          _buildFloatingMonster(
            context: context,
            asset: 'assets/monster_3.png',
            alignment: const Alignment(-0.6, 0.45), // X:やや左 Y:下寄り
            width: baseMonsterSize * 0.9,
            delay: 1.5,
          ),

          // 右下: 宝箱？ (monster_5)
          _buildFloatingMonster(
            context: context,
            asset: 'assets/monster_5.png',
            alignment: const Alignment(0.6, 0.5), // X:やや右 Y:下寄り
            width: baseMonsterSize * 1.1,
            delay: 0.8,
          ),

          // 3. タイトルテキスト (中央)
          Align(
            alignment: const Alignment(0.0, -0.1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOutlinedText('口臭王者', Colors.yellow, 48),
                _buildOutlinedText('歯磨キング', Colors.red, 48),
              ],
            ),
          ),

          // 4. 黒い下部の半円形
          // 画面下部に黒い円を配置してカーブを作る
          Positioned(
            bottom: -size.height * 0.3,
            left: -size.width * 0.5,
            right: -size.width * 0.5,
            height: size.height * 0.5,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 5. 下部の3つの丸いボタン
          Align(
            alignment: const Alignment(0.0, 0.95), // 下端に寄せる
            child: Row(
              mainAxisSize: MainAxisSize.min, // 3つのボタンを中央に固める
              crossAxisAlignment: CrossAxisAlignment.end, // 中央のボタンを少し上にずらすため
              children: [
                // 数値チェックボタン (黄)
                _buildCircleButton(
                  context: context,
                  title: '数値\nチェック',
                  color: Colors.amber,
                  size: 90,
                  routeName: '/measure',
                ),
                SizedBox(width: math.min(size.width * 0.03, 20.0)),
                
                // バトル開始ボタン (赤) - 中央なので少し大きく上に配置
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: _buildCircleButton(
                    context: context,
                    title: 'バトル\n開始',
                    color: Colors.red,
                    size: 110, // 少し大きい
                    routeName: '/battle',
                    isBold: true,
                  ),
                ),
                SizedBox(width: math.min(size.width * 0.03, 20.0)),

                // 履歴ボタン (緑)
                _buildCircleButton(
                  context: context,
                  title: '履歴',
                  color: const Color(0xFF00B050), // 緑
                  size: 90,
                  routeName: '/history',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// モックアップに合わせた黒フチ付きテキストを作成
  Widget _buildOutlinedText(String text, Color textColor, double fontSize) {
    return Stack(
      children: [
        // フチ取り用テキスト(太い黒)
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = Colors.black,
          ),
        ),
        // 内側のテキスト(色付き)
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  /// フワフワ動くモンスターウィジェットを生成 (Align を使って相対的な位置に配置)
  Widget _buildFloatingMonster({
    required BuildContext context,
    required String asset,
    required Alignment alignment,
    required double width,
    required double delay,
  }) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // 遅延(位相)をつけてそれぞれがバラバラに動くように
          final double offset = math.sin((_animationController.value * 2 * math.pi) + delay) * 10;
          return Transform.translate(
            offset: Offset(0, offset),
            child: SizedBox(
              width: width,
              child: Image.asset(asset, fit: BoxFit.contain), 
            ),
          );
        },
      ),
    );
  }

  /// 真ん丸のメニューボタン
  Widget _buildCircleButton({
    required BuildContext context,
    required String title,
    required Color color,
    required double size,
    required String routeName,
    bool isBold = false,
  }) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, routeName),
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}