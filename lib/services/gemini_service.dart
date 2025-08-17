import 'dart:convert';
import 'package:http/http.dart' as http;

class PlantDetailsResponse {
  final String benefits;
  final String usage;
  final String description;

  PlantDetailsResponse({
    required this.benefits,
    required this.usage,
    required this.description,
  });
}

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';
  final String _apiKey; // Store your Gemini API key securely

  GeminiService(this._apiKey);

  Future<String> getMedicalBenefits(String plantName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'What are the medical benefits of $plantName? Please provide a concise summary.',
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 200},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      } else {
        throw Exception('Failed to get medical benefits');
      }
    } catch (e) {
      throw Exception('Error getting medical benefits: $e');
    }
  }

  Future<PlantDetailsResponse> getPlantDetails(String plantName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      '''
                  Please provide detailed information about $plantName in the following format:
                  
                  BENEFITS:
                  [List the medical and health benefits]
                  
                  USAGE:
                  [Explain how it can be used - preparation methods, dosage, application methods]
                  
                  DESCRIPTION:
                  [Brief botanical description and interesting facts]
                  
                  Keep the response concise but informative, suitable for display on a mobile AR interface.
                  ''',
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 800},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fullText =
            data['candidates'][0]['content']['parts'][0]['text'] as String;

        // Parse the response into sections
        final sections = _parseGeminiResponse(fullText);

        return PlantDetailsResponse(
          benefits:
              sections['benefits'] ?? 'Benefits information not available.',
          usage: sections['usage'] ?? 'Usage information not available.',
          description: sections['description'] ?? 'Description not available.',
        );
      } else {
        throw Exception('Failed to get plant details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting plant details: $e');
    }
  }

  Map<String, String> _parseGeminiResponse(String response) {
    final result = <String, String>{};

    try {
      final lines = response.split('\n');
      String currentSection = '';
      StringBuffer currentContent = StringBuffer();

      for (final line in lines) {
        final trimmedLine = line.trim();

        if (trimmedLine.toUpperCase().startsWith('BENEFITS:')) {
          if (currentSection.isNotEmpty) {
            result[currentSection] = currentContent.toString().trim();
          }
          currentSection = 'benefits';
          currentContent.clear();
          // Add any content after the colon
          final afterColon = trimmedLine.substring(9).trim();
          if (afterColon.isNotEmpty) {
            currentContent.writeln(afterColon);
          }
        } else if (trimmedLine.toUpperCase().startsWith('USAGE:')) {
          if (currentSection.isNotEmpty) {
            result[currentSection] = currentContent.toString().trim();
          }
          currentSection = 'usage';
          currentContent.clear();
          // Add any content after the colon
          final afterColon = trimmedLine.substring(6).trim();
          if (afterColon.isNotEmpty) {
            currentContent.writeln(afterColon);
          }
        } else if (trimmedLine.toUpperCase().startsWith('DESCRIPTION:')) {
          if (currentSection.isNotEmpty) {
            result[currentSection] = currentContent.toString().trim();
          }
          currentSection = 'description';
          currentContent.clear();
          // Add any content after the colon
          final afterColon = trimmedLine.substring(12).trim();
          if (afterColon.isNotEmpty) {
            currentContent.writeln(afterColon);
          }
        } else if (currentSection.isNotEmpty && trimmedLine.isNotEmpty) {
          currentContent.writeln(trimmedLine);
        }
      }

      // Don't forget the last section
      if (currentSection.isNotEmpty) {
        result[currentSection] = currentContent.toString().trim();
      }
    } catch (e) {
      print('Error parsing Gemini response: $e');
      // Fallback: use the entire response as description
      result['description'] = response;
    }

    return result;
  }
}
