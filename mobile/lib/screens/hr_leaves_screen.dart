import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';

class HRLeavesScreen extends StatefulWidget {
  const HRLeavesScreen({super.key});

  @override
  State<HRLeavesScreen> createState() => _HRLeavesScreenState();
}

class _HRLeavesScreenState extends State<HRLeavesScreen> {
  List<dynamic> _leaves = [];
  bool _isLoading = true;
  final _api = const ApiClient();

  @override
  void initState() {
    super.initState();
    _fetchLeaves();
  }

  Future<void> _fetchLeaves() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/admin/leaves');
      if (mounted) {
        setState(() {
          _leaves = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching leaves: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    try {
      await _api.put('/admin/leaves/$id/status', {'status': status});
      _fetchLeaves();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Leave Management", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchLeaves, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
        : _leaves.isEmpty
            ? const Center(child: Text("No pending leave requests found.", style: TextStyle(color: Colors.white38, fontSize: 16)))
            : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _leaves.length,
            itemBuilder: (context, index) {
              final leave = _leaves[index];
              final status = (leave['status'] ?? 'pending').toString().toLowerCase();
              final isPending = status == 'pending';
              
              Color statusColor = Colors.orangeAccent;
              if (status == 'approved') statusColor = Colors.greenAccent;
              if (status == 'rejected') statusColor = Colors.redAccent;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(leave['profiles']?['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.beach_access_rounded, size: 18, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(width: 12),
                          Text("CATEGORY: ${leave['leave_type'].toString().toUpperCase()}", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.date_range_rounded, size: 18, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(width: 12),
                          Text("${leave['start_date']} to ${leave['end_date']}", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                        ],
                      ),
                      if (leave['reason'] != null && leave['reason'].toString().isNotEmpty) ...[
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white10)),
                        Text("EMPLOYEE REMARKS:", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text(leave['reason'], style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                      ],
                      if (isPending) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _updateStatus(leave['id'], 'approved'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.withOpacity(0.1),
                                  foregroundColor: Colors.greenAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _updateStatus(leave['id'], 'rejected'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                                  foregroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('DECLINE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
