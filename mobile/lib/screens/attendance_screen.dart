import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../config/api_config.dart';
import '../services/ml_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _cameraController;
  final MLService _mlService = MLService();
  bool _isProcessing = false;
  String _statusMessage = 'Align your face in the camera';
  bool _isRegistered = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    
    // Check registration status from backend
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/employee/$_userId/stats'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _isRegistered = data['isRegistered'] ?? false;
      }
    } catch (_) {}

    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    _cameraController = CameraController(front, ResolutionPreset.high, enableAudio: false);
    await _cameraController!.initialize();
    await _mlService.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _executeAction(String action) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Processing $action...';
    });

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final List<Face> faces = await _mlService.faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) throw Exception("No face detected. Please try again.");
      
      // DeepFAS (Anti-Spoofing) Check
      if (!_mlService.isLive(faces.first)) {
        throw Exception("Spoofing detected or poor quality. Please keep your eyes open and look straight.");
      }
      
      final embedding = await _mlService.generateEmbedding(image.path, faces.first);
      
      final endpoint = action == 'Register' ? '/attendance/register' : '/attendance/verify';
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'liveEmbedding': embedding,
          'action': action,
        }),
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Success'), backgroundColor: Colors.green));
        if (action == 'Register') {
           setState(() => _isRegistered = true);
        } else {
           Navigator.pop(context);
        }
      } else {
        throw Exception(result['error'] ?? 'Operation failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        setState(() => _statusMessage = 'Try again');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_statusMessage, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  if (_isProcessing)
                    const CircularProgressIndicator()
                  else if (!_isRegistered)
                    FilledButton.icon(
                      onPressed: () => _executeAction('Register'),
                      icon: const Icon(Icons.face),
                      label: const Text('REGISTER FACE'),
                      style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _attendanceBtn('Clock In', Colors.green, Icons.login)),
                            const SizedBox(width: 12),
                            Expanded(child: _attendanceBtn('Break In', Colors.orange, Icons.coffee)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _attendanceBtn('Break Out', Colors.orangeAccent, Icons.work)),
                            const SizedBox(width: 12),
                            Expanded(child: _attendanceBtn('Clock Out', Colors.red, Icons.logout)),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          SafeArea(child: BackButton(color: Colors.white, onPressed: () => Navigator.pop(context))),
        ],
      ),
    );
  }

  Widget _attendanceBtn(String label, Color color, IconData icon) {
    return FilledButton.icon(
      onPressed: () => _executeAction(label),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      style: FilledButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
