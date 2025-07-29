import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const String _apiKey = 'AIzaSyAX99H-C9-Aw6Rs-Z0H53Cgkq-zshZ3_ho'; // key

Future<List<dynamic>> analyzeImage(XFile image) async {
  final String url = 'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

  try {
    final Uint8List bytes = await image.readAsBytes();
    final String base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'}, // Good practice to set headers
      body: jsonEncode({
        "requests": [
          {
            "image": {"content": base64Image},
            "features": [
              {"type": "LABEL_DETECTION", "maxResults": 15} // Increased maxResults slightly
            ]
          }
        ]
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Defensive coding: Check if the expected structure exists
      if (data['responses'] != null &&
          data['responses'].isNotEmpty &&
          data['responses'][0]['labelAnnotations'] != null) {
        return data['responses'][0]['labelAnnotations'] as List<dynamic>;
      } else if (data['responses'] != null &&
          data['responses'].isNotEmpty &&
          data['responses'][0]['error'] != null) {
        // Handle API errors specifically
        final error = data['responses'][0]['error'];
        print("Google Vision API Error: ${error['message']}");
        throw Exception('Vision API Error: ${error['message']}');
      } else {
        print("Unexpected API response format: ${response.body}");
        throw Exception('Unexpected API response format.');
      }
    } else {
      // Handle HTTP errors
      print("HTTP Error ${response.statusCode}: ${response.body}");
      throw Exception('Failed to analyze image. Status code: ${response.statusCode}');
    }
  }catch(e){
    print("Error in analyzeImage function: $e");
    // Re-throw the exception so the caller can handle it
    // (e.g., display a message to the user)
    throw Exception('Error processing image analysis: ${e.toString()}');
  }
}