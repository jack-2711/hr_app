import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _companyName = 'HR CONNECT';

  @override
  void initState() {
    super.initState();
    _fetchCompanyName();
  }

  Future<void> _fetchCompanyName() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/settings'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _companyName = data['orgName'] ?? 'HR CONNECT';
          });
        }
      }
    } catch (_) {
      // Keep default
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', data['user']['id']);
        await prefs.setString('user_role', data['user']['role']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(role: data['user']['role'])),
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Login failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
        ),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF6366f1).withOpacity(0.15), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [const Color(0xFF6366f1).withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'logo',
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                            BoxShadow(color: const Color(0xFF6366f1).withOpacity(0.1), blurRadius: 40, spreadRadius: -5),
                          ],
                        ),
                        child: const Icon(Icons.business_center_rounded, size: 64, color: Color(0xFF6366f1)),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      _companyName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ENTERPRISE RESOURCE GATEWAY',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 60),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Corporate Email',
                        hintText: 'name@company.com',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF6366f1), size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Access Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6366f1), size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.03),
                      ),
                    ),
                    const SizedBox(height: 48),
                    FilledButton(
                      onPressed: _isLoading ? null : _login,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(64),
                        backgroundColor: const Color(0xFF6366f1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('AUTHENTICATE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'SECURED BY BIOMETRIC PROTOCOLS',
                      style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
