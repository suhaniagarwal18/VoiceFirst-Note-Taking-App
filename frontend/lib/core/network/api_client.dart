import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/constants.dart';
import '../models/note_model.dart';
import '../models/session_model.dart';

class ApiClient {
  String baseUrl;

  ApiClient({this.baseUrl = AppConstants.defaultBackendUrl});

  Future<Map<String, dynamic>> processVoice({
    required String text,
    Map<String, dynamic>? context,
    String userId = AppConstants.defaultUserId,
    double confidence = 1.0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/voice/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'user_id': userId,
          'confidence': confidence,
          'context': context ?? {},
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'intent': 'ERROR',
          'spoken_response': "I couldn't reach the notes server. Please ensure the backend is running.",
          'action': 'none',
          'context': context ?? {},
        };
      }
    } catch (e) {
      return {
        'intent': 'NETWORK_ERROR',
        'spoken_response': "Connection error. Please check your backend server.",
        'action': 'none',
        'context': context ?? {},
      };
    }
  }

  Future<List<NoteModel>> getNotes({
    String userId = AppConstants.defaultUserId,
    String? subject,
    String? tag,
    String? timeframe,
  }) async {
    try {
      final queryParams = <String, String>{'user_id': userId};
      if (subject != null) queryParams['subject'] = subject;
      if (tag != null) queryParams['tag'] = tag;
      if (timeframe != null) queryParams['timeframe'] = timeframe;

      final uri = Uri.parse('$baseUrl/api/notes').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => NoteModel.fromJson(item)).toList();
      }
    } catch (e) {
      // Return empty list on error
    }
    return [];
  }

  Future<NoteModel?> getLastNote({String userId = AppConstants.defaultUserId}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/notes/last?user_id=$userId'));
      if (response.statusCode == 200) {
        return NoteModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {}
    return null;
  }

  Future<SessionModel?> getActiveSession({String userId = AppConstants.defaultUserId}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/sessions/active?user_id=$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['is_active'] == true && data['session'] != null) {
          return SessionModel.fromJson(data['session']);
        }
      }
    } catch (e) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getBookmarks({String userId = AppConstants.defaultUserId}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/bookmarks?user_id=$userId'));
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (e) {}
    return [];
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
