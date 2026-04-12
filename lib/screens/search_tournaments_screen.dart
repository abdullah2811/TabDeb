import 'package:tabdeb/screens/tournament_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tournament.dart';

class SearchTournamentsScreen extends StatefulWidget {
  final bool isGuest;

  const SearchTournamentsScreen({Key? key, this.isGuest = false})
      : super(key: key);

  @override
  State<SearchTournamentsScreen> createState() =>
      _SearchTournamentsScreenState();
}

class _SearchTournamentsScreenState extends State<SearchTournamentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Tournament> _allTournaments = [];
  List<Tournament> _filteredTournaments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .get();

      // Only load tournaments where currentSegmentIndex == -1 OR isClosed == true
      // Exclude running tournaments (currentSegmentIndex >= 0 AND isClosed == false)
      final tournaments = querySnapshot.docs
          .map((doc) => Tournament.fromJson(doc.data()))
          .where((tournament) {
        final isUpcoming =
            tournament.currentSegmentIndex == -1 && !tournament.isClosed;
        final isCompleted = tournament.isClosed;
        return isUpcoming || isCompleted;
      }).toList();

      setState(() {
        _allTournaments = tournaments;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tournaments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTournamentStatus(Tournament tournament) {
    // Determine status based on currentSegmentIndex and isClosed
    if (tournament.isClosed) {
      return 'Completed';
    } else if (tournament.currentSegmentIndex == -1) {
      return 'Upcoming';
    } else {
      return 'Active';
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    _filteredTournaments = _allTournaments.where((tournament) {
      // Apply status filter
      final status = _getTournamentStatus(tournament);
      bool matchesFilter = true;

      if (_selectedFilter == 'Completed') {
        matchesFilter = status == 'Completed';
      } else if (_selectedFilter == 'Upcoming') {
        matchesFilter = status == 'Upcoming';
      } else if (_selectedFilter == '2025') {
        matchesFilter = tournament.tournamentStartingDate.year == 2025;
      } else if (_selectedFilter == '2026') {
        matchesFilter = tournament.tournamentStartingDate.year == 2026;
      }
      // 'All' shows everything

      if (!matchesFilter) return false;

      // Apply search query
      if (query.isNotEmpty) {
        return tournament.tournamentName.toLowerCase().contains(query) ||
            tournament.tournamentClubName.toLowerCase().contains(query) ||
            (tournament.tournamentLocation?.toLowerCase().contains(query) ??
                false) ||
            tournament.tournamentStartingDate.year.toString().contains(query);
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Search Tournaments'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar Section
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        hintText: 'Search by name, club, or year...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon:
                                    const Icon(Icons.clear, color: Colors.grey),
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
                      onChanged: (value) {
                        setState(() {
                          _applyFilters();
                        });
                      },
                    ),
                  ),
                ),

                // Filter Chips
                Container(
                  height: 50,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Upcoming'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed'),
                      const SizedBox(width: 8),
                      _buildFilterChip('2026'),
                      const SizedBox(width: 8),
                      _buildFilterChip('2025'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Results Count
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  _isLoading
                      ? 'Loading...'
                      : '${_filteredTournaments.length} tournaments found',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _showSortOptions(context);
                  },
                  icon: const Icon(Icons.sort, size: 18),
                  label: const Text('Sort'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // Tournament List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredTournaments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tournaments found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredTournaments.length,
                        itemBuilder: (context, index) {
                          final tournament = _filteredTournaments[index];
                          return _buildTournamentCard(tournament: tournament);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color:
              isSelected ? const Color.fromARGB(255, 7, 2, 2) : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          _applyFilters();
        });
      },
      backgroundColor: Colors.blue.shade600,
      selectedColor: Colors.white,
      checkmarkColor: Colors.blue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildTournamentCard({required Tournament tournament}) {
    // Determine status based on currentSegmentIndex and isClosed
    final status = _getTournamentStatus(tournament);
    Color statusColor;
    Color statusBgColor;

    if (status == 'Upcoming') {
      statusColor = Colors.orange;
      statusBgColor = Colors.orange.shade50;
    } else if (status == 'Completed') {
      statusColor = Colors.grey;
      statusBgColor = Colors.grey.shade200;
    } else {
      statusColor = Colors.green;
      statusBgColor = Colors.green.shade50;
    }

    // Format dates
    final startDate =
        '${tournament.tournamentStartingDate.month}/${tournament.tournamentStartingDate.day}/${tournament.tournamentStartingDate.year}';
    final endDate =
        '${tournament.tournamentEndingDate.month}/${tournament.tournamentEndingDate.day}/${tournament.tournamentEndingDate.year}';
    final dateRange =
        startDate == endDate ? startDate : '$startDate - $endDate';

    // Get segment name
    String formattedSegment = 'N/A';
    if (tournament.tournamentSegments != null &&
        tournament.currentSegmentIndex >= 0 &&
        tournament.currentSegmentIndex <
            tournament.tournamentSegments!.length) {
      formattedSegment = tournament
          .tournamentSegments![tournament.currentSegmentIndex].segmentName;
    }

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
              // Header Row
              Row(
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Year Badge
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

              // Tournament Name
              Text(
                tournament.tournamentName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              // Club Name
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

              // Created By
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tournament.createdByUserID ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Location
              if (tournament.tournamentLocation != null &&
                  tournament.tournamentLocation!.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tournament.tournamentLocation!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),

              if (tournament.tournamentLocation != null &&
                  tournament.tournamentLocation!.isNotEmpty)
                const SizedBox(height: 6),

              // Date
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    dateRange,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Current Segment & Teams
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timeline,
                            size: 14, color: Colors.purple.shade700),
                        const SizedBox(width: 6),
                        Text(
                          formattedSegment,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.purple.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups,
                            size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '${tournament.numberOfTeamsInTournament} Teams',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Action Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TournamentDetailsScreen(
                            currentTournament: tournament,
                            isGuest: widget.isGuest),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort By',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date (Newest First)'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement sort
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date (Oldest First)'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement sort
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Name (A-Z)'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement sort
                },
              ),
              ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('Number of Teams'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement sort
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
