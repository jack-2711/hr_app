import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../utils/formatters.dart';

class HRDashboardScreen extends StatefulWidget {
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

class _HRDashboardScreenState extends State<HRDashboardScreen> {
  final _api = const ApiClient();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _pendingLeaves = [];
  List<dynamic> _pendingOvertime = [];
  List<dynamic> _alerts = [];
  List<dynamic> _chartData = [];
  String _companyName = 'HR CONNECT';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.get('/admin/dashboard');
      
      // Fetch settings for company name
      try {
        final settings = await _api.get('/admin/settings');
        _companyName = settings['orgName'] ?? 'HR CONNECT';
      } catch (e) {
        // Fallback
      }

      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _pendingLeaves = data['pendingLeaves'] ?? [];
        _pendingOvertime = data['pendingOvertime'] ?? [];
        _alerts = data['hrAlerts'] ?? [];
        _chartData = data['dynamicChartData'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dashboard failed to load: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_companyName.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w900, color: Color(0xFF6366F1))),
            const Text('Strategic Overview', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadDashboard, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
                    childAspectRatio: 1.22,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _metricCard('Live Clock-Ins', '${_stats['liveClockIns'] ?? 0} / ${_stats['activeToday'] ?? 0}', Icons.login, Colors.green),
                      _metricCard('On Break', '${_stats['onBreakToday'] ?? 0}', Icons.coffee, Colors.orange),
                      _metricCard('On Leave Today', '${_stats['onLeaveToday'] ?? 0}', Icons.event_busy, Colors.deepPurple),
                      _metricCard('MTD Payroll', formatCurrency((_stats['mtdPayroll'] ?? 0) as num), Icons.payments, Colors.blue),
                      _metricCard('LOP Savings', formatCurrency((_stats['lopSaved'] ?? 0) as num), Icons.trending_up, Colors.teal),
                      _metricCard('Employees', '${_stats['totalEmployees'] ?? 0}', Icons.groups, Colors.indigo),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionCard(
                    title: 'Seasonal Absenteeism',
                    child: Container(
                      height: 220, 
                      padding: const EdgeInsets.only(top: 20, right: 10),
                      child: _buildChart()
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionCard(
                    title: 'Action Center',
                    child: _buildActionCenter(),
                  ),
                  const SizedBox(height: 20),
                  _sectionCard(
                    title: 'Culture & HR Alerts',
                    child: _alerts.isEmpty
                        ? const Text('No birthdays, anniversaries, or probation alerts this month.', style: TextStyle(color: Colors.white60))
                        : Column(children: _alerts.map((alert) => _alertTile(alert)).toList()),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return const Center(child: Text('No chart data available.', style: TextStyle(color: Colors.white60)));
    }
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _chartData.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_chartData[index]['name'].toString().substring(0, 3), style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5))),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < _chartData.length; i++)
                FlSpot(i.toDouble(), ((_chartData[i]['attendance'] ?? 0) as num).toDouble())
            ],
            isCurved: true,
            barWidth: 4,
            color: const Color(0xFF6366F1),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true, 
              gradient: LinearGradient(
                colors: [const Color(0xFF6366F1).withOpacity(0.3), const Color(0xFF6366F1).withOpacity(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCenter() {
    final items = [..._pendingOvertime, ..._pendingLeaves];
    if (items.isEmpty) return const Text("You're all caught up. No pending requests.", style: TextStyle(color: Colors.white60));
    return Column(
      children: [
        ..._pendingOvertime.map((item) => _requestTile(
              icon: Icons.more_time,
              color: Colors.blueAccent,
              title: '${item['overtime_hours'] ?? 0}h overtime request',
              subtitle: item['profiles']?['full_name'] ?? 'Unknown employee',
            )),
        ..._pendingLeaves.map((item) => _requestTile(
              icon: Icons.beach_access,
              color: Colors.orange,
              title: '${item['leave_type'] ?? 'Leave'} request',
              subtitle: '${item['profiles']?['full_name'] ?? 'Unknown'} starts ${item['start_date'] ?? '-'}',
            )),
      ],
    );
  }

  Widget _requestTile({required IconData icon, required Color color, required String title, required String subtitle}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white24),
    );
  }

  Widget _alertTile(dynamic alert) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(backgroundColor: Color(0xFF1E293B), child: Icon(Icons.notifications_active, color: Colors.amber, size: 20)),
      title: Text(alert['name']?.toString() ?? 'Alert', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
      subtitle: Text(alert['message']?.toString() ?? '', style: const TextStyle(color: Colors.white60, fontSize: 12)),
    );
  }
}
