import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../utils/formatters.dart';

class HRTimesheetsScreen extends StatefulWidget {
  final String? userId;
  final String? userRole;

  const HRTimesheetsScreen({super.key, this.userId, this.userRole});

  @override
  State<HRTimesheetsScreen> createState() => _HRTimesheetsScreenState();
}

class _HRTimesheetsScreenState extends State<HRTimesheetsScreen> {
  final _api = const ApiClient();
  final _searchController = TextEditingController();
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _records = [];
  Map<String, dynamic> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadTimesheets();
  }

  Future<void> _loadTimesheets() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.get('/admin/timesheets');
      final settings = await _api.get('/admin/settings');
      if (!mounted) return;
      setState(() {
        _records = data ?? [];
        _settings = Map<String, dynamic>.from(settings ?? {});
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timesheets failed to load: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmployee = widget.userRole == 'employee';
    final selectedDay = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final query = _searchController.text.trim().toLowerCase();
    
    final filtered = _records.where((record) {
      final createdAt = record['created_at']?.toString() ?? '';
      final name = record['profiles']?['full_name']?.toString().toLowerCase() ?? '';
      final email = record['profiles']?['email']?.toString().toLowerCase() ?? '';
      
      // Filter by user if employee
      if (isEmployee && record['employee_id'] != widget.userId) return false;
      
      return createdAt.startsWith(selectedDay) && (query.isEmpty || name.contains(query) || email.contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(isEmployee ? 'My Timesheet' : 'Global Timesheets', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_month, color: Colors.white)),
          IconButton(onPressed: _loadTimesheets, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTimesheets,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (!isEmployee)
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by employee name or email',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          child: TextButton(
                            onPressed: _pickDate, 
                            style: TextButton.styleFrom(backgroundColor: const Color(0xFF6366F1).withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: Text(DateFormat('MMM d').format(_selectedDate), style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold))
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                  if (isEmployee)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        child: TextButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month, color: Color(0xFF6366F1)),
                          label: Text('Viewing: ${DateFormat('MMMM d, yyyy').format(_selectedDate)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(child: Text(isEmployee ? 'No records for this date.' : 'No attendance records found for this date.', style: const TextStyle(color: Colors.white60))),
                    )
                  else
                    ...filtered.map((record) => _recordCard(record)),
                ],
              ),
            ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF6366F1), onPrimary: Colors.white, surface: Color(0xFF1E293B), onSurface: Colors.white),
          dialogBackgroundColor: const Color(0xFF0F172A),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _recordCard(dynamic record) {
    final profile = record['profiles'] ?? {};
    final isLate = _isLate(record);
    final isHalfDay = _isHalfDay(record);
    final leftEarly = _leftEarly(record);
    final overtime = _overtime(record);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
              CircleAvatar(
                backgroundColor: const Color(0xFF0F172A),
                child: Text(
                  (profile['full_name']?.toString().isNotEmpty ?? false) ? profile['full_name'][0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    Text(formatDate(record['created_at']), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              _pill(Icons.login, 'In: ${formatTime(record['clock_in'])}', isLate ? Colors.redAccent : Colors.greenAccent),
              _pill(Icons.logout, record['clock_out'] == null ? 'Shift Active' : 'Out: ${formatTime(record['clock_out'])}', leftEarly ? Colors.redAccent : Colors.blueGrey),
              _pill(Icons.coffee, 'Break: ${formatHours(record['total_break_duration'])}', Colors.orangeAccent),
              _pill(Icons.timer, 'Working: ${formatHours(record['working_hours'])}', const Color(0xFF6366F1)),
              if (isLate) _pill(Icons.warning_amber_rounded, 'Late Entry', Colors.redAccent),
              if (isHalfDay) _pill(Icons.event_busy, 'Half Day Penalty', Colors.redAccent),
              if (overtime != null) _pill(Icons.more_time, '+$overtime Overtime', Colors.tealAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  bool _isLate(dynamic record) {
    final start = record['standard_start_time'] ?? _settings['workStart'];
    final clockIn = record['clock_in'];
    if (start == null || clockIn == null) return false;
    final grace = int.tryParse('${record['grace_period'] ?? _settings['gracePeriod'] ?? 0}') ?? 0;
    return _minutesSinceMidnight(clockIn) > _settingsMinutes(start) + grace;
  }

  bool _isHalfDay(dynamic record) {
    final start = record['standard_start_time'] ?? _settings['workStart'];
    final clockIn = record['clock_in'];
    if (start == null || clockIn == null) return false;
    final threshold = int.tryParse('${record['half_day_late_threshold'] ?? _settings['halfDayLateThreshold'] ?? 60}') ?? 60;
    return _minutesSinceMidnight(clockIn) > _settingsMinutes(start) + threshold;
  }

  bool _leftEarly(dynamic record) {
    final end = record['standard_end_time'] ?? _settings['workEnd'];
    final clockOut = record['clock_out'];
    if (end == null || clockOut == null) return false;
    return _minutesSinceMidnight(clockOut) < _settingsMinutes(end);
  }

  String? _overtime(dynamic record) {
    final start = record['standard_start_time'] ?? _settings['workStart'];
    final end = record['standard_end_time'] ?? _settings['workEnd'];
    final hours = (record['working_hours'] as num?)?.toDouble();
    if (start == null || end == null || hours == null) return null;
    final standard = (_settingsMinutes(end) - _settingsMinutes(start)) / 60;
    final overtime = hours - standard;
    return overtime > 0.25 ? formatHours(overtime) : null;
  }

  int _settingsMinutes(dynamic value) {
    final parts = value.toString().split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1];
  }

  int _minutesSinceMidnight(String iso) {
    final date = DateTime.parse(iso).toLocal();
    return date.hour * 60 + date.minute;
  }
}
