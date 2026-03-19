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
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final pass = _passwordController.text;
    setState(() {
      if (pass.isEmpty) {
        _passwordError = null;
      } else if (pass.length < 6) {
        _passwordError = "パスワードは6文字以上必要です";
      } else {
        _passwordError = null;
      }
    });
  }

  // --- 1. ゲストログイン ---
  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInAnonymously();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showErrorDialog("ゲストログインに失敗しました。Firebaseの設定を確認してください。");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. メールログイン / 自動新規登録 ---
  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.length < 6) return;
    
    setState(() => _isLoading = true);
    try {
      // ログインを試行
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      // ユーザーが存在しない場合は、その場で新規登録
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'user-disabled') {
        try {
          await _auth.createUserWithEmailAndPassword(email: email, password: password);
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        } catch (signUpError) {
          _showErrorDialog("新規登録に失敗しました。メール形式を確認してください。");
        }
      } else {
        _showErrorDialog("エラー: ${e.message}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("注意"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isButtonEnabled = _emailController.text.isNotEmpty && 
                          _passwordController.text.length >= 6 && 
                          !_isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_fix_high, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text("歯磨きバトルRPG", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

              // メールアドレス入力
              TextField(
                controller: _emailController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: "メールアドレス",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  hintText: "example@test.com",
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // パスワード入力
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "パスワード",
                  errorText: _passwordError,
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: "※6文字以上の英数字を入力してください",
                ),
              ),
              const SizedBox(height: 24),

              // メインログインボタン
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? _signInWithEmail : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("ログイン / 新規登録", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              
              const SizedBox(height: 30),
              
              const Text("または", style: TextStyle(color: Colors.grey)),
              
              const SizedBox(height: 10),

              // ゲストログインボタン
              TextButton(
                onPressed: _isLoading ? null : _signInAnonymously,
                child: const Text(
                  "ゲストとして体験する（登録不要）", 
                  style: TextStyle(color: Colors.blue, fontSize: 16, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}