import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/api_contract.dart';
import '../models/api_response.dart';

class SpeechApiService {
  SpeechApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _defaultAndroidHost = 'http://10.0.2.2:8000';
  static const String _defaultWebDesktopHost = 'http://localhost:8000';

  String get _baseUrl {
    const configured = String.fromEnvironment('SPEECH_API_BASE_URL');
    if (configured.isNotEmpty) {
      return _normalizeBaseUrl(configured);
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _defaultAndroidHost;
    }
    return _defaultWebDesktopHost;
  }

  String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    // Android emulators cannot reach host machine via localhost.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      value = value
          .replaceFirst('://localhost', '://10.0.2.2')
          .replaceFirst('://127.0.0.1', '://10.0.2.2');
    }
    return value;
  }

  Exception _networkException([Object? cause]) {
    return Exception(
      'Cannot reach Speech API at $_baseUrl. '
      'Start backend server and verify base URL. '
      'For Android emulator use http://10.0.2.2:8000, '
      'for physical device use http://<PC-LAN-IP>:8000. '
      'Original error: $cause',
    );
  }

  Future<String> _getIdToken() async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User is not authenticated');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Failed to get Firebase ID token');
    }
    return token;
  }

  Future<CreateSpeechJobResponse> createSpeechJob(
    CreateSpeechJobRequest request,
  ) async {
    final token = await _getIdToken();
    final uri = Uri.parse('$_baseUrl/v1${ApiContract.createJobEndpoint}');

    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
    } on http.ClientException catch (e) {
      throw _networkException(e.message);
    } catch (e) {
      throw _networkException(e);
    }

    final payload = _decodeResponse(response);
    if (response.statusCode != ApiContract.createJobResponseStatus) {
      throw _toApiException(payload, response.statusCode);
    }

    return CreateSpeechJobResponse.fromJson(payload);
  }

  Future<void> uploadAudioToSignedUrl(
    String signedUrl,
    Uint8List bytes,
  ) async {
    final uri = Uri.parse(signedUrl);
    http.Response response;
    try {
      response = await _client.put(
        uri,
        headers: {
          'Content-Type': ApiContract.audioUploadContentType,
        },
        body: bytes,
      );
    } on http.ClientException catch (e) {
      throw _networkException(e.message);
    } catch (e) {
      throw _networkException(e);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Audio upload failed with status ${response.statusCode}');
    }
  }

  Future<GetSpeechJobResponse> getSpeechJob(String jobId) async {
    final token = await _getIdToken();
    final endpoint = ApiContract.getJobEndpoint.replaceAll('{jobId}', jobId);
    final uri = Uri.parse('$_baseUrl/v1$endpoint');

    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
    } on http.ClientException catch (e) {
      throw _networkException(e.message);
    } catch (e) {
      throw _networkException(e);
    }

    final payload = _decodeResponse(response);
    if (response.statusCode != ApiContract.getJobResponseStatus) {
      throw _toApiException(payload, response.statusCode);
    }

    return GetSpeechJobResponse.fromJson(payload);
  }

  Future<SummarizationStartedResponse> triggerSummarization(
    String jobId, {
    int? maxLength,
  }) async {
    final token = await _getIdToken();
    final endpoint =
        ApiContract.summarizeJobEndpoint.replaceAll('{jobId}', jobId);
    final uri = Uri.parse('$_baseUrl/v1$endpoint');

    final request = SummarizationRequest(maxLength: maxLength);
    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
    } on http.ClientException catch (e) {
      throw _networkException(e.message);
    } catch (e) {
      throw _networkException(e);
    }

    final payload = _decodeResponse(response);
    if (response.statusCode != ApiContract.summarizeJobResponseStatus) {
      throw _toApiException(payload, response.statusCode);
    }

    return SummarizationStartedResponse.fromJson(payload);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Unexpected response format from server');
  }

  Exception _toApiException(Map<String, dynamic> payload, int statusCode) {
    try {
      final apiError = ApiErrorResponse.fromJson(payload);
      return Exception(apiError.userMessage);
    } catch (_) {
      return Exception('Request failed with status $statusCode');
    }
  }
}
