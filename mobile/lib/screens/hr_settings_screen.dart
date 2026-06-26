import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_client.dart';

class HRSettingsScreen extends StatefulWidget {
  const HRSettingsScreen({super.key});

  @override
  State<HRSettingsScreen> createState() => _HRSettingsScreenState();
}

class _HRSettingsScreenState extends State<HRSettingsScreen> {
  final _api = const ApiClient();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  String _currency = 'USD';
  String _timezone = 'UTC';

  final _controllers = <String, TextEditingController>{
    'orgName': TextEditingController(text: 'Acme Corp'),
    'industry': TextEditingController(text: 'Technology'),
    'workStart': TextEditingController(text: '09:00'),
    'workEnd': TextEditingController(text: '17:00'),
    'gracePeriod': TextEditingController(text: '15'),
    'halfDayLateThreshold': TextEditingController(text: '60'),
    'sickAllowance': TextEditingController(text: '7'),
    'casualAllowance': TextEditingController(text: '3'),
    'geofenceLat': TextEditingController(text: '0'),
    'geofenceLng': TextEditingController(text: '0'),
    'geofenceRadius': TextEditingController(text: '500'),
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await _api.get('/admin/settings');
      if (!mounted) return;
      setState(() {
        for (final entry in _controllers.entries) {
          if (data[entry.key] != null) entry.value.text = data[entry.key].toString();
        }
        _currency = data['currency'] ?? 'USD';
        _timezone = data['timezone'] ?? 'UTC';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Settings failed to load: $e')));
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _api.post('/admin/settings', {
        for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
        'currency': _currency,
        'timezone': _timezone,
        'vacationAllowance': '14',
        'emailAlerts': true,
        'pushAlerts': false,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings synchronized globally.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission is required.')));
      return;
    }
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _controllers['geofenceLat']!.text = position.latitude.toStringAsFixed(6);
      _controllers['geofenceLng']!.text = position.longitude.toStringAsFixed(6);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Global Configuration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadSettings, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _section('Organization Profile', Icons.business, [
                    _textField('orgName', 'Company Name'),
                    _textField('industry', 'Industry'),
                    DropdownButtonFormField<String>(
                      value: _currency,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Base Currency', labelStyle: TextStyle(color: Colors.white70)),
                      items: const [
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                        DropdownMenuItem(value: 'INR', child: Text('INR')),
                      ],
                      onChanged: (value) => setState(() => _currency = value ?? 'USD'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _timezone,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Primary Timezone', labelStyle: TextStyle(color: Colors.white70)),
                      items: const [
                        DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                        DropdownMenuItem(value: 'EST', child: Text('Eastern Time')),
                        DropdownMenuItem(value: 'PST', child: Text('Pacific Time')),
                        DropdownMenuItem(value: 'IST', child: Text('India Standard Time')),
                      ],
                      onChanged: (value) => setState(() => _timezone = value ?? 'UTC'),
                    ),
                  ]),
                  _section('Policy: Working Hours', Icons.schedule, [
                    _textField('workStart', 'Standard Check-In (HH:mm)', keyboard: TextInputType.datetime),
                    _textField('workEnd', 'Standard Check-Out (HH:mm)', keyboard: TextInputType.datetime),
                    _textField('gracePeriod', 'Tardiness Grace Period (mins)', keyboard: TextInputType.number),
                    _textField('halfDayLateThreshold', 'Half-Day Penalty Threshold (mins)', keyboard: TextInputType.number),
                  ]),
                  _section('Policy: Leave Allowances', Icons.event_available, [
                    _textField('sickAllowance', 'Sick Leaves per Annum', keyboard: TextInputType.number),
                    _textField('casualAllowance', 'Casual Leaves per Annum', keyboard: TextInputType.number),
                  ]),
                  _section('Biometric Geofencing', Icons.location_on, [
                    _textField('geofenceLat', 'Center Latitude', keyboard: TextInputType.number),
                    _textField('geofenceLng', 'Center Longitude', keyboard: TextInputType.number),
                    _textField('geofenceRadius', 'Allowed Radius (meters)', keyboard: TextInputType.number),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('DETECT CURRENT COORDINATES'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                        foregroundColor: const Color(0xFF6366F1),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveSettings,
                    icon: _isSaving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                    label: Text(_isSaving ? 'SYNCHRONIZING...' : 'SAVE CONFIGURATION'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 24),
          ...children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 16), child: child)),
        ],
      ),
    );
  }

  Widget _textField(String key, String label, {TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: _controllers[key],
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
      ),
      validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
    );
  }
}
