import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Asset model representing a face filter
class FilterAsset {
  final String id;
  final String name;
  final String thumbnail; // Base64 encoded
  final bool hasSound;
  final String? soundFile;
  final String folder;

  FilterAsset({
    required this.id,
    required this.name,
    required this.thumbnail,
    required this.folder,
    this.hasSound = false,
    this.soundFile,
  });

  factory FilterAsset.fromJson(Map<String, dynamic> json) {
    return FilterAsset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      folder: json['folder'] ?? '',
      hasSound: json['has_sound'] ?? false,
      soundFile: json['sound_file'],
    );
  }
}

class ApiService {
  static String _baseUrl = "http://127.0.0.1:8000";

  static String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8000";
    // If user has set a custom IP (e.g. for Android tablet), use it.
    // Otherwise fallback to emulator default or localhost.
    if (_baseUrl != "http://127.0.0.1:8000") return _baseUrl;

    if (Platform.isAndroid) return "http://10.0.2.2:8000";
    return "http://127.0.0.1:8000";
  }

  static void setBaseUrl(String ip) {
    if (ip.isEmpty) return;
    if (!ip.startsWith("http")) {
      _baseUrl = "http://$ip:8000";
    } else {
      _baseUrl = ip;
    }
    debugPrint("API Base URL set to: $_baseUrl");
  }

  /// Get hello message (test endpoint)
  static Future<String> getMessage() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/hello"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'];
      } else {
        return "Error: ${response.statusCode}";
      }
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  /// Get list of available filter categories
  static Future<List<String>> getCategories() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/categories"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['categories'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      return [];
    }
  }

  /// Get assets for a specific category
  static Future<List<FilterAsset>> getCategoryAssets(String category) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/categories/$category/assets"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List assets = data['assets'] ?? [];
        return assets.map((a) => FilterAsset.fromJson(a)).toList();
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching assets for $category: $e");
      return [];
    }
  }

  /// Process a frame with face morphing
  /// Returns a Map with 'frame' (base64) and 'mouth_open' (bool), or null if failed
  static Future<Map<String, dynamic>?> processFrame({
    required String frameBase64,
    required String assetId,
    double opacity = 1.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/process-frame"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "frame": frameBase64,
          "asset_id": assetId,
          "opacity": opacity,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            "frame": data['frame'],
            "mouth_open": data['mouth_open'] ?? false,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error processing frame: $e");
      return null;
    }
  }

  /// Convert image bytes to base64
  static String bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  /// Convert base64 to image bytes
  static Uint8List base64ToBytes(String base64String) {
    return base64Decode(base64String);
  }

  /// Detect gender from a frame
  /// Returns a Map with gender and confidence, or error
  static Future<Map<String, dynamic>> detectGender(String frameBase64) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/detect-gender"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "frame": frameBase64,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"error": "Server error: ${response.statusCode}"};
      }
    } catch (e) {
      return {"error": "Connection error: $e"};
    }
  }

  /// Start recording video on backend
  static Future<bool> startRecording() async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/start-recording"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "width": 640, // Values ignored by backend in lazy mode
          "height": 480,
          "fps": 20
        }),
      );
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error starting recording: $e");
      return false;
    }
  }

  /// Stop recording and get video
  static Future<String?> stopRecording() async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/stop-recording"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['video'] != null) {
          return data['video'];
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      return null;
    }
  }
}
