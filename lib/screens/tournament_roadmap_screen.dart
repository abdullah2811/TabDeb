import 'package:tabdeb/models/tournament.dart';
import 'package:tabdeb/models/tournament_segment.dart';
import 'package:flutter/material.dart';

class TournamentRoadmapScreen extends StatefulWidget {
  final Tournament currentTournament;

  const TournamentRoadmapScreen({Key? key, required this.currentTournament})
      : super(key: key);

  @override
  State<TournamentRoadmapScreen> createState() =>
      _TournamentRoadmapScreenState();
}

class _TournamentRoadmapScreenState extends State<TournamentRoadmapScreen> {
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customTeamsController = TextEditingController();
  final TextEditingController _customQualifiedController =
      TextEditingController();

  late List<TournamentSegment> _segments;
  String _selectedSegmentType = 'Round 1 Tab';
  int _segmentIdCounter = 1;
  bool _isSaving = false;
  late int all;

  final List<String> _segmentTypes = [
    'Round 1 Tab',
    'Round 2 Tab',
    'Round 3 Tab',
    'Pre-Quarter Final',
    'Quarter Final',
    'Semi Final',
    'Grand Final',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    // Ensure UI list and model list reference the same object
    all = widget.currentTournament.numberOfTeamsInTournament;
    _segments = widget.currentTournament.tournamentSegments ?? [];
    widget.currentTournament.tournamentSegments = _segments;
    if (_segments.isNotEmpty) {
      _segmentIdCounter =
          _segments.map((s) => s.segmentID).reduce((a, b) => a > b ? a : b) + 1;
    }
  }

  Map<String, dynamic> get _segmentDefaults => {
        'Round 1 Tab': {'teams': all, 'qualified': 0, 'isTabRound': true},
        'Round 2 Tab': {'teams': all, 'qualified': 0, 'isTabRound': true},
        'Round 3 Tab': {'teams': all, 'qualified': 0, 'isTabRound': true},
        'Pre-Quarter Final': {'teams': 16, 'qualified': 0, 'isTabRound': false},
        'Quarter Final': {'teams': 8, 'qualified': 0, 'isTabRound': false},
        'Semi Final': {'teams': 4, 'qualified': 0, 'isTabRound': false},
        'Grand Final': {'teams': 2, 'qualified': 0, 'isTabRound': false},
      };

  @override
  void dispose() {
    _customNameController.dispose();
    _customTeamsController.dispose();
    _customQualifiedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Roadmap'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure Tournament Segments',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Dropdown for segment type
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String>(
                value: _selectedSegmentType,
                isExpanded: true,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down),
                items: _segmentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSegmentType = value!;
                    _customNameController.clear();
                    _customTeamsController.clear();
                    _customQualifiedController.clear();
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Custom fields if Custom is selected
            if (_selectedSegmentType == 'Custom') ...[
              _buildTextField(
                controller: _customNameController,
                label: 'Custom Segment Name',
                icon: Icons.label,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customTeamsController,
                label: 'Number of Teams',
                icon: Icons.groups,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customQualifiedController,
                label: 'Auto-Qualified Teams',
                icon: Icons.check_circle,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],

            // Add Segment Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addSegment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Segment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Roadmap Diagram
            if (_segments.isNotEmpty) ...[
              const Text(
                'Tournament Roadmap',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildRoadmapDiagram(),
              const SizedBox(height: 24),
            ],

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRoadmap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Roadmap',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapDiagram() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (int i = 0; i < _segments.length; i++) ...[
              _buildSegmentCard(_segments[i], i),
              if (i < _segments.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Icon(Icons.arrow_downward, color: Colors.blue.shade700),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentCard(TournamentSegment segment, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            child: Text('${index + 1}'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.segmentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Teams: ${segment.numberOfTeamsInSegment}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (segment.numberOfTeamsAutoQualifiedForNextRound > 0)
                  Text(
                    'Auto-qualified: ${segment.numberOfTeamsAutoQualifiedForNextRound}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                _segments.removeAt(index);
                // Persist the updated segments list once
                widget.currentTournament.updateTournament();
              });
            },
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  void _addSegment() {
    String segmentName;
    int numberOfTeams;
    int numberOfQualified;
    bool isATabRound = false;

    if (_selectedSegmentType == 'Custom') {
      segmentName = _customNameController.text.trim();
      numberOfTeams = int.tryParse(_customTeamsController.text.trim()) ?? 0;
      numberOfQualified =
          int.tryParse(_customQualifiedController.text.trim()) ?? 0;

      if (segmentName.isEmpty || numberOfTeams <= 0) {
        _showSnack('Please provide valid segment name and number of teams.');
        return;
      }
    } else {
      segmentName = _selectedSegmentType;
      numberOfTeams = _segmentDefaults[_selectedSegmentType]['teams'];
      numberOfQualified = _segmentDefaults[_selectedSegmentType]['qualified'];
      isATabRound =
          _segmentDefaults[_selectedSegmentType]['isTabRound'] as bool;
    }

    setState(() {
      final newSegment = TournamentSegment(
        segmentName: segmentName,
        segmentID: _segmentIdCounter++,
        numberOfTeamsInSegment: numberOfTeams,
        numberOfTeamsAutoQualifiedForNextRound: numberOfQualified,
        isTabRound: isATabRound,
      );
      _segments.add(newSegment);
    });

    // Persist the updated segments list once
    widget.currentTournament.updateTournament();
  }

  Future<void> _saveRoadmap() async {
    if (_segments.isEmpty) {
      _showSnack('Please add at least one segment.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Set the current segment to the first one if not already set
      widget.currentTournament.currentSegmentIndex = -1;
      // Lock the roadmap so it can't be edited anymore
      widget.currentTournament.roadmapLocked = true;

      await widget.currentTournament.updateTournament();
      _showSnack('Roadmap saved successfully.');
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Error saving roadmap: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
