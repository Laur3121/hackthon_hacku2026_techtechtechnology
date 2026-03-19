import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // ゲストログイン（匿名認証）
  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInAnonymously();
      if (mounted) {
        // ログイン成功後、メイン画面へ移動（ルート名は自分の設定に合わせてください）
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showErrorDialog("ゲストログインに失敗しました: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // メールアドレスでサインアップ/ログイン（簡易版）
  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      // 既存ユーザーならログイン、いなければ新規登録する流れが一般的ですが、
      // ここではシンプルにサインインを試みます
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      _showErrorDialog("ログインエラー: ${e.message}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("エラー"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アプリロゴ的なもの
              const Icon(Icons.auto_fix_high, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                "歯磨きバトルRPG",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // メールアドレス入力
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "メールアドレス",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // パスワード入力
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "パスワード",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // ログインボタン
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithEmail,
                  child: const Text("ログイン / 新規登録"),
                ),
              ),
              
              const SizedBox(height: 16),
              const Text("または"),
              const SizedBox(height: 16),

              // ゲストログインボタン
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signInAnonymously,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                  child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text("ゲストとして体験する（登録不要）"),
                ),
              ),
              
              const SizedBox(height: 20),
              const Text(
                "※ゲストの場合、データはブラウザを閉じると消える場合があります",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}