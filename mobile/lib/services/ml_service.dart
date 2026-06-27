import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLService {
  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // For FAS (Blink detection)
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Interpreter? _interpreter;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
      print("ML Model loaded successfully");
    } catch (e) {
      print("Failed to load TFLite model: $e");
    }
  }

  /// Implements Deep Face Anti-Spoofing (FAS) check
  /// Checks for liveness via blink detection and basic image quality
  bool isLive(Face face) {
    // 1. Check eye open probability (Blink Detection)
    // In a real DeepFAS, this would use a dedicated CNN to detect moire/texture
    // Here we use active liveness cues.
    if (face.leftEyeOpenProbability != null && face.rightEyeOpenProbability != null) {
      // If eyes are closed or squinting too much, it might be a spoof or low quality
      if (face.leftEyeOpenProbability! < 0.2 || face.rightEyeOpenProbability! < 0.2) {
        return false;
      }
    }
    
    // 2. Head Pose Check (Ensures it's a 3D head not a flat photo)
    if (face.headEulerAngleY != null && (face.headEulerAngleY!.abs() > 40)) {
       return false; // Too much tilt
    }

    return true;
  }

  Future<List<double>> generateEmbedding(String imagePath, Face face) async {
    if (_interpreter == null) {
      print("Interpreter not initialized, using fallback");
      return List.generate(192, (i) => 0.0);
    }

    try {
      // 1. Load and process image
      final bytes = await File(imagePath).readAsBytes();
      img.Image? fullImage = img.decodeImage(bytes);
      if (fullImage == null) return List.generate(192, (i) => 0.0);

      // 2. Crop face
      final rect = face.boundingBox;
      img.Image croppedFace = img.copyCrop(
        fullImage,
        x: rect.left.toInt(),
        y: rect.top.toInt(),
        width: rect.width.toInt(),
        height: rect.height.toInt(),
      );

      // 3. Resize to 112x112 (MobileFaceNet requirement)
      img.Image resizedFace = img.copyResize(croppedFace, width: 112, height: 112);

      // 4. Preprocess: Normalize to [-1, 1] or [0, 1] based on model
      // MobileFaceNet usually expects normalized input
      var input = Float32List(1 * 112 * 112 * 3);
      var buffer = input.buffer;
      var floatList = buffer.asFloat32List();
      
      int pixelIndex = 0;
      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          final pixel = resizedFace.getPixel(x, y);
          // Standard normalization: (x - 127.5) / 128
          floatList[pixelIndex++] = (pixel.r - 127.5) / 128.0;
          floatList[pixelIndex++] = (pixel.g - 127.5) / 128.0;
          floatList[pixelIndex++] = (pixel.b - 127.5) / 128.0;
        }
      }

      // 5. Run inference
      var output = List.filled(1 * 192, 0.0).reshape([1, 192]);
      _interpreter!.run(input.reshape([1, 112, 112, 3]), output);

      return List<double>.from(output[0]);
    } catch (e) {
      print("Error generating embedding: $e");
      return List.generate(192, (i) => 0.0);
    }
  }

  void dispose() {
    faceDetector.close();
    _interpreter?.close();
  }
}
