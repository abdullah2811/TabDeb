import 'package:flutter/material.dart';

import '../models/speech_job.dart';
import '../services/speech_pdf_service.dart';
import '../services/speech_workflow_service.dart';

class SpeechResultScreen extends StatefulWidget {
  const SpeechResultScreen({super.key, required this.initialJob});

  final SpeechJob initialJob;

  @override
  State<SpeechResultScreen> createState() => _SpeechResultScreenState();
}

class _SpeechResultScreenState extends State<SpeechResultScreen> {
  late SpeechJob _job;
  late SpeechWorkflowService _workflowService;
  late SpeechPdfService _pdfService;

  bool _isSummarizing = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    _workflowService = SpeechWorkflowService();
    _pdfService = SpeechPdfService();
  }

  bool get _hasSummary => (_job.summary ?? '').trim().isNotEmpty;

  Future<void> _summarize() async {
    if ((_job.transcript ?? '').trim().isEmpty) {
      _showError('Transcript is empty.');
      return;
    }

    setState(() => _isSummarizing = true);
    try {
      final updated = await _workflowService.summarizeJob(jobId: _job.id);
      setState(() {
        _job = updated;
      });
      _showInfo('Summary generated successfully.');
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    final transcript = (_job.transcript ?? '').trim();
    final summary = (_job.summary ?? '').trim();

    if (transcript.isEmpty || summary.isEmpty) {
      _showError('Transcript and summary are required for PDF export.');
      return;
    }

    setState(() => _isExporting = true);
    try {
      await _pdfService.exportTranscriptAndSummary(
        transcript: transcript,
        summary: summary,
      );
      _showInfo('PDF export opened.');
    } catch (_) {
      _showError('Failed to export PDF.');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech Results'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(),
                const SizedBox(height: 16),
                _buildTranscriptCard(),
                const SizedBox(height: 16),
                _buildSummaryCard(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isSummarizing || _isExporting ? null : _summarize,
                        icon: const Icon(Icons.lightbulb),
                        label: Text(
                            _isSummarizing ? 'Summarizing...' : 'AI Summarize'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isSummarizing || _isExporting || !_hasSummary
                                ? null
                                : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label:
                            Text(_isExporting ? 'Exporting...' : 'Export PDF'),
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSummarizing || _isExporting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.done),
                    label: const Text('Done'),
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
          if (_isSummarizing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                  minHeight: 3, color: Colors.green.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Status: ${_job.statusLabel}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transcript',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            (_job.transcript ?? '').trim().isEmpty
                ? 'No transcript available.'
                : _job.transcript!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = (_job.summary ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            summary.isEmpty
                ? 'No summary generated yet. Tap AI Summarize.'
                : summary,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
