import 'package:tabdeb/models/app.dart';
import 'package:tabdeb/models/tournament.dart';
import 'package:flutter/material.dart';
import '../models/debate_team.dart';
import '../models/debater.dart';

class AddTeamsScreen extends StatefulWidget {
  final Tournament currentTournament;
  const AddTeamsScreen({required this.currentTournament, Key? key})
      : super(key: key);

  @override
  State<AddTeamsScreen> createState() => _AddTeamsScreenState();
}

class _AddTeamsScreenState extends State<AddTeamsScreen> {
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _debaterOneController = TextEditingController();
  final TextEditingController _debaterTwoController = TextEditingController();
  final TextEditingController _debaterThreeController = TextEditingController();

  late List<DebateTeam> _teams;
  int _teamIdCounter = 1;
  int _debaterIdCounter = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Load teams from tournament if they exist
    _teams = widget.currentTournament.teamsInTheTournament ?? [];
    // Set counters based on existing data
    if (_teams.isNotEmpty) {
      _teamIdCounter =
          _teams.map((t) => t.teamID).reduce((a, b) => a > b ? a : b) + 1;
      for (var team in _teams) {
        for (var member in team.teamMembers) {
          if (member is Debater) {
            _debaterIdCounter = _debaterIdCounter > member.debaterID
                ? _debaterIdCounter
                : member.debaterID + 1;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _debaterOneController.dispose();
    _debaterTwoController.dispose();
    _debaterThreeController.dispose();
    super.dispose();
  }

  void _addTeam() {
    final teamName = _teamNameController.text.trim();
    final deb1 = _debaterOneController.text.trim();
    final deb2 = _debaterTwoController.text.trim();
    final deb3 = _debaterThreeController.text.trim();

    if (teamName.isEmpty || deb1.isEmpty || deb2.isEmpty || deb3.isEmpty) {
      _showSnack('Please enter team name and three debaters.');
      return;
    }

    final debaters = <Debater>[
      Debater(
          debaterID: _debaterIdCounter++,
          name: deb1,
          teamName: teamName,
          teamID: _teamIdCounter),
      Debater(
          debaterID: _debaterIdCounter++,
          name: deb2,
          teamName: teamName,
          teamID: _teamIdCounter),
      Debater(
          debaterID: _debaterIdCounter++,
          name: deb3,
          teamName: teamName,
          teamID: _teamIdCounter),
    ];

    final newTeam = DebateTeam(
      teamID: _teamIdCounter++,
      teamName: teamName,
      teamMembers: debaters,
    );

    setState(() {
      widget.currentTournament.addTeam(widget.currentTournament, newTeam);
      // Refresh _teams reference to reflect the updated list
      _teams = widget.currentTournament.teamsInTheTournament ?? [];
      _teamNameController.clear();
      _debaterOneController.clear();
      _debaterTwoController.clear();
      _debaterThreeController.clear();
    });

    _showSnack('Team "$teamName" added.');
  }

  void _editTeam(int index) {
    final team = _teams[index];
    final teamNameCtrl = TextEditingController(text: team.teamName);
    final deb1Ctrl = TextEditingController(
        text: team.teamMembers.isNotEmpty && team.teamMembers[0] is Debater
            ? (team.teamMembers[0] as Debater).name
            : '');
    final deb2Ctrl = TextEditingController(
        text: team.teamMembers.length > 1 && team.teamMembers[1] is Debater
            ? (team.teamMembers[1] as Debater).name
            : '');
    final deb3Ctrl = TextEditingController(
        text: team.teamMembers.length > 2 && team.teamMembers[2] is Debater
            ? (team.teamMembers[2] as Debater).name
            : '');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Team'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: teamNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Team Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deb1Ctrl,
                decoration: InputDecoration(
                  labelText: 'Debater 1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deb2Ctrl,
                decoration: InputDecoration(
                  labelText: 'Debater 2',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: deb3Ctrl,
                decoration: InputDecoration(
                  labelText: 'Debater 3',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = teamNameCtrl.text.trim();
              if (newName.isEmpty ||
                  deb1Ctrl.text.isEmpty ||
                  deb2Ctrl.text.isEmpty ||
                  deb3Ctrl.text.isEmpty) {
                _showSnack('Please fill all fields.');
                return;
              }
              setState(() {
                _teams[index].updateTeamName(newName);
                if (_teams[index].teamMembers.isNotEmpty &&
                    _teams[index].teamMembers[0] is Debater) {
                  (_teams[index].teamMembers[0] as Debater)
                      .updateName(deb1Ctrl.text.trim());
                }
                if (_teams[index].teamMembers.length > 1 &&
                    _teams[index].teamMembers[1] is Debater) {
                  (_teams[index].teamMembers[1] as Debater)
                      .updateName(deb2Ctrl.text.trim());
                }
                if (_teams[index].teamMembers.length > 2 &&
                    _teams[index].teamMembers[2] is Debater) {
                  (_teams[index].teamMembers[2] as Debater)
                      .updateName(deb3Ctrl.text.trim());
                }
                // Update tournament in Firebase
                widget.currentTournament.updateTournament();
              });
              Navigator.pop(context);
              _showSnack('Team updated successfully.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _removeTeam(int index) {
    final teamName = _teams[index].teamName;
    final team = _teams[index];

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Team'),
        content: Text('Are you sure you want to remove "$teamName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Use tournament method to remove team
                widget.currentTournament
                    .removeTeam(widget.currentTournament, team);
                // Refresh _teams reference to reflect the updated list
                _teams = widget.currentTournament.teamsInTheTournament ?? [];
              });
              Navigator.pop(context);
              _showSnack('Team "$teamName" removed.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _onAddIa() {
    _showSnack('Add IA will be implemented later.');
  }

  Future<void> _lockTeamList() async {
    setState(() {
      _isSaving = true;
    });

    try {
      widget.currentTournament.teamAdditionClosed = true;
      await widget.currentTournament.updateTournament();
      await App.incrementTeamsAndDebaters(_teams.length, _teams.length * 3);
      _showSnack('Team list locked.');
      Navigator.pop(context, true); // Return true to signal refresh needed
    } catch (e) {
      _showSnack('Error locking team list: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepare Teams'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Teams',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _teamNameController,
              label: 'Team Name',
              icon: Icons.group,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _debaterOneController,
              label: 'Debater 1',
              icon: Icons.person,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _debaterTwoController,
              label: 'Debater 2',
              icon: Icons.person,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _debaterThreeController,
              label: 'Debater 3',
              icon: Icons.person,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addTeam,
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
                  'Add Team',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _onAddIa,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text(
                'Add IA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _lockTeamList,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                    : const Icon(Icons.lock),
                label: Text(
                  _isSaving ? 'Locking...' : 'Lock the team list',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Teams (${_teams.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_teams.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No teams added yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              ..._teams.map((team) => _buildTeamTile(team)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamTile(DebateTeam team) {
    final index = _teams.indexOf(team);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
              team.teamName.isNotEmpty ? team.teamName[0].toUpperCase() : '?'),
        ),
        title: Text(team.teamName),
        subtitle: Text('${team.teamMembers.length} debaters'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editTeam(index),
              tooltip: 'Edit Team',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeTeam(index),
              tooltip: 'Remove Team',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
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
}
