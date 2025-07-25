import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class PlantDetectionResult {
  final String label;
  final double confidence;

  PlantDetectionResult({required this.label, required this.confidence});
}

class PlantDetectorService {
  static const String apiKey =
      'AIzaSyCnc12Lkv8U6rzjfX_Fmzw1BGk8BPoVA3w';
  late final GenerativeModel _model;

  Future<void> loadModel() async {
    try {
      _model = GenerativeModel(model: 'gemini-pro-vision', apiKey: apiKey);
    } catch (e) {
      throw Exception('Failed to initialize Gemini: $e');
    }
  }

  Future<PlantDetectionResult> detectPlant(File imageFile) async {
    try {
      // Read image bytes
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Create content part for the image
      final imagePart = DataPart('image/jpeg', imageBytes);

      // Create prompt
      const String prompt = '''
        Analyze this plant image and provide:
        1. The most likely plant species name
        2. Confidence level (0-100%)
        Format: "species|confidence"
      ''';

      // Get response from Gemini
      final response = await _model.generateContent([
        Content.multi([TextPart(prompt), imagePart]),
      ]);

      final text = response.text;
      if (text == null) throw Exception('No response from Gemini');

      // Parse response (expected format: "species|confidence")
      final parts = text.split('|');
      if (parts.length != 2) throw Exception('Invalid response format');

      return PlantDetectionResult(
        label: parts[0].trim(),
        confidence: double.parse(parts[1].replaceAll('%', '')) / 100,
      );
    } catch (e) {
      throw Exception('Detection failed: $e');
    }
  }

  Future<void> disposeModel() async {
    // No explicit cleanup needed for Gemini
  }
}
