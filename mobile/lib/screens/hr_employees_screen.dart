import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../utils/formatters.dart';

class HREmployeesScreen extends StatefulWidget {
  const HREmployeesScreen({super.key});

  @override
  State<HREmployeesScreen> createState() => _HREmployeesScreenState();
}

class _HREmployeesScreenState extends State<HREmployeesScreen> {
  final _api = const ApiClient();
  List<dynamic> _employees = [];
  Map<String, dynamic> _leavesTaken = {};
  num _maxLeaves = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/admin/employees');
      if (!mounted) return;
      setState(() {
        _employees = response['employees'] ?? [];
        _leavesTaken = Map<String, dynamic>.from(response['leavesTaken'] ?? {});
        _maxLeaves = (response['maxLeaves'] ?? 0) as num;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Employees failed to load: $e')));
    }
  }

  Future<void> _editEmployee(Map<String, dynamic> emp) async {
    final nameController = TextEditingController(text: emp['full_name'] ?? '');
    final emailController = TextEditingController(text: emp['email'] ?? '');
    final rateController = TextEditingController(text: emp['per_day_rate']?.toString() ?? '0');
    final baseController = TextEditingController(text: emp['base_salary']?.toString() ?? '');
    final role = ValueNotifier<String>(emp['role'] ?? 'employee');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Edit Employee', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameController, 'Full Name'),
              _dialogField(emailController, 'Email Address'),
              ValueListenableBuilder<String>(
                valueListenable: role,
                builder: (context, value, _) => DropdownButtonFormField<String>(
                  value: value,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: 'Role', labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'hr', child: Text('HR')),
                  ],
                  onChanged: (next) => role.value = next ?? 'employee',
                ),
              ),
              const SizedBox(height: 12),
              _dialogField(rateController, 'Per Day Rate', keyboard: TextInputType.number),
              _dialogField(baseController, 'Base Salary', keyboard: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _api.put('/admin/employees/${emp['id']}', {
                  'full_name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'role': role.value,
                  'per_day_rate': double.tryParse(rateController.text),
                  'base_salary': double.tryParse(baseController.text),
                });
                if (!mounted) return;
                Navigator.pop(context);
                _fetchEmployees();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addEmployee() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final rateController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Provision Employee', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameController, 'Full Name'),
              _dialogField(emailController, 'Email Address'),
              _dialogField(passwordController, 'Temporary Password', obscure: true),
              _dialogField(rateController, 'Per Day Rate', keyboard: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await _api.post('/admin/employees', {
                  'full_name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'password': passwordController.text.trim(),
                  'role': 'employee',
                  'per_day_rate': double.tryParse(rateController.text) ?? 0,
                });
                if (!mounted) return;
                Navigator.pop(context);
                _fetchEmployees();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Provision failed: $e')));
              }
            },
            child: const Text('Provision'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Corporate Ledger', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchEmployees, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchEmployees,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _employees.length,
                itemBuilder: (context, index) {
                  final emp = _employees[index];
                  final isHr = emp['role'] == 'hr';
                  final taken = (_leavesTaken[emp['id']] ?? 0) as num;
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
                              radius: 24,
                              backgroundColor: const Color(0xFF0F172A),
                              child: Text(
                                emp['full_name']?.substring(0, 1).toUpperCase() ?? 'U',
                                style: TextStyle(color: isHr ? const Color(0xFF6366F1) : Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(emp['full_name'] ?? 'Unknown Employee', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text('${emp['role'].toString().toUpperCase()} • ${emp['email']}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                              child: IconButton(onPressed: () => _editEmployee(emp), icon: const Icon(Icons.edit_note, color: Color(0xFF6366F1), size: 24)),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(height: 1, color: Colors.white10),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _miniStat('Standard Daily Rate', formatCurrency((emp['per_day_rate'] ?? 0) as num)),
                            _miniStat('Annual Leaves Taken', '${_formatNumber(taken)} / ${_formatNumber(_maxLeaves)}'),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: _addEmployee,
        elevation: 10,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('PROVISION EMPLOYEE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
      ),
    );
  }

  String _formatNumber(num value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)),
      ],
    );
  }

  Widget _dialogField(TextEditingController controller, String label, {TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label, 
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
