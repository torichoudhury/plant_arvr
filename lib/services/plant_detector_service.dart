import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PlantDetectionResult {
  final String label;
  final double confidence;

  PlantDetectionResult({required this.label, required this.confidence});
}

class PlantDetectorService {
  Future<void> loadModel() async {
    // No model loading needed for API-based detection
    // You could add a health check here if needed
  }

  Future<PlantDetectionResult> detectPlant(File imageFile) async {
    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://25d2a1973063.ngrok-free.app/predict/file'),
      );

      // Add the image file to the request
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file', // This matches the parameter name expected by your API
        imageBytes,
        filename: 'plant_image.jpg',
      );
      request.files.add(multipartFile);

      // Add any additional headers if needed
      request.headers['Accept'] = 'application/json';

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Parse the JSON response
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // Extract plant name and confidence from API response
        final String plantName = jsonResponse['plant_name'] ?? 'Unknown Plant';
        final double confidence =
            (jsonResponse['confidence'] ?? 0.0).toDouble();

        return PlantDetectionResult(label: plantName, confidence: confidence);
      } else {
        throw Exception(
          'API request failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Detection failed: $e');
    }
  }

  Future<void> disposeModel() async {
    // No cleanup needed for API-based detection
  }
}
