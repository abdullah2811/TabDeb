import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabdeb/models/tournament.dart';
import 'package:tabdeb/models/user.dart';
import 'package:tabdeb/screens/add_teams_screen.dart';
import 'package:tabdeb/screens/matchup_screen.dart';
import 'package:tabdeb/screens/tournament_details_screen.dart';
import 'package:tabdeb/screens/tournament_roadmap_screen.dart';
import 'package:flutter/material.dart';

class OwnTournamentsScreen extends StatefulWidget {
  final User currentUser;

  const OwnTournamentsScreen({Key? key, required this.currentUser})
      : super(key: key);

  @override
  State<OwnTournamentsScreen> createState() => _OwnTournamentsScreenState();
}

class _OwnTournamentsScreenState extends State<OwnTournamentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Tournament> _allTournaments =
      []; // It will be used when sorting or filtering implementations are added
  List<Tournament> _filteredTournaments = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final results = _filteredTournaments.where((t) {
      if (query.isEmpty) return true;

      // Get current segment name safely (currentSegmentIndex could be -1)
      String segmentName = '';
      if (t.currentSegmentIndex >= 0 &&
          t.tournamentSegments != null &&
          t.currentSegmentIndex < t.tournamentSegments!.length) {
        segmentName = t.tournamentSegments![t.currentSegmentIndex].segmentName
            .toLowerCase();
      }

      // Search in tournament name, club name, segment name, and location
      return t.tournamentName.toLowerCase().contains(query) ||
          t.tournamentClubName.toLowerCase().contains(query) ||
          segmentName.contains(query) ||
          (t.tournamentLocation?.toLowerCase().contains(query) ?? false) ||
          (t.tournamentDescription?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Tournaments'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search my tournaments...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                    ? const Center(
                        child: Text(
                          'No tournaments found.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final tournament = results[index];
                          return _buildTournamentCard(tournament);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all tournaments that the user is running
      final snapshot =
          await FirebaseFirestore.instance.collection('tournaments').get();

      final allTournaments =
          snapshot.docs.map((doc) => Tournament.fromJson(doc.data())).toList();

      // Filter tournaments where the user is either the creator or a co-owner
      final userTournaments = allTournaments.where((tournament) {
        final isCreator =
            tournament.createdByUserID == widget.currentUser.userID;
        final isCoOwner = tournament.usersRunningTheTournament
            .any((user) => user.userID == widget.currentUser.userID);
        return isCreator || isCoOwner;
      }).toList();

      // Sort by creation date or starting date, newest first
      userTournaments.sort((a, b) {
        final aDate = a.createdAt ?? a.tournamentStartingDate;
        final bDate = b.createdAt ?? b.tournamentStartingDate;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _allTournaments = userTournaments;
        _filteredTournaments = userTournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tournaments: $e')),
        );
      }
    }
  }

  String _getCurrentSegmentName(Tournament tournament) {
    if (tournament.currentSegmentIndex < 0) {
      return 'Registration';
    }
    if (tournament.isClosed) {
      return 'Tournament Closed';
    }
    if (tournament.tournamentSegments == null ||
        tournament.currentSegmentIndex >=
            tournament.tournamentSegments!.length) {
      return 'Unknown';
    }
    return tournament
        .tournamentSegments![tournament.currentSegmentIndex].segmentName;
  }

  Widget _buildTournamentCard(Tournament tournament) {
    final now = DateTime.now();
    final isUpcoming = now.isBefore(tournament.tournamentStartingDate);
    final isCompleted = now.isAfter(tournament.tournamentEndingDate);
    final isActive = !isUpcoming && !isCompleted;

    String status;
    if (isUpcoming) {
      status = 'Upcoming';
    } else if (isCompleted || tournament.isClosed) {
      status = 'Completed';
    } else {
      status = 'Active';
    }

    final additionClosed = tournament.teamAdditionClosed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to tournament details
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            color: isActive
                                ? Colors.green.shade900
                                : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (tournament.isClosed == false)
                    TextButton.icon(
                      onPressed: () => _editTournament(tournament),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  const SizedBox(width: 4),
                  if (tournament.isClosed == false)
                    TextButton.icon(
                      onPressed: () => _confirmDeleteTournament(tournament),
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${tournament.tournamentStartingDate.year}',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                tournament.tournamentName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.school, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tournament.tournamentClubName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.timeline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Segment: ${_getCurrentSegmentName(tournament)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.groups,
                    label: '${tournament.numberOfTeamsInTournament} Teams',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (tournament.isClosed == false)
                    TextButton.icon(
                      onPressed: () {
                        _showManageCoOwnersDialog(tournament);
                      },
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Manage Co-Owners'),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                  if (tournament.isClosed == false)
                    TextButton.icon(
                      onPressed: () async {
                        // Determine which screen to navigate to based on tournament state
                        if (!additionClosed) {
                          // Add Teams
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddTeamsScreen(currentTournament: tournament),
                            ),
                          );
                          if (result == true) {
                            _loadTournaments();
                          }
                        } else if (!tournament.roadmapLocked) {
                          // Configure Rounds
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TournamentRoadmapScreen(
                                  currentTournament: tournament),
                            ),
                          );
                          if (result == true) {
                            _loadTournaments();
                          }
                        } else {
                          // Generate Matchups
                          final refreshed = await Tournament.getTournament(
                              tournament.tournamentID);
                          if (refreshed != null && mounted) {
                            tournament = refreshed;
                          }
                          if (tournament.currentSegmentIndex == -1) {
                            tournament.proceedToNextSegment();
                          }

                          if (!mounted) return;

                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  MatchupScreen(currentTournament: tournament),
                            ),
                          );
                          if (result == true) {
                            _loadTournaments();
                          }
                        }
                      },
                      icon: Icon(
                        !additionClosed
                            ? Icons.build
                            : !tournament.roadmapLocked
                                ? Icons.arrow_forward
                                : Icons.settings,
                        size: 18,
                      ),
                      label: Text(
                        !additionClosed
                            ? 'Add Teams'
                            : !tournament.roadmapLocked
                                ? 'Configure Rounds'
                                : 'Generate Matchups',
                      ),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => TournamentDetailsScreen(
                                currentTournament: tournament)),
                      );
                      if (result == true) {
                        _loadTournaments();
                      }
                    },
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTournament(Tournament tournament) async {
    final nameCtrl = TextEditingController(text: tournament.tournamentName);
    final clubCtrl = TextEditingController(text: tournament.tournamentClubName);
    final locationCtrl =
        TextEditingController(text: tournament.tournamentLocation ?? '');
    final descriptionCtrl =
        TextEditingController(text: tournament.tournamentDescription ?? '');
    final maxTeamsCtrl =
        TextEditingController(text: tournament.maxTeams?.toString() ?? '');
    final prizePoolCtrl =
        TextEditingController(text: tournament.prizePool?.toString() ?? '');

    DateTime startDate = tournament.tournamentStartingDate;
    DateTime endDate = tournament.tournamentEndingDate;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (statefulContext, setLocalState) {
          Future<void> pickStart() async {
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: startDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setLocalState(() => startDate = picked);
            }
          }

          Future<void> pickEnd() async {
            final picked = await showDatePicker(
              context: dialogContext,
              initialDate: endDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setLocalState(() => endDate = picked);
            }
          }

          return AlertDialog(
            title: const Text('Edit Tournament'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextFieldCtrl(nameCtrl, 'Tournament Name', Icons.title),
                  const SizedBox(height: 10),
                  _buildTextFieldCtrl(clubCtrl, 'Club/Organizer', Icons.school),
                  const SizedBox(height: 10),
                  _buildTextFieldCtrl(
                      locationCtrl, 'Location', Icons.location_on),
                  const SizedBox(height: 10),
                  _buildTextFieldCtrl(
                      descriptionCtrl, 'Description', Icons.description,
                      maxLines: 3),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickStart,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                              'Start: ${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: pickEnd,
                          icon: const Icon(Icons.event),
                          label: Text(
                              'End: ${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTextFieldCtrl(
                    maxTeamsCtrl,
                    'Max Teams (optional)',
                    Icons.groups,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _buildTextFieldCtrl(
                    prizePoolCtrl,
                    'Prize Pool (optional)',
                    Icons.attach_money,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Basic validation
                  if (nameCtrl.text.trim().isEmpty ||
                      clubCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text('Name and Club are required.')),
                    );
                    return;
                  }

                  // Apply edits to model
                  tournament.tournamentName = nameCtrl.text.trim();
                  tournament.tournamentClubName = clubCtrl.text.trim();
                  tournament.tournamentLocation =
                      locationCtrl.text.trim().isEmpty
                          ? null
                          : locationCtrl.text.trim();
                  tournament.tournamentDescription =
                      descriptionCtrl.text.trim().isEmpty
                          ? null
                          : descriptionCtrl.text.trim();
                  tournament.tournamentStartingDate = startDate;
                  tournament.tournamentEndingDate = endDate;

                  final maxTeamsVal = int.tryParse(maxTeamsCtrl.text.trim());
                  final prizePoolVal =
                      double.tryParse(prizePoolCtrl.text.trim());

                  tournament.maxTeams = maxTeamsVal;
                  tournament.prizePool = prizePoolVal;

                  try {
                    await tournament.updateTournament();
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      _loadTournaments();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tournament updated.')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  void _confirmDeleteTournament(Tournament tournament) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Tournament'),
        content: Text(
            'Are you sure you want to delete "${tournament.tournamentName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                // deleteTournament() is async void; call and then reload
                tournament.deleteTournament();
                await Future.delayed(const Duration(milliseconds: 300));
                _loadTournaments();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tournament deleted.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete tournament: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldCtrl(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showManageCoOwnersDialog(Tournament tournament) {
    final isCreator = tournament.createdByUserID == widget.currentUser.userID;

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setLocalState) {
          return AlertDialog(
            title: const Text('Manage Co-Owners'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Co-Owners Section
                    const Text(
                      'Current Co-Owners',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (tournament.usersRunningTheTournament.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            'No co-owners added yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount:
                              tournament.usersRunningTheTournament.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user =
                                tournament.usersRunningTheTournament[index];
                            final isUserCreator =
                                user.userID == tournament.createdByUserID;

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                backgroundColor: isUserCreator
                                    ? Colors.amber.shade100
                                    : Colors.blue.shade100,
                                child: Icon(
                                  isUserCreator ? Icons.star : Icons.person,
                                  color: isUserCreator
                                      ? Colors.amber.shade700
                                      : Colors.blue.shade700,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                user.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    user.userID,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isUserCreator) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Creator',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isCreator && !isUserCreator
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Remove co-owner',
                                      onPressed: () {
                                        _confirmRemoveCoOwner(
                                          tournament,
                                          user,
                                          dialogContext,
                                          setLocalState,
                                        );
                                      },
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Add New Co-Owner Section
                    const Text(
                      'Add New Co-Owner',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showAddCoOwnerDialog(tournament);
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Search & Add Co-Owner'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                    if (!isCreator) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Only the tournament creator can remove co-owners.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmRemoveCoOwner(
    Tournament tournament,
    User user,
    BuildContext dialogContext,
    void Function(void Function()) setLocalState,
  ) {
    showDialog<void>(
      context: dialogContext,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Remove Co-Owner'),
        content: Text(
          'Are you sure you want to remove "${user.name}" as a co-owner of this tournament?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(confirmContext);
              try {
                await tournament.removeCoOwner(user, widget.currentUser.userID);
                setLocalState(() {}); // Refresh the dialog
                _loadTournaments(); // Refresh the list
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${user.name} removed as co-owner'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddCoOwnerDialog(Tournament tournament) {
    final searchController = TextEditingController();
    List<User> searchResults = [];
    bool isSearching = false;

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (statefulContext, setLocalState) {
          return AlertDialog(
            title: const Text('Add Co-Owner'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter user ID',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) async {
                      if (value.trim().isEmpty) {
                        setLocalState(() {
                          searchResults = [];
                        });
                        return;
                      }

                      setLocalState(() {
                        isSearching = true;
                      });

                      try {
                        final results =
                            await User.searchUsersByID(value.trim());
                        setLocalState(() {
                          searchResults = results;
                          isSearching = false;
                        });
                      } catch (e) {
                        setLocalState(() {
                          isSearching = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                                content: Text('Error searching users: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (searchResults.isEmpty && searchController.text.isNotEmpty)
                    const Text(
                      'No users found',
                      style: TextStyle(color: Colors.grey),
                    )
                  else if (searchResults.isNotEmpty)
                    SizedBox(
                      height: 200,
                      width: double.maxFinite,
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          final isAlreadyOwner = tournament
                              .usersRunningTheTournament
                              .any((u) => u.userID == user.userID);
                          final isCurrentUser =
                              user.userID == widget.currentUser.userID;

                          return ListTile(
                            title: Text(user.name),
                            subtitle: Text(user.userID),
                            enabled: !isAlreadyOwner && !isCurrentUser,
                            onTap: isAlreadyOwner || isCurrentUser
                                ? null
                                : () async {
                                    try {
                                      await tournament.addCoOwner(user);
                                      if (mounted) {
                                        Navigator.pop(dialogContext);
                                        _loadTournaments();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${user.name} added as co-owner',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(dialogContext)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error: ${e.toString()}'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            trailing: isAlreadyOwner
                                ? const Tooltip(
                                    message: 'Already a co-owner',
                                    child:
                                        Icon(Icons.check, color: Colors.green),
                                  )
                                : isCurrentUser
                                    ? const Tooltip(
                                        message: 'Current user',
                                        child: Icon(Icons.person,
                                            color: Colors.blue),
                                      )
                                    : null,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }
}
