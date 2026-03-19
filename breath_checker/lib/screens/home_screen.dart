import 'package:flutter/material.dart';

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