import 'package:flutter/material.dart';

class Enemy {
  final String name;
  final String imagePath;
  final int maxHp;

  Enemy({
    required this.name,
    required this.imagePath,
    required this.maxHp,
  });
}

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  final List<Enemy> _enemies = [
    Enemy(name: 'むしばきん', imagePath: 'assets/リアルなちいさいかわいいドラゴン.png', maxHp: 100),
    Enemy(name: 'よごれスライム', imagePath: 'assets/リアルなかわいいドラゴン.png', maxHp: 150),
    Enemy(name: 'ボス・シコウ', imagePath: 'assets/かっこいいドラゴン（黒色）.png', maxHp: 500),
  ];

  int _currentIndex = 0;
  late int _currentHp;

  @override
  void initState() {
    super.initState();
    _currentHp = _enemies[_currentIndex].maxHp;
  }

  @override
  Widget build(BuildContext context) {
    final currentEnemy = _enemies[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('⚔️ バトル')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${currentEnemy.name} が あらわれた！',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Image.asset(
              currentEnemy.imagePath,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, exception, stackTrace) {
                return SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: Text(
                      '${currentEnemy.name}の\n画像が見つかりません',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Text(
              '敵のHP: $_currentHp / ${currentEnemy.maxHp}',
              style: const TextStyle(fontSize: 20, color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}