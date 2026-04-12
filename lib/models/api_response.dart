/// Response models from backend API for type-safe parsing
/// These correspond to payloads defined in [ApiContract]
import 'speech_job.dart';

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

DateTime _asDateTime(dynamic value, {DateTime? fallback}) {
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? fallback ?? DateTime.now();
  }
  return fallback ?? DateTime.now();
}

/// Response when creating a new speech job
/// Returned: 201 Created
class CreateSpeechJobResponse {
  final String jobId;
  final String status;
  final String uploadUrl; // Signed PUT URL for audio file upload
  final String audioStoragePath; // Path where audio will be stored
  final DateTime createdAt;
  final int expiresIn; // Seconds until uploadUrl expires

  CreateSpeechJobResponse({
    required this.jobId,
    required this.status,
    required this.uploadUrl,
    required this.audioStoragePath,
    required this.createdAt,
    required this.expiresIn,
  });

  factory CreateSpeechJobResponse.fromJson(Map<String, dynamic> json) {
    return CreateSpeechJobResponse(
      jobId: _asString(json['jobId']),
      status: _asString(json['status'], fallback: 'uploaded'),
      uploadUrl: _asString(json['uploadUrl']),
      audioStoragePath: _asString(json['audioStoragePath']),
      createdAt: _asDateTime(json['createdAt']),
      expiresIn: _asInt(json['expiresIn']) ?? 3600,
    );
  }

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'status': status,
        'uploadUrl': uploadUrl,
        'audioStoragePath': audioStoragePath,
        'createdAt': createdAt.toIso8601String(),
        'expiresIn': expiresIn,
      };

  @override
  String toString() => 'CreateSpeechJobResponse(jobId=$jobId, status=$status)';
}

/// Response when polling job status
/// Returned: 200 OK (job exists and user owns it)
/// Contains current state: transcript, summary, or error depending on status
class GetSpeechJobResponse {
  final String jobId;
  final String status;
  final String userId;
  final int? durationSeconds;
  final String? transcript;
  final String? summary;
  final String? error;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  GetSpeechJobResponse({
    required this.jobId,
    required this.status,
    required this.userId,
    this.durationSeconds,
    this.transcript,
    this.summary,
    this.error,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory GetSpeechJobResponse.fromJson(Map<String, dynamic> json) {
    return GetSpeechJobResponse(
      jobId: _asString(json['jobId']),
      status: _asString(json['status'], fallback: 'uploaded'),
      userId: _asString(json['userId']),
      durationSeconds: _asInt(json['durationSeconds']),
      transcript: json['transcript']?.toString(),
      summary: json['summary']?.toString(),
      error: json['error']?.toString(),
      createdAt: _asDateTime(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? _asDateTime(json['updatedAt']) : null,
      completedAt:
          json['completedAt'] != null ? _asDateTime(json['completedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'status': status,
        'userId': userId,
        'durationSeconds': durationSeconds,
        'transcript': transcript,
        'summary': summary,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  /// Converts this API response to a domain model [SpeechJob]
  SpeechJob toSpeechJob() {
    return SpeechJob(
      id: jobId,
      userId: userId,
      status: status.toSpeechJobStatus(),
      durationSeconds: durationSeconds,
      transcript: transcript,
      summary: summary,
      error: error,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
    );
  }

  @override
  String toString() =>
      'GetSpeechJobResponse(jobId=$jobId, status=$status, hasTranscript=${transcript != null}, hasSummary=${summary != null})';
}

/// Response when triggering summarization step
/// Returned: 202 Accepted (background job queued)
class SummarizationStartedResponse {
  final String jobId;
  final String status;
  final String message;

  SummarizationStartedResponse({
    required this.jobId,
    required this.status,
    required this.message,
  });

  factory SummarizationStartedResponse.fromJson(Map<String, dynamic> json) {
    return SummarizationStartedResponse(
      jobId: _asString(json['jobId']),
      status: _asString(json['status'], fallback: 'summarizing'),
      message: _asString(json['message']),
    );
  }

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'status': status,
        'message': message,
      };

  @override
  String toString() =>
      'SummarizationStartedResponse(jobId=$jobId, status=$status)';
}

/// Standard error response from backend
/// Returned on any HTTP error status (4xx, 5xx)
class ApiErrorResponse {
  final String error;
  final String message;
  final int statusCode;
  final DateTime timestamp;

  ApiErrorResponse({
    required this.error,
    required this.message,
    required this.statusCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) {
    return ApiErrorResponse(
      error: _asString(json['error'], fallback: 'unknown_error'),
      message: _asString(
        json['message'],
        fallback: 'An unexpected error occurred',
      ),
      statusCode: _asInt(json['statusCode']) ?? 500,
      timestamp: json['timestamp'] != null
          ? _asDateTime(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'error': error,
        'message': message,
        'statusCode': statusCode,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Returns true if error is retryable (transient failure)
  bool get isRetryable {
    return statusCode >= 500; // 5xx errors are typically retryable
  }

  /// Returns true if error is auth-related (token expired, invalid, etc.)
  bool get isAuthError {
    return error == 'invalid_token' ||
        error == 'forbidden' ||
        statusCode == 401 ||
        statusCode == 403;
  }

  /// Returns user-friendly error message
  String get userMessage {
    switch (error) {
      case 'invalid_token':
        return 'Your session has expired. Please sign in again.';
      case 'forbidden':
        return 'You do not have permission to access this resource.';
      case 'job_not_found':
        return 'The requested job could not be found.';
      case 'invalid_state':
        return 'Cannot perform this action on the current job state.';
      case 'invalid_request':
        return 'Invalid request parameters. Please try again.';
      case 'internal_error':
        return 'Server error occurred. Please try again later.';
      default:
        return message;
    }
  }

  @override
  String toString() =>
      'ApiErrorResponse(error=$error, statusCode=$statusCode, message=$message)';
}

/// Request body for creating a speech job
/// Used when calling POST /v1/speech-jobs
class CreateSpeechJobRequest {
  final int audioFileSize; // bytes
  final int? durationSeconds; // optional
  final String? tournamentId; // optional

  CreateSpeechJobRequest({
    required this.audioFileSize,
    this.durationSeconds,
    this.tournamentId,
  });

  Map<String, dynamic> toJson() => {
        'audioFileSize': audioFileSize,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (tournamentId != null) 'tournamentId': tournamentId,
      };

  @override
  String toString() =>
      'CreateSpeechJobRequest(size=$audioFileSize, duration=$durationSeconds, tournament=$tournamentId)';
}

/// Request body for triggering summarization
/// Used when calling POST /v1/speech-jobs/{jobId}/summarize
class SummarizationRequest {
  final int? maxLength; // optional, defaults to 200 on backend

  SummarizationRequest({
    this.maxLength,
  });

  Map<String, dynamic> toJson() => {
        if (maxLength != null)
          'settings': {
            'maxLength': maxLength,
          }
      };

  @override
  String toString() => 'SummarizationRequest(maxLength=$maxLength)';
}
