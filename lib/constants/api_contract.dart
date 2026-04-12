/// Backend API contract for the speech transcription and summarization pipeline
/// This defines the HTTP API that Flutter clients communicate with.
/// All endpoints require Firebase ID token in Authorization header.
///
/// Base URL (set in Flutter env config): https://api.example.com/v1
/// Header: Authorization: Bearer {firebaseIdToken}
/// Error handling: See [ApiErrorResponse] below
class ApiContract {
  // Prevent instantiation
  ApiContract._();

  /// API version prefix
  static const String apiVersion = 'v1';

  // =========================================================================
  // ENDPOINT: Create and start speech job
  // =========================================================================

  static const String createJobEndpoint = '/speech-jobs';

  /// Request to create a new speech processing job
  /// POST /v1/speech-jobs
  /// Headers: Authorization: Bearer {token}
  /// Body: CreateSpeechJobRequest JSON
  static const String createJobMethod = 'POST';

  /// Response after job creation
  /// Status: 201 Created
  /// Body: CreateSpeechJobResponse JSON
  static const int createJobResponseStatus = 201;

  // =========================================================================
  // ENDPOINT: Get job status and intermediate results
  // =========================================================================

  static const String getJobEndpoint = '/speech-jobs/{jobId}';

  /// Request to poll job status
  /// GET /v1/speech-jobs/{jobId}
  /// Headers: Authorization: Bearer {token}
  /// Path Parameter: jobId - UUID of the speech job
  static const String getJobMethod = 'GET';

  /// Response with current job state
  /// Status: 200 OK (job exists and user owns it)
  /// Status: 404 Not Found (job doesn't exist)
  /// Status: 403 Forbidden (user doesn't own this job)
  /// Body: GetSpeechJobResponse JSON
  static const int getJobResponseStatus = 200;

  // =========================================================================
  // ENDPOINT: Trigger summarization after transcription complete
  // =========================================================================

  static const String summarizeJobEndpoint = '/speech-jobs/{jobId}/summarize';

  /// Request to start summarization (only valid when status == 'transcribed')
  /// POST /v1/speech-jobs/{jobId}/summarize
  /// Headers: Authorization: Bearer {token}
  /// Path Parameter: jobId - UUID of the speech job
  /// Body: {settings: {maxLength: 500}} (optional, for future expansion)
  static const String summarizeJobMethod = 'POST';

  /// Response after triggering summarization
  /// Status: 202 Accepted (job queued for processing)
  /// Status: 400 Bad Request (invalid job state, e.g., not transcribed yet)
  /// Status: 409 Conflict (already summarizing or already summarized)
  /// Body: SummarizationStartedResponse JSON
  static const int summarizeJobResponseStatus = 202;

  // =========================================================================
  // PAYLOAD SCHEMAS (Documented in Dart for reference)
  // Actual JSON examples below in comments
  // =========================================================================

  /// Flutter -> Backend: Create a new speech job for audio processing
  ///
  /// JSON Example:
  /// ```json
  /// {
  ///   "audioFileSize": 2048576,          // bytes, for validation
  ///   "durationSeconds": 120,             // estimated duration from client
  ///   "tournamentId": "tourn_xyz"         // optional, null if not in tournament
  /// }
  /// ```
  static const Map<String, String> createJobRequestFields = {
    'audioFileSize': 'int (bytes)',
    'durationSeconds': 'int? (seconds)',
    'tournamentId': 'String? (tournament UUID or null)',
  };

  /// Backend -> Flutter: Confirmation and upload URL after job creation
  ///
  /// JSON Example:
  /// ```json
  /// {
  ///   "jobId": "job_abc123xyz",
  ///   "status": "uploaded",
  ///   "uploadUrl": "https://storage.googleapis.com/bucket/...",   // signed PUT URL
  ///   "audioStoragePath": "speech_audio/user_uid/job_abc123xyz.m4a",
  ///   "createdAt": "2025-04-05T14:30:00Z",
  ///   "expiresIn": 3600                  // seconds until upload URL expires
  /// }
  /// ```
  static const Map<String, String> createJobResponseFields = {
    'jobId': 'String (UUID)',
    'status': 'String (enum: uploaded)',
    'uploadUrl': 'String (Firebase Storage signed PUT URL)',
    'audioStoragePath': 'String (path in Storage)',
    'createdAt': 'String (ISO 8601 timestamp)',
    'expiresIn': 'int (seconds)',
  };

  /// Flutter -> (implicit): Upload audio file to signed PUT URL
  ///
  /// After receiving uploadUrl from createJobResponse:
  /// PUT {uploadUrl}
  /// Headers: Content-Type: audio/m4a
  /// Body: Binary audio file (m4a format from record package)
  /// Status: 200 OK
  ///
  /// Note: Upload URL is pre-signed by backend; no auth token needed for PUT
  static const String audioUploadMethod = 'PUT';
  static const String audioUploadContentType = 'audio/m4a';

  /// Backend -> Flutter: Poll current job state at any time
  ///
  /// JSON Example (status: uploaded):
  /// ```json
  /// {
  ///   "jobId": "job_abc123xyz",
  ///   "status": "uploaded",
  ///   "userId": "user_uid",
  ///   "durationSeconds": 120,
  ///   "transcript": null,
  ///   "summary": null,
  ///   "error": null,
  ///   "createdAt": "2025-04-05T14:30:00Z",
  ///   "updatedAt": "2025-04-05T14:30:05Z",
  ///   "completedAt": null
  /// }
  /// ```
  ///
  /// JSON Example (status: transcribed):
  /// ```json
  /// {
  ///   "jobId": "job_abc123xyz",
  ///   "status": "transcribed",
  ///   "userId": "user_uid",
  ///   "durationSeconds": 120,
  ///   "transcript": "Today I want to discuss the merits of...",
  ///   "summary": null,
  ///   "error": null,
  ///   "createdAt": "2025-04-05T14:30:00Z",
  ///   "updatedAt": "2025-04-05T14:32:15Z",
  ///   "completedAt": null
  /// }
  /// ```
  ///
  /// JSON Example (status: completed):
  /// ```json
  /// {
  ///   "jobId": "job_abc123xyz",
  ///   "status": "completed",
  ///   "userId": "user_uid",
  ///   "durationSeconds": 120,
  ///   "transcript": "Today I want to discuss the merits of...",
  ///   "summary": "The speaker argues that X is important because Y and Z.",
  ///   "error": null,
  ///   "createdAt": "2025-04-05T14:30:00Z",
  ///   "updatedAt": "2025-04-05T14:35:20Z",
  ///   "completedAt": "2025-04-05T14:35:20Z"
  /// }
  /// ```
  ///
  /// JSON Example (status: failed):
  /// ```json
  /// {
  ///   "jobId": "job_abc123xyz",
  ///   "status": "failed",
  ///   "userId": "user_uid",
  ///   "durationSeconds": 120,
  ///   "transcript": null,
  ///   "summary": null,
  ///   "error": "Audio transcription service temporarily unavailable",
  ///   "createdAt": "2025-04-05T14:30:00Z",
  ///   "updatedAt": "2025-04-05T14:32:15Z",
  ///   "completedAt": "2025-04-05T14:32:15Z"
  /// }
  /// ```
  static const Map<String, String> getJobResponseFields = {
    'jobId': 'String (UUID)',
    'status':
        'String (enum: uploaded|transcribing|transcribed|summarizing|completed|failed)',
    'userId': 'String (Firebase UID)',
    'durationSeconds': 'int? (seconds)',
    'transcript': 'String? (null until status >= transcribed)',
    'summary': 'String? (null until status == completed)',
    'error': 'String? (error message if status == failed)',
    'createdAt': 'String (ISO 8601)',
    'updatedAt': 'String? (ISO 8601)',
    'completedAt': 'String? (ISO 8601, present when status is terminal)',
  };

  /// Flutter -> Backend: Trigger summarization step
  ///
  /// JSON Example:
  /// ```json
  /// {
  ///   "settings": {
  ///     "maxLength": 500                  // optional, default 200
  ///   }
  /// }
  /// ```
  static const Map<String, String> summarizeJobRequestFields = {
    'settings': 'Object {maxLength?: int}',
  };

  /// Backend -> Flutter: Summarization triggered (async job started)
  ///
  /// JSON Example:
  /// ```json
  /// {
  ///   "jobId": "job_abc123xyz",
  ///   "status": "summarizing",
  ///   "message": "Summarization started"
  /// }
  /// ```
  static const Map<String, String> summarizationStartedResponseFields = {
    'jobId': 'String (UUID)',
    'status': 'String (now: summarizing)',
    'message': 'String (confirmation message)',
  };

  // =========================================================================
  // ERROR HANDLING
  // =========================================================================

  /// Standard error response format from backend
  ///
  /// JSON Example (400 Bad Request):
  /// ```json
  /// {
  ///   "error": "invalid_request",
  ///   "message": "audioFileSize must be positive integer",
  ///   "statusCode": 400,
  ///   "timestamp": "2025-04-05T14:30:00Z"
  /// }
  /// ```
  ///
  /// JSON Example (401 Unauthorized - invalid token):
  /// ```json
  /// {
  ///   "error": "invalid_token",
  ///   "message": "Firebase token is invalid or expired",
  ///   "statusCode": 401,
  ///   "timestamp": "2025-04-05T14:30:00Z"
  /// }
  /// ```
  ///
  /// JSON Example (403 Forbidden - no access):
  /// ```json
  /// {
  ///   "error": "forbidden",
  ///   "message": "You do not have permission to access this job",
  ///   "statusCode": 403,
  ///   "timestamp": "2025-04-05T14:30:00Z"
  /// }
  /// ```
  ///
  /// JSON Example (404 Not Found):
  /// ```json
  /// {
  ///   "error": "job_not_found",
  ///   "message": "Job with ID 'job_abc123xyz' does not exist",
  ///   "statusCode": 404,
  ///   "timestamp": "2025-04-05T14:30:00Z"
  /// }
  /// ```
  ///
  /// JSON Example (409 Conflict - invalid state transition):
  /// ```json
  /// {
  ///   "error": "invalid_state",
  ///   "message": "Cannot summarize job in status 'uploaded'; must be 'transcribed'",
  ///   "statusCode": 409,
  ///   "timestamp": "2025-04-05T14:30:00Z"
  /// }
  /// ```
  ///
  /// JSON Example (500 Internal Server Error):
  /// ```json
  /// {
  ///   "error": "internal_error",
  ///   "message": "An unexpected error occurred; please try again later",
  ///   "statusCode": 500,
  ///   "timestamp": "2025-04-05T14:30:00Z"
  /// }
  /// ```
  static const Map<String, String> errorResponseFields = {
    'error':
        'String (error code: invalid_request|invalid_token|forbidden|job_not_found|invalid_state|internal_error)',
    'message': 'String (human-readable error description)',
    'statusCode': 'int (HTTP status code)',
    'timestamp': 'String (ISO 8601 when error occurred)',
  };

  // Error codes that Flutter must handle
  static const String errorCodeInvalidToken = 'invalid_token';
  static const String errorCodeForbidden = 'forbidden';
  static const String errorCodeJobNotFound = 'job_not_found';
  static const String errorCodeInvalidState = 'invalid_state';
  static const String errorCodeInternalError = 'internal_error';
  static const String errorCodeInvalidRequest = 'invalid_request';
}
