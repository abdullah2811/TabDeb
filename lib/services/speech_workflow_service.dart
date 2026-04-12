import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/polling_config.dart';
import '../models/api_response.dart';
import '../models/speech_job.dart';
import 'speech_api_service.dart';

class SpeechWorkflowService {
  SpeechWorkflowService({SpeechApiService? apiService})
      : _apiService = apiService ?? SpeechApiService();

  final SpeechApiService _apiService;

  Future<SpeechJob> transcribeFromRecording({
    required String recordingPath,
    int? durationSeconds,
    String? tournamentId,
  }) async {
    final bytes = await _readRecordingBytes(recordingPath);

    final createResponse = await _apiService.createSpeechJob(
      CreateSpeechJobRequest(
        audioFileSize: bytes.length,
        durationSeconds: durationSeconds,
        tournamentId: tournamentId,
      ),
    );

    await _apiService.uploadAudioToSignedUrl(createResponse.uploadUrl, bytes);

    final transcribedJob = await _pollUntil(
      jobId: createResponse.jobId,
      isDone: (job) =>
          job.status == SpeechJobStatus.transcribed ||
          job.status == SpeechJobStatus.failed,
      timeoutBudget: PollingConfig.transcriptionTimeoutBudget,
      timeoutMessage: PollingConfig.getTimeoutMessage('transcription'),
    );

    if (transcribedJob.status == SpeechJobStatus.failed) {
      throw Exception(transcribedJob.error ?? 'Transcription failed');
    }

    return transcribedJob;
  }

  Future<SpeechJob> summarizeJob({
    required String jobId,
    int? maxLength,
  }) async {
    await _apiService.triggerSummarization(jobId, maxLength: maxLength);

    final completedJob = await _pollUntil(
      jobId: jobId,
      isDone: (job) =>
          job.status == SpeechJobStatus.completed ||
          job.status == SpeechJobStatus.failed,
      timeoutBudget: PollingConfig.summarizationTimeoutBudget,
      timeoutMessage: PollingConfig.getTimeoutMessage('summarization'),
    );

    if (completedJob.status == SpeechJobStatus.failed) {
      throw Exception(completedJob.error ?? 'Summarization failed');
    }

    return completedJob;
  }

  Future<SpeechJob> _pollUntil({
    required String jobId,
    required bool Function(SpeechJob job) isDone,
    required Duration timeoutBudget,
    required String timeoutMessage,
  }) async {
    final startedAt = DateTime.now();
    var attempt = 0;

    while (DateTime.now().difference(startedAt) < timeoutBudget) {
      final response = await _apiService.getSpeechJob(jobId);
      final job = response.toSpeechJob();
      if (isDone(job)) {
        return job;
      }

      final interval = PollingConfig.calculateNextInterval(
        attempt,
        PollingConfig.activePollingInterval,
      );
      attempt++;
      await Future<void>.delayed(interval);
    }

    throw Exception(timeoutMessage);
  }

  Future<Uint8List> _readRecordingBytes(String path) async {
    if (kIsWeb && path.startsWith('blob:')) {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      throw Exception('Failed to read web recording data');
    }

    final file = File(path);
    final exists = await file.exists();
    if (!exists) {
      throw Exception('Recording file not found: $path');
    }
    return file.readAsBytes();
  }
}
