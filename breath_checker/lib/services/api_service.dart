import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = "あなたのCloudRunのURL"; // 最後に / は不要

  // 1. 自分のステータスを取得
  static Future<Map<String, dynamic>> getStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("ログインしていません");

    final response = await http.get(Uri.parse("$baseUrl/game-status/${user.uid}"));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("ステータス取得失敗");
    }
  }

  // 2. 攻撃する
  static Future<Map<String, dynamic>> attack(int damage) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("ログインしていません");

    final response = await http.post(
      Uri.parse("$baseUrl/attack"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": user.uid,
        "damage": damage,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("攻撃失敗");
    }
  }
}