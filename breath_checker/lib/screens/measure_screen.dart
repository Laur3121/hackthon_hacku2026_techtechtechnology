import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  // APIから取得するデータ
  double _diff = 0.0;
  double _temp = 0.0;
  double _hum = 0.0;
  double _gas = 0.0;
  
  Timer? _timer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 1秒ごとにAPIを叩いて最新の状態に更新する
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _fetchSensorData());
  }

  Future<void> _fetchSensorData() async {
    try {
      // あなたがデプロイした Cloud Run の URL
      final url = 'https://breath-checker-api-476724390420.asia-northeast1.run.app/check-firebase';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sensor = data['firebase_data'];

        setState(() {
          _diff = double.parse(sensor['diff_percent'].toString());
          _temp = double.parse(sensor['temperature'].toString());
          _hum  = double.parse(sensor['humidity'].toString());
          _gas  = double.parse(sensor['gas_resistance'].toString());
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("API取得エラー: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // 画面を離れたら通信を止める（大事！）
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 数値チェック'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) // ロード中
        : SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Text('現在の汚れ度 (攻撃力)', style: TextStyle(fontSize: 18)),
                
                // メインの大きな数字
                Text(
                  '${_diff.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 80, 
                    fontWeight: FontWeight.bold, 
                    color: _diff > 20 ? Colors.redAccent : Colors.blueAccent
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Divider(height: 40),
                ),

                // サブ情報のカード
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoCard('温度', '${_temp.toStringAsFixed(1)}℃', Icons.thermostat, Colors.orange),
                      _infoCard('湿度', '${_hum.toStringAsFixed(1)}%', Icons.water_drop, Colors.blue),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                _infoCard('ガス抵抗値', '${_gas.toStringAsFixed(1)} kΩ', Icons.air, Colors.green),
                
                const SizedBox(height: 50),
                
                // 状態メッセージ
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _diff > 20 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _diff > 20 ? '⚠️ 強力なブレスを検知！バトルで大ダメージ！' : '✅ 空気はクリーンです。',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold, 
                      color: _diff > 20 ? Colors.red : Colors.green
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // 小さな情報カードの部品
  Widget _infoCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}