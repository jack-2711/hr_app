import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import 'attendance_screen.dart';
import 'hr_dashboard_screen.dart';
import 'hr_employees_screen.dart';
import 'hr_leaves_screen.dart';
import 'hr_payroll_screen.dart';
import 'hr_settings_screen.dart';
import 'hr_timesheets_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String? role;
  const DashboardScreen({super.key, this.role});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = const ApiClient();
  bool _isLoading = true;
  String _userRole = 'employee';
  String _userName = 'User';
  String _companyName = 'HR CONNECT';
  bool _isRegistered = true;
  List<dynamic> _alerts = [];
  
  // Employee stats
  int _casualLeaves = 0;
  int _sickLeaves = 0;
  double _lopAmount = 0.0;
  List<dynamic> _attendanceHistory = [];
  List<dynamic> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      _userRole = widget.role ?? prefs.getString('user_role') ?? 'employee';

      if (userId == null) {
        _logout();
        return;
      }

      // 1. Fetch employee stats & registration
      final stats = await _api.get('/employee/$userId/stats');
      _isRegistered = stats['isRegistered'] ?? false;
      _casualLeaves = stats['casualLeaves'] ?? 0;
      _sickLeaves = stats['sickLeaves'] ?? 0;
      _lopAmount = (stats['lopAmount'] ?? 0).toDouble();
      _attendanceHistory = stats['attendanceHistory'] ?? [];
      _leaveRequests = stats['leaveRequests'] ?? [];

      // 2. Fetch alerts
      _alerts = await _api.get('/alerts');

      // 3. Fetch settings for company name
      try {
        final settings = await _api.get('/admin/settings');
        _companyName = settings['orgName'] ?? 'HR CONNECT';
      } catch (e) {
        _companyName = 'HR CONNECT';
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 4. Show registration prompt if not registered
      if (!_isRegistered) {
        Future.delayed(const Duration(milliseconds: 500), () => _showRegisterPrompt());
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showRegisterPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Biometric Setup Required', style: TextStyle(color: Colors.white)),
        content: const Text('To use the attendance system, you must first register your face signature.', style: TextStyle(color: Colors.white70)),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())).then((_) => _loadData());
            },
            child: const Text('Register Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHr = _userRole == 'hr' || _userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
        : CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWelcomeCard(),
                    const SizedBox(height: 32),
                    if (_alerts.isNotEmpty) ...[
                      const Text('NOTICES & ANNOUNCEMENTS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      _buildAlertsList(),
                      const SizedBox(height: 32),
                    ],
                    const Text('WORKFORCE TOOLS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    _buildActionGrid(context, isHr),
                    const SizedBox(height: 40),
                    if (!isHr) ..._buildEmployeeStatsSection(),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      backgroundColor: const Color(0xFF0F172A),
      floating: true,
      elevation: 0,
      centerTitle: false,
      title: Text(_companyName.toUpperCase(), style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white70, size: 20),
            onPressed: _logout,
          ),
        )
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366f1), Color(0xFF4f46e5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: const Color(0xFF6366f1).withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SYSTEM ACCESS GRANTED', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
                child: const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF6366f1),
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 32),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
            child: Text(_userRole.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
          )
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _alerts.length,
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          return Container(
            width: 300,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(LucideIcons.megaphone, color: Colors.orangeAccent, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(alert['title'] ?? 'Notice', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(alert['message'] ?? '', style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context, bool isHr) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final userId = snapshot.data?.getString('user_id');
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(context, 'Attendance', LucideIcons.scan_face, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen()))),
            _buildActionCard(context, 'Apply Leave', LucideIcons.calendar_plus, Colors.orange, () => _showLeaveDialog()),
            if (isHr) ...[
              _buildActionCard(context, 'HR Dashboard', LucideIcons.layout_dashboard, Colors.cyan, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HRDashboardScreen()))),
              _buildActionCard(context, 'Employees', LucideIcons.users, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HREmployeesScreen()))),
              _buildActionCard(context, 'Leave Requests', LucideIcons.calendar_check, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HRLeavesScreen()))),
              _buildActionCard(context, 'Timesheets', LucideIcons.history, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => HRTimesheetsScreen(userId: userId, userRole: _userRole)))),
              _buildActionCard(context, 'Payroll', LucideIcons.banknote, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => HRPayrollScreen(userId: userId, userRole: _userRole)))),
              _buildActionCard(context, 'Settings', LucideIcons.settings, Colors.grey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HRSettingsScreen()))),
            ],
            if (!isHr) ...[
              _buildActionCard(context, 'My Timesheet', LucideIcons.history, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => HRTimesheetsScreen(userId: userId, userRole: _userRole)))),
              _buildActionCard(context, 'My Payroll', LucideIcons.banknote, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => HRPayrollScreen(userId: userId, userRole: _userRole)))),
            ],
          ],
        );
      }
    );
  }

  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmployeeStatsSection() {
    return [
      const Text("PERSONAL ANALYTICS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildStatCard("CASUAL LEAVES", "$_casualLeaves / 12", Colors.blue)),
          const SizedBox(width: 16),
          Expanded(child: _buildStatCard("SICK LEAVES", "$_sickLeaves / 6", Colors.orange)),
        ],
      ),
      const SizedBox(height: 16),
      _buildStatCard("LOP DEDUCTIONS", formatCurrency(_lopAmount), Colors.redAccent),
      const SizedBox(height: 40),
      const Text("WORK HOURS TREND", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
      const SizedBox(height: 16),
      _buildWorkHoursChart(),
      const SizedBox(height: 40),
      const Text("LEAVE STATUS", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
      const SizedBox(height: 16),
      _buildLeaveRequestsList(),
    ];
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color.withOpacity(0.7), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildWorkHoursChart() {
    final history = _attendanceHistory.take(7).toList().reversed.toList();
    if (history.isEmpty) return const Text('No attendance data available.', style: TextStyle(color: Colors.white38));

    return Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: BarChart(
        BarChartData(
          maxY: 12,
          barGroups: [
            for (var i = 0; i < history.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: (history[i]['working_hours'] ?? 0.0).toDouble(), 
                  color: const Color(0xFF6366F1), 
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: 12, color: Colors.white.withOpacity(0.05)),
                )
              ]),
          ],
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildLeaveRequestsList() {
    if (_leaveRequests.isEmpty) return const Text('No recent leave requests', style: TextStyle(color: Colors.white38));
    return Column(
      children: _leaveRequests.take(3).map((leave) {
        final status = (leave['status'] ?? 'pending').toString().toLowerCase();
        final color = status == 'approved' ? Colors.greenAccent : (status == 'rejected' ? Colors.redAccent : Colors.orangeAccent);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text('${leave['leave_type'].toString().toUpperCase()} LEAVE', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${leave['start_date']} to ${leave['end_date']}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10)),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showLeaveDialog() {
    final reasonController = TextEditingController();
    String selectedType = 'casual';
    DateTime? start;
    DateTime? end;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setS) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Apply for Leave', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                items: const [DropdownMenuItem(value: 'casual', child: Text('Casual')), DropdownMenuItem(value: 'sick', child: Text('Sick'))],
                onChanged: (v) => setS(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                   final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                   if (d != null) setS(() => start = d);
                },
                child: Text(start == null ? 'Start Date' : formatDate(start!.toIso8601String())),
              ),
              OutlinedButton(
                onPressed: () async {
                   final d = await showDatePicker(context: context, firstDate: start ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                   if (d != null) setS(() => end = d);
                },
                child: Text(end == null ? 'End Date' : formatDate(end!.toIso8601String())),
              ),
              TextField(controller: reasonController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Reason', labelStyle: TextStyle(color: Colors.white70))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await _api.post('/employee/leave', {
                'employee_id': prefs.getString('user_id'),
                'leave_type': selectedType,
                'start_date': start!.toIso8601String().split('T')[0],
                'end_date': end!.toIso8601String().split('T')[0],
                'reason': reasonController.text,
              });
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Submit'),
          )
        ],
      )),
    );
  }
}
