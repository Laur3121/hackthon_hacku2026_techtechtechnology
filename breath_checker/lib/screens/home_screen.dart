import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ← 追加

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ログアウト処理の関数
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        // ログイン画面に戻る（スタックをクリアして戻るのが安全です）
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログアウトに失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歯磨きバトル', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent, // 少し色をつけて分かりやすく
        foregroundColor: Colors.white,
        actions: [
          // ログアウトボタンを右上に配置
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView( // 念のためスクロール可能に
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // 間違えて押しちゃうのを防ぐ確認ダイアログ
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ログアウト"),
        content: const Text("ログアウトしてもよろしいですか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("キャンセル")
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ダイアログを閉じる
              _logout(context);       // ログアウト実行
            }, 
            child: const Text("ログアウト", style: TextStyle(color: Colors.red))
          ),
        ],
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