import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../utils/formatters.dart';

class HRPayrollScreen extends StatefulWidget {
  final String? userId;
  final String? userRole;

  const HRPayrollScreen({super.key, this.userId, this.userRole});

  @override
  State<HRPayrollScreen> createState() => _HRPayrollScreenState();
}

class _HRPayrollScreenState extends State<HRPayrollScreen> {
  final _api = const ApiClient();
  bool _isLoading = true;
  bool _isGenerating = false;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _currency = 'USD';
  Map<String, dynamic> _allowances = {'sick': 7, 'casual': 3};
  List<dynamic> _payrolls = [];

  @override
  void initState() {
    super.initState();
    _loadPayroll();
  }

  Future<void> _loadPayroll() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _api.get('/admin/settings');
      var payrolls = await _api.get('/payroll/$_selectedMonth');
      
      if (!mounted) return;
      
      // Filter if employee
      if (widget.userRole == 'employee' && widget.userId != null) {
        payrolls = (payrolls as List).where((p) => p['employee_id'] == widget.userId).toList();
      }

      setState(() {
        _currency = settings['currency'] ?? 'USD';
        _allowances = {
          'sick': NumberFormat().parse('${settings['sickAllowance'] ?? 7}'),
          'casual': NumberFormat().parse('${settings['casualAllowance'] ?? 3}'),
        };
        _payrolls = payrolls ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payroll failed to load: $e')));
    }
  }

  Future<void> _generatePayroll() async {
    final parts = _selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final now = DateTime.now();

    if (year > now.year || (year == now.year && month > now.month)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Future payroll cannot be generated.')));
      return;
    }

    final endOfMonth = DateTime(year, month + 1, 0).day;
    if (year == now.year && month == now.month && now.day < endOfMonth) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generate current month?'),
          content: Text('This month is not over yet. Salaries will be pro-rated up to today (${now.day} days).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Generate')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isGenerating = true);
    try {
      await _api.post('/payroll/generate', {
        'selectedMonth': _selectedMonth,
        'allowances': _allowances,
      });
      await _loadPayroll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll generated successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generate failed: $e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final options = List.generate(6, (index) => DateTime(now.year, now.month - index, 1));
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final date in options)
              ListTile(
                title: Text(DateFormat('MMMM yyyy').format(date)),
                trailing: DateFormat('yyyy-MM').format(date) == _selectedMonth ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, DateFormat('yyyy-MM').format(date)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _selectedMonth = picked);
      _loadPayroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmployee = widget.userRole == 'employee';
    final totalGross = _payrolls.fold<num>(0, (sum, item) => sum + ((item['calculated_salary'] ?? 0) as num));
    final totalNet = _payrolls.fold<num>(0, (sum, item) => sum + ((item['net_salary'] ?? 0) as num));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(isEmployee ? 'My Payroll' : 'Payroll Viewer', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _pickMonth, icon: const Icon(Icons.calendar_month, color: Colors.white)),
          IconButton(onPressed: _loadPayroll, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPayroll,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (!isEmployee) ...[
                    Row(
                      children: [
                        Expanded(child: _summaryCard('Gross Expenditure', formatCurrency(totalGross, currency: _currency), Icons.payments, Colors.blue)),
                        const SizedBox(width: 16),
                        Expanded(child: _summaryCard('Net Disbursed', formatCurrency(totalNet, currency: _currency), Icons.account_balance_wallet, Colors.green)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isGenerating ? null : _generatePayroll,
                      icon: _isGenerating ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow),
                      label: Text(_isGenerating ? 'Generating $_selectedMonth' : 'Generate End of Month ($_selectedMonth)'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_payrolls.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(child: Text(isEmployee ? 'No payslip found for this month.' : 'No payroll data found for this month.', style: const TextStyle(color: Colors.white60))),
                    )
                  else
                    ..._payrolls.map((item) => _payrollCard(item)),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _payrollCard(dynamic item) {
    final gross = (item['calculated_salary'] ?? 0) as num;
    final deductions = ((item['tax_deduction'] ?? 0) as num) + ((item['pf_deduction'] ?? 0) as num) + ((item['lop_deduction'] ?? 0) as num);
    final net = (item['net_salary'] ?? (gross - deductions)) as num;
    final profile = item['profiles'] ?? {};

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
                    Text(profile['full_name'] ?? 'Unknown', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Employee ID: ${profile['id']?.toString().substring(0,8) ?? 'N/A'}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
              Text(formatCurrency(net, currency: _currency), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const Divider(height: 32, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniAmount('Gross', gross, Colors.blueAccent),
              _miniAmount('Deductions', deductions, Colors.redAccent),
              _miniAmount('Unpaid Days', item['lop_days_counted'] ?? 0, Colors.orangeAccent, money: false),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showPayslip(item),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('VIEW DETAILED PAYSLIP'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAmount(String label, num value, Color color, {bool money = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
        Text(money ? formatCurrency(value, currency: _currency) : value.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  void _showPayslip(dynamic item) {
    final deductions = ((item['tax_deduction'] ?? 0) as num) + ((item['pf_deduction'] ?? 0) as num) + ((item['lop_deduction'] ?? 0) as num);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(32),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(item['profiles']?['full_name'] ?? 'Payslip', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Payroll Cycle: $_selectedMonth', style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 32),
              _line('Basic Pay', item['basic_pay']),
              _line('HRA (House Rent)', item['hra']),
              _line('DA (Dearness)', item['da']),
              _line('Overtime Bonus', item['overtime_bonus']),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white10)),
              _line('Income Tax (TDS)', item['tax_deduction'], negative: true),
              _line('Provident Fund (PF)', item['pf_deduction'], negative: true),
              _line('Loss of Pay (LOP)', item['lop_deduction'], negative: true),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white10)),
              _line('Total Deductions', deductions, negative: true, strong: true),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: _line('Net Salary Payable', item['net_salary'], strong: true, colorOverride: Colors.greenAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, dynamic value, {bool negative = false, bool strong = false, Color? colorOverride}) {
    final amount = (value ?? 0) as num;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: strong ? FontWeight.bold : FontWeight.normal, color: strong ? Colors.white : Colors.white70, fontSize: strong ? 16 : 14)),
          Text(
            '${negative ? '- ' : ''}${formatCurrency(amount, currency: _currency)}',
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.bold, 
              color: colorOverride ?? (negative ? Colors.redAccent : (strong ? Colors.white : Colors.white)),
              fontSize: strong ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
