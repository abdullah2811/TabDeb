/// Firestore collection and path constants for the speech pipeline
/// All paths follow a strict naming convention to ensure consistency and scalability
class FirestoreConstants {
  // Prevent instantiation
  FirestoreConstants._();

  /// Main collection for speech jobs (indexed for admin/analytics)
  /// Document ID: jobId (UUID)
  /// Used for bulk queries, metrics, and admin dashboards
  static const String speechJobsCollection = 'speech_jobs';

  /// Subcollection within user documents for per-user speech job history
  /// Path: users/{uid}/speech_jobs/{jobId}
  /// Used for user's personal dashboard and history retrieval
  static const String userSpeechJobsSubcollection = 'speech_jobs';

  /// User root collection for auth-scoped data
  /// Path: users/{uid}
  static const String usersCollection = 'users';

  /// Subcollection for audit/metadata about user's stored recordings
  /// Path: users/{uid}/speech_metadata/{jobId}
  /// Optional: denormalized metadata like transcription word count, summary length, etc.
  static const String speechMetadataSubcollection = 'speech_metadata';

  // Firestore document field names (kept consistent for querying)
  static const String fieldId = 'id';
  static const String fieldUserId = 'userId';
  static const String fieldStatus = 'status';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldUpdatedAt = 'updatedAt';
  static const String fieldCompletedAt = 'completedAt';
  static const String fieldTranscript = 'transcript';
  static const String fieldSummary = 'summary';
  static const String fieldError = 'error';
  static const String fieldAudioStoragePath = 'audioStoragePath';
  static const String fieldDurationSeconds = 'durationSeconds';
  static const String fieldTournamentId = 'tournamentId';

  /// Composite index recommendation for queries
  /// Firestore indexes needed:
  ///   1. Collection: speech_jobs
  ///      Fields: userId (Asc), createdAt (Desc) -> for user history sorted by date
  ///      Status: userId (Asc), status (Asc), createdAt (Desc) -> for filtering by status
  ///
  ///   2. Collection: users/{uid}/speech_jobs
  ///      Fields: status (Asc), updatedAt (Desc) -> for active jobs polling
  static const String indexRecommendation =
      'See comments above for required Firestore indexes';
}

/// Firebase Cloud Storage bucket paths for the speech pipeline
class StorageConstants {
  // Prevent instantiation
  StorageConstants._();

  /// Root folder for all speech recordings
  /// Full path: gs://bucket/speech_audio/
  static const String audioFolder = 'speech_audio';

  /// Root folder for generated PDF reports
  /// Full path: gs://bucket/speech_reports/
  static const String reportsFolder = 'speech_reports';

  /// Constructs the storage path for a user's uploaded audio file
  /// Format: speech_audio/{uid}/{jobId}.m4a
  /// Parameters:
  ///   - uid: Firebase user ID
  ///   - jobId: Unique speech job identifier
  /// Returns: Full path suitable for gs:// URI or Firebase Storage reference
  static String audioFilePath(String uid, String jobId) =>
      '$audioFolder/$uid/$jobId.m4a';

  /// Constructs the storage path for a user's generated PDF report
  /// Format: speech_reports/{uid}/{jobId}.pdf
  /// Parameters:
  ///   - uid: Firebase user ID
  ///   - jobId: Unique speech job identifier
  /// Returns: Full path suitable for gs:// URI or Firebase Storage reference
  static String reportFilePath(String uid, String jobId) =>
      '$reportsFolder/$uid/$jobId.pdf';

  /// Extracts job ID from an audio file path
  /// Input: speech_audio/{uid}/{jobId}.m4a
  /// Returns: jobId
  static String extractJobIdFromAudioPath(String path) {
    final parts = path.split('/');
    if (parts.length >= 3) {
      return parts.last.replaceAll('.m4a', '');
    }
    return '';
  }

  /// Extracts user ID from an audio file path
  /// Input: speech_audio/{uid}/{jobId}.m4a
  /// Returns: uid
  static String extractUserIdFromAudioPath(String path) {
    final parts = path.split('/');
    if (parts.length >= 3) {
      return parts[parts.length - 2];
    }
    return '';
  }
}
