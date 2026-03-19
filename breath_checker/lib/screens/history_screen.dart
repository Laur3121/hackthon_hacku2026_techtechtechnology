import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> battleLogs = [];
  bool isLoading = true;
  bool showChart = false; // 表とグラフの切り替え用

  // APIのベースURL
  final String apiUrl = "https://breath-checker-api-476724390420.asia-northeast1.run.app";

  @override
  void initState() {
    super.initState();
    _fetchBattleHistory();
  }

  // PostgreSQLから戦闘ログを取得
  Future<void> _fetchBattleHistory() async {
    try {
      final res = await http.get(Uri.parse("$apiUrl/battle-history"));
      if (res.statusCode == 200) {
        setState(() {
          battleLogs = json.decode(res.body);
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load history");
      }
    } catch (e) {
      print("Error fetching history: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("冒険の記録", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(showChart ? Icons.format_list_bulleted : Icons.show_chart),
            onPressed: () => setState(() => showChart = !showChart),
            tooltip: showChart ? "リスト表示" : "グラフ表示",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : battleLogs.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSummaryHeader(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: showChart ? _buildChartView() : _buildListView(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_fix_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("まだ戦闘の記録がありません。\nハミガキをして敵を攻撃しよう！",
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueAccent.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("総戦闘数", "${battleLogs.length}回"),
          _buildStatItem("最大ダメージ", "${_getMaxDamage()}"),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
      ],
    );
  }

  // --- リスト表示 ---
  Widget _buildListView() {
    return ListView.builder(
      key: const ValueKey("list"),
      padding: const EdgeInsets.all(8),
      itemCount: battleLogs.length,
      itemBuilder: (context, index) {
        final log = battleLogs[index];
        final DateTime date = DateTime.parse(log['created_at']).toLocal();
        final String timeStr = DateFormat('MM/dd HH:mm').format(date);
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orangeAccent,
              child: Text("${log['stage']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text("STAGE ${log['stage']} へ攻撃！", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(timeStr),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("-${log['damage']} HP", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("除去率: ${log['diff_percent']}%", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- グラフ表示（修正済） ---
  Widget _buildChartView() {
    if (battleLogs.length < 2) {
      return const Center(child: Text("グラフを表示するには少なくとも2回以上の戦闘が必要です"));
    }

    List<FlSpot> damageSpots = [];
    final sortedLogs = battleLogs.reversed.toList();
    for (int i = 0; i < sortedLogs.length; i++) {
      damageSpots.add(FlSpot(i.toDouble(), (sortedLogs[i]['damage'] as num).toDouble()));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 24, 16),
      child: LineChart(
        key: const ValueKey("chart"),
        LineChartData(
          lineBarsData: [
            // LineChartBarData（単数形）に修正
            LineChartBarData(
              spots: damageSpots,
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.redAccent.withOpacity(0.1)),
            ),
          ],
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
              axisNameWidget: Text("ダメージ量"),
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text("戦闘回数（左が古い）"),
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  int _getMaxDamage() {
    if (battleLogs.isEmpty) return 0;
    return battleLogs.map((e) => e['damage'] as int).reduce((a, b) => a > b ? a : b);
  }
}