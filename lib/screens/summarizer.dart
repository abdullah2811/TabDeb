import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../services/speech_workflow_service.dart';
import 'speech_result_screen.dart';

class SummarizerScreen extends StatefulWidget {
  const SummarizerScreen({Key? key}) : super(key: key);

  @override
  State<SummarizerScreen> createState() => _SummarizerScreenState();
}

class _SummarizerScreenState extends State<SummarizerScreen> {
  late AudioRecorder _audioRecorder;
  late SpeechWorkflowService _workflowService;

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isTranscribing = false;

  String? _recordingPath;
  DateTime? _recordingStartedAt;
  String _transcriptionStageMessage = 'Preparing transcription...';

  bool get _isBusy => _isTranscribing;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _workflowService = SpeechWorkflowService();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showErrorSnackBar('Microphone permission is required');
        return;
      }

      final generatedPath =
          'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: generatedPath,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingPath = null;
        _recordingStartedAt = DateTime.now();
      });
    } catch (_) {
      _showErrorSnackBar('Failed to start recording');
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      setState(() => _isPaused = true);
    } catch (_) {
      _showErrorSnackBar('Failed to pause recording');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      setState(() => _isPaused = false);
    } catch (_) {
      _showErrorSnackBar('Failed to resume recording');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final String? path = await _audioRecorder.stop();
      if (path == null || path.isEmpty) {
        _showErrorSnackBar('No recording was captured');
        return;
      }

      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingPath = path;
      });

      _showTranscriptDialog();
    } catch (_) {
      _showErrorSnackBar('Failed to stop recording');
    }
  }

  void _showTranscriptDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Transcribe Audio?'),
        content:
            const Text('Would you like to transcribe this recording to text?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToDashboard();
            },
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _transcribeAndOpenResult();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _transcribeAndOpenResult() async {
    if (_recordingPath == null || _recordingPath!.isEmpty) {
      _showErrorSnackBar('Please record audio first');
      return;
    }

    setState(() {
      _isTranscribing = true;
      _transcriptionStageMessage = 'Uploading and transcribing your audio...';
    });

    try {
      final started = _recordingStartedAt;
      final durationSeconds =
          started == null ? null : DateTime.now().difference(started).inSeconds;

      final job = await _workflowService.transcribeFromRecording(
        recordingPath: _recordingPath!,
        durationSeconds: durationSeconds,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SpeechResultScreen(initialJob: job),
        ),
      );
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isTranscribing = false);
      }
    }
  }

  void _navigateToDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Summarization'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _buildRecordingView(),
          if (_isBusy) _buildTranscriptionOverlay(),
        ],
      ),
    );
  }

  Widget _buildRecordingView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _isRecording ? Colors.red.shade100 : Colors.blue.shade100,
                ),
                child: Icon(
                  Icons.mic,
                  size: 56,
                  color: _isRecording ? Colors.red : Colors.blue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isRecording
                    ? (_isPaused ? 'Recording Paused' : 'Recording in Progress')
                    : 'Ready to Record',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isRecording
                          ? Colors.red.shade700
                          : Colors.blue.shade800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stop recording to begin transcript generation and AI summary.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'How It Works',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '1. Record your speech\n2. Confirm transcription\n3. Review transcript\n4. Tap AI Summarize\n5. Export PDF report',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (!_isRecording)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _startRecording,
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Recording'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (_isRecording)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBusy
                            ? null
                            : (_isPaused ? _resumeRecording : _pauseRecording),
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                        label: Text(_isPaused ? 'Resume' : 'Pause'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isBusy ? null : _stopRecording,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _navigateToDashboard,
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptionOverlay() {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                'Processing Audio',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _transcriptionStageMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
