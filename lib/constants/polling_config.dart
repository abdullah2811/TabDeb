/// Configuration for job polling, retry strategy, and timeout management
/// in the speech transcription and summarization pipeline.
///
/// This ensures consistent behavior across the app for handling async job states
/// and provides tuning knobs for production environments.
class PollingConfig {
  // Prevent instantiation
  PollingConfig._();

  // =========================================================================
  // POLLING INTERVALS & TIMEOUTS
  // =========================================================================

  /// Initial polling interval for nascent jobs (just uploaded)
  /// Used for: checking if backend has acknowledged and started processing
  /// Value: 2 seconds
  /// Rationale: User expects feedback quickly after upload completes
  static const Duration initialPollingInterval = Duration(seconds: 2);

  /// Active polling interval for jobs in progress (transcribing/summarizing)
  /// Used for: checking status while actual work is happening
  /// Value: 5 seconds
  /// Rationale: Provides reasonable balance between responsiveness and server load
  static const Duration activePollingInterval = Duration(seconds: 5);

  /// Slow polling interval for jobs that are stalled or backgrounded
  /// Used for: checking on abandoned or background jobs
  /// Value: 30 seconds
  /// Rationale: Reduces request volume for jobs user is not actively monitoring
  static const Duration slowPollingInterval = Duration(seconds: 30);

  /// Maximum total time to wait for transcription to complete
  /// Used for: upper bound on active polling attempts
  /// Value: 15 minutes (900 seconds, ~= 180 active polls at 5s interval)
  /// Rationale: Covers typical debate speeches (5-20 min) + backend processing overhead
  /// If exceeded: polling stops and user sees timeout error with manual retry option
  static const Duration transcriptionTimeoutBudget = Duration(minutes: 15);

  /// Maximum total time to wait for summarization to complete
  /// Used for: upper bound on summarize polling attempts
  /// Value: 2 minutes (120 seconds, ~= 24 active polls at 5s interval)
  /// Rationale: Summarization (Groq) is typically faster than transcription
  /// If exceeded: show timeout error; user can manually retry
  static const Duration summarizationTimeoutBudget = Duration(minutes: 2);

  /// Maximum total time to wait for job to reach any terminal state (completed or failed)
  /// Used for: safety net catch-all timeout for entire job lifecycle
  /// Value: 20 minutes (1200 seconds)
  /// Rationale: Should never hit this in normal operation; prevents stuck jobs indefinitely
  static const Duration maxJobLifetime = Duration(minutes: 20);

  // =========================================================================
  // BACKOFF STRATEGY
  // =========================================================================

  /// Enable exponential backoff (true) or fixed interval (false)
  /// Exponential backoff: 2s -> 4s -> 8s -> 16s -> 30s (capped)
  /// Fixed interval: always 5s
  /// Recommended: true (reduces server load on long-running jobs)
  static const bool enableExponentialBackoff = true;

  /// Base interval for exponential backoff calculation
  /// Each retry: baseInterval * (2 ^ attemptNumber), capped at maxBackoffInterval
  /// Value: 1 second
  static const Duration backoffBaseInterval = Duration(seconds: 1);

  /// Maximum backoff interval (exponential backoff will never exceed this)
  /// Used as ceiling for: min(baseInterval * 2^n, maxBackoffInterval)
  /// Value: 30 seconds
  static const Duration maxBackoffInterval = Duration(seconds: 30);

  // =========================================================================
  // RETRY LOGIC
  // =========================================================================

  /// Maximum number of polling attempts before declaring timeout
  /// Calculated as: transcriptionTimeoutBudget / activePollingInterval = 180
  /// If user manually retries: counter resets
  static const int maxTranscriptionPollingAttempts = (900 ~/ 5); // 180 attempts

  /// Maximum number of polling attempts for summarization
  /// Calculated as: summarizationTimeoutBudget / activePollingInterval = 24
  static const int maxSummarizationPollingAttempts = (120 ~/ 5); // 24 attempts

  /// Maximum number of times user can trigger a manual retry
  /// After this many retries, show error and suggest contacting support
  /// Value: 3 (user can retry up to 4 times total: original + 3 retries)
  static const int maxManualRetries = 3;

  /// Which HTTP status codes should trigger an automatic retry (transparent to user)
  /// These are considered transient failures (server temporarily down, etc.)
  /// User may trigger manual retry if polling ends due to non-retryable error
  static const Set<int> retryableHttpStatuses = {
    408, // Request Timeout
    429, // Too Many Requests
    500, // Internal Server Error
    502, // Bad Gateway
    503, // Service Unavailable
    504, // Gateway Timeout
  };

  // =========================================================================
  // STATE-SPECIFIC BEHAVIOR
  // =========================================================================

  /// Polling behavior mapping for each job status
  /// Format: {status: (interval, isActive)}
  /// isActive: true = counts toward timeout budget, false = background polling
  ///
  /// Logic:
  ///   - uploaded: Use initialPollingInterval (quick feedback)
  ///   - transcribing: Use activePollingInterval (user waiting)
  ///   - transcribed: No polling (waiting for user to click Summarize)
  ///   - summarizing: Use activePollingInterval (user waiting)
  ///   - completed/failed: Stop polling (terminal states)
  static Map<String, (Duration interval, bool isActive)> getPollingBehavior() {
    return {
      'uploaded': (initialPollingInterval, true),
      'transcribing': (activePollingInterval, true),
      'transcribed': (Duration.zero, false), // No polling; user action required
      'summarizing': (activePollingInterval, true),
      'completed': (Duration.zero, false), // Terminal; no polling
      'failed': (Duration.zero, false), // Terminal; no polling
    };
  }

  // =========================================================================
  // UI/UX FEEDBACK TIMING
  // =========================================================================

  /// Delay before showing "taking longer than expected" message
  /// If a single polling attempt takes longer than this, show warning
  /// Value: 10 seconds
  static const Duration slowResponseThreshold = Duration(seconds: 10);

  /// Delay before collapsing the loading indicator to a smaller badge
  /// Reduces visual clutter if job continues to process in background
  /// Value: 30 seconds
  static const Duration collapseLoadingAfter = Duration(seconds: 30);

  // =========================================================================
  // HELPER METHODS
  // =========================================================================

  /// Calculates next polling interval using exponential backoff if enabled
  /// Parameters:
  ///   - currentAttempt: Zero-indexed poll attempt number
  ///   - defaultInterval: Interval to use if backoff disabled
  /// Returns: Duration to wait before next poll
  static Duration calculateNextInterval(
      int currentAttempt, Duration defaultInterval) {
    if (!enableExponentialBackoff) {
      return defaultInterval;
    }

    final exponentialInterval =
        backoffBaseInterval * (1 << currentAttempt); // 2^attempt
    final cappedInterval = exponentialInterval > maxBackoffInterval
        ? maxBackoffInterval
        : exponentialInterval;

    return cappedInterval;
  }

  /// Determines if an HTTP status code should be automatically retried
  static bool isRetryableStatus(int statusCode) {
    return retryableHttpStatuses.contains(statusCode);
  }

  /// Determines if a job should continue polling based on current status
  static bool shouldContinuePolling(String jobStatus) {
    return jobStatus == 'transcribing' ||
        jobStatus == 'summarizing' ||
        jobStatus == 'uploaded';
  }

  /// Gets human-readable timeout explanation for user
  static String getTimeoutMessage(String context) {
    // context: 'transcription', 'summarization', or 'job'
    switch (context) {
      case 'transcription':
        return 'Transcription is taking longer than expected. '
            'Please check your internet connection and try again.';
      case 'summarization':
        return 'Summarization is taking longer than expected. '
            'Please try again in a moment.';
      case 'job':
        return 'Job processing has exceeded the time limit. '
            'Please try again or contact support if the issue persists.';
      default:
        return 'Processing timed out. Please try again.';
    }
  }
}

/// Helper class for tracking polling state and deciding when to stop
class PollingTracker {
  int transcriptionAttempts = 0;
  int summarizationAttempts = 0;
  int manualRetries = 0;
  DateTime? startTime;
  DateTime? transcriptionStartTime;
  DateTime? summarizationStartTime;

  /// Increments transcription polling counter and checks if limit exceeded
  bool shouldContinueTranscriptionPolling() {
    transcriptionAttempts++;
    transcriptionStartTime ??= DateTime.now();

    final elapsed = DateTime.now().difference(transcriptionStartTime!);
    return transcriptionAttempts <
            PollingConfig.maxTranscriptionPollingAttempts &&
        elapsed < PollingConfig.transcriptionTimeoutBudget;
  }

  /// Increments summarization polling counter and checks if limit exceeded
  bool shouldContinueSummarizationPolling() {
    summarizationAttempts++;
    summarizationStartTime ??= DateTime.now();

    final elapsed = DateTime.now().difference(summarizationStartTime!);
    return summarizationAttempts <
            PollingConfig.maxSummarizationPollingAttempts &&
        elapsed < PollingConfig.summarizationTimeoutBudget;
  }

  /// Resets counters for a manual retry attempt
  void resetForManualRetry() {
    transcriptionAttempts = 0;
    summarizationAttempts = 0;
    transcriptionStartTime = null;
    summarizationStartTime = null;
    manualRetries++;
  }

  /// Checks if user has exceeded maximum manual retry attempts
  bool canRetryManually() {
    return manualRetries < PollingConfig.maxManualRetries;
  }

  /// Gets remaining manual retry attempts
  int remainingManualRetries() {
    return (PollingConfig.maxManualRetries - manualRetries)
        .clamp(0, PollingConfig.maxManualRetries);
  }

  /// Resets all tracking (for new job)
  void reset() {
    transcriptionAttempts = 0;
    summarizationAttempts = 0;
    manualRetries = 0;
    startTime = null;
    transcriptionStartTime = null;
    summarizationStartTime = null;
  }

  @override
  String toString() =>
      'PollingTracker(transcription=$transcriptionAttempts, summarization=$summarizationAttempts, retries=$manualRetries)';
}
