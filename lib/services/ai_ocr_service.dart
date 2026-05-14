import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class AiOcrService {
  static Future<Map<String, dynamic>> extractBillData(Uint8List bytes) async {
    try {
      final apiKey = dotenv.env['AI_API_KEY'] ?? '';
      final baseUrl = dotenv.env['AI_BASE_URL'] ?? 'https://api.together.xyz/v1/chat/completions';
      final model = dotenv.env['AI_MODEL'] ?? 'moonshotai/Kimi-K2.5:together';

      if (apiKey.isEmpty) {
        debugPrint('AI API key is missing.');
        return _fallbackError('API key not configured in .env');
      }

      final base64Image = base64Encode(bytes);
      
      final payload = {
        "model": model,
        "messages": [
          {
            "role": "system",
            "content": "You are a highly accurate receipt parsing assistant. You MUST respond with ONLY a valid JSON object. Do not include markdown code blocks (```json ... ```), just the raw JSON object."
          },
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "Extract bill details from this image and return as JSON. The JSON MUST have exactly these keys: 'raw_text' (string, the full text visible on the bill), 'amount' (number, total amount), 'vendor_name' (string, name of the shop or vendor), 'bill_date' (string, format YYYY-MM-DD), 'is_gst_bill' (boolean, true if GST is mentioned), 'gst_amount' (number, total GST amount). If a value is missing, use 0 for numbers and empty string for strings."
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": "data:image/jpeg;base64,$base64Image"
                }
              }
            ]
          }
        ],
        "temperature": 0.1,
      };

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        
        // Sometimes the model might wrap in ```json ... ``` despite instructions
        String jsonString = content.trim();
        if (jsonString.startsWith('```json')) {
          jsonString = jsonString.substring(7);
        }
        if (jsonString.startsWith('```')) {
          jsonString = jsonString.substring(3);
        }
        if (jsonString.endsWith('```')) {
          jsonString = jsonString.substring(0, jsonString.length - 3);
        }
        jsonString = jsonString.trim();

        // Extract JSON using regex in case the model includes conversational text
        final jsonRegex = RegExp(r'\{[\s\S]*\}');
        final match = jsonRegex.firstMatch(jsonString);
        if (match != null) {
          jsonString = match.group(0)!;
        }

        final Map<String, dynamic> parsedData = jsonDecode(jsonString);
        debugPrint('Extracted OCR Data: $parsedData');

        return {
          'raw_text': parsedData['raw_text'] ?? '',
          'amount': (parsedData['amount'] ?? 0.0) is num ? (parsedData['amount'] as num).toDouble() : 0.0,
          'vendor_name': parsedData['vendor_name'] ?? '',
          'bill_date': parsedData['bill_date'] ?? DateTime.now().toIso8601String().split('T')[0],
          'is_gst_bill': parsedData['is_gst_bill'] ?? false,
          'gst_amount': (parsedData['gst_amount'] ?? 0.0) is num ? (parsedData['gst_amount'] as num).toDouble() : 0.0,
        };
      } else {
        debugPrint('AI API Error: ${response.statusCode} - ${response.body}');
        return _fallbackError('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('AI OCR Extraction Error: $e');
      return _fallbackError(e.toString());
    }
  }

  static Map<String, dynamic> _fallbackError(String errorMsg) {
    return {
      'raw_text': '',
      'amount': 0.0,
      'vendor_name': '',
      'bill_date': DateTime.now().toIso8601String().split('T')[0],
      'is_gst_bill': false,
      'gst_amount': 0.0,
      'error': errorMsg,
    };
  }
}
