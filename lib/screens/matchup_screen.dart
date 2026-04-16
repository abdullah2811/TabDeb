import 'package:tabdeb/models/debate_match.dart';
import 'package:tabdeb/models/tournament.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MatchupScreen extends StatefulWidget {
  final Tournament currentTournament;

  const MatchupScreen({Key? key, required this.currentTournament})
      : super(key: key);

  @override
  State<MatchupScreen> createState() => _MatchupScreenState();
}

class _MatchupScreenState extends State<MatchupScreen> {
  late List<DebateMatch> matches;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateMatches();
  }

  void _generateMatches() {
    final segments = widget.currentTournament.tournamentSegments;
    final idx = widget.currentTournament.currentSegmentIndex;

    if (segments != null && idx >= 0 && idx < segments.length) {
      matches = segments[idx].matchesInThisSegment ?? [];
    } else {
      matches = [];
    }
    setState(() {
      isLoading = false;
    });
  }

  bool get _allMatchesCompleted =>
      matches.isNotEmpty && matches.every((m) => m.isCompleted);

  bool get _isFinalSegment {
    final segments = widget.currentTournament.tournamentSegments;
    final currentSegment = widget.currentTournament.tournamentSegments !=
                null &&
            widget.currentTournament.currentSegmentIndex >= 0
        ? widget.currentTournament
            .tournamentSegments![widget.currentTournament.currentSegmentIndex]
        : null;
    if (segments == null || currentSegment == null) return false;
    return segments.last.segmentID == currentSegment.segmentID;
  }

  void _showEliminateTeamDialog() {
    final teams = widget.currentTournament.teamsInTheTournament ?? [];
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teams available to eliminate.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Eliminate a Team'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    team.teamName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Wins: ${team.teamWins} | Score: ${team.teamScore.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    tooltip: 'Eliminate Team',
                    onPressed: () => _confirmEliminateTeam(dialogContext, team),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmEliminateTeam(BuildContext dialogContext, dynamic team) {
    showDialog(
      context: dialogContext,
      builder: (confirmContext) => AlertDialog(
        title: const Text('Confirm Elimination'),
        content: Text(
          'Are you sure you want to eliminate "${team.teamName}" from the tournament?\n\nThis team will not participate in future rounds, but their existing match data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(confirmContext); // Close confirmation dialog
              Navigator.pop(dialogContext); // Close team list dialog

              try {
                // Remove team from teamsInTheTournament
                widget.currentTournament.teamsInTheTournament?.removeWhere(
                  (t) => t.teamID == team.teamID,
                );

                // Update Firestore
                await widget.currentTournament.updateTournament();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '"${team.teamName}" has been eliminated from the tournament.',
                      ),
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error eliminating team: $e')),
                  );
                }
              }
            },
            child: const Text('Eliminate'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToNextRound() async {
    try {
      widget.currentTournament.proceedToNextSegment();
      await widget.currentTournament.updateTournament();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proceeded to next round.')),
        );
        Navigator.pop(context, true); // Indicate refresh needed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error proceeding to next round: $e')),
        );
      }
    }
  }

  Future<void> _closeTournament() async {
    // Capture the parent context so we can pop the screen (not just the dialog)
    final parentContext = context;

    showDialog<void>(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Close Tournament'),
        content: const Text(
          'Are you sure you want to close this tournament? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); // Close the dialog first
              try {
                widget.currentTournament.isClosed = true;
                await widget.currentTournament.updateTournament();

                if (mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(content: Text('Tournament closed.')),
                  );
                  // Return to own_tournaments_screen and trigger refresh
                  Navigator.pop(parentContext, true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('Error closing tournament: $e')),
                  );
                }
              }
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    final segmentName = widget.currentTournament.tournamentSegments != null &&
            widget.currentTournament.currentSegmentIndex >= 0
        ? widget
            .currentTournament
            .tournamentSegments![widget.currentTournament.currentSegmentIndex]
            .segmentName
        : 'Round';

    // Load app icon
    final iconData = await rootBundle.load('assets/icons/app_icon.png');
    final iconImage = pw.MemoryImage(iconData.buffer.asUint8List());

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // TabDeb Branding Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(iconImage, width: 40, height: 40),
                pw.SizedBox(width: 12),
                pw.Text(
                  'TabDeb',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            // Tournament Header
            pw.Center(
              child: pw.Text(
                widget.currentTournament.tournamentName,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                segmentName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 16),

            // Matchups Table
            ...matches.asMap().entries.map((entry) {
              final index = entry.key;
              final match = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Match ${index + 1}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.Text(
                          'Venue: ${match.venue ?? 'TBD'}',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Government',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.blue600,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                match.teamA.teamName,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (match.isCompleted)
                                pw.Text(
                                  'Score: ${match.teamAScores.reduce((a, b) => a + b) + match.teamARebuttal}',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: pw.Text(
                            'VS',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'Opposition',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.red600,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                match.teamB.teamName,
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.right,
                              ),
                              if (match.isCompleted)
                                pw.Text(
                                  'Score: ${match.teamBScores.reduce((a, b) => a + b) + match.teamBRebuttal}',
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    // Show print/save dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${widget.currentTournament.tournamentName}_$segmentName'
          .replaceAll(' ', '_'),
    );
  }

  Future<void> _generateTeamsRankingPdf() async {
    final teams = widget.currentTournament.teamsInTheTournament ?? [];
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teams found.')),
      );
      return;
    }

    final sortedTeams = List.from(teams)
      ..sort((a, b) {
        if (b.teamWins != a.teamWins) {
          return b.teamWins.compareTo(a.teamWins);
        }
        return b.teamScore.compareTo(a.teamScore);
      });

    final segmentName = widget.currentTournament.tournamentSegments != null &&
            widget.currentTournament.currentSegmentIndex >= 0
        ? widget
            .currentTournament
            .tournamentSegments![widget.currentTournament.currentSegmentIndex]
            .segmentName
        : 'Round';

    // Load app icon
    final iconData = await rootBundle.load('assets/icons/app_icon.png');
    final iconImage = pw.MemoryImage(iconData.buffer.asUint8List());

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // TabDeb Branding Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(iconImage, width: 40, height: 40),
                pw.SizedBox(width: 12),
                pw.Text(
                  'TabDeb',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                widget.currentTournament.tournamentName,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Team Rankings - After $segmentName',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple800,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.purple100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('#',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Team Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Wins',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Losses',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Score',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...sortedTeams.asMap().entries.map((entry) {
                  final index = entry.key;
                  final team = entry.value;
                  final isTopThree = index < 3;
                  return pw.TableRow(
                    decoration: isTopThree
                        ? pw.BoxDecoration(
                            color: index == 0
                                ? PdfColors.amber50
                                : index == 1
                                    ? PdfColors.grey200
                                    : PdfColors.orange50,
                          )
                        : null,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${index + 1}',
                            style: isTopThree
                                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                                : null),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(team.teamName,
                            style: isTopThree
                                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                                : null),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${team.teamWins}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${team.teamLosses}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(team.teamScore.toStringAsFixed(1)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${widget.currentTournament.tournamentName}_Teams_Ranking'
          .replaceAll(' ', '_'),
    );
  }

  Future<void> _generateDebatersRankingPdf() async {
    final debaters = widget.currentTournament.debatersInTheTournament ?? [];
    if (debaters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No debaters found.')),
      );
      return;
    }

    final sortedDebaters = List.from(debaters)
      ..sort((a, b) => b.individualScore.compareTo(a.individualScore));

    final segmentName = widget.currentTournament.tournamentSegments != null &&
            widget.currentTournament.currentSegmentIndex >= 0
        ? widget
            .currentTournament
            .tournamentSegments![widget.currentTournament.currentSegmentIndex]
            .segmentName
        : 'Round';

    // Load app icon
    final iconData = await rootBundle.load('assets/icons/app_icon.png');
    final iconImage = pw.MemoryImage(iconData.buffer.asUint8List());

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // TabDeb Branding Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(iconImage, width: 40, height: 40),
                pw.SizedBox(width: 12),
                pw.Text(
                  'TabDeb',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                widget.currentTournament.tournamentName,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Debater Rankings - After $segmentName',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FixedColumnWidth(40),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.teal100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('#',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Debater Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Team',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total Score',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...sortedDebaters.asMap().entries.map((entry) {
                  final index = entry.key;
                  final debater = entry.value;
                  final isTopThree = index < 3;
                  return pw.TableRow(
                    decoration: isTopThree
                        ? pw.BoxDecoration(
                            color: index == 0
                                ? PdfColors.amber50
                                : index == 1
                                    ? PdfColors.grey200
                                    : PdfColors.orange50,
                          )
                        : null,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${index + 1}',
                            style: isTopThree
                                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                                : null),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(debater.name,
                            style: isTopThree
                                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                                : null),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          debater.teamName.isEmpty ? '-' : debater.teamName,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child:
                            pw.Text(debater.individualScore.toStringAsFixed(1)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${widget.currentTournament.tournamentName}_Debaters_Ranking'
          .replaceAll(' ', '_'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, false);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
              'Matchups - ${widget.currentTournament.tournamentSegments?[widget.currentTournament.currentSegmentIndex].segmentName ?? 'Round'}'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Download PDF',
              onPressed: _generatePdf,
            ),
            IconButton(
              icon: const Icon(Icons.leaderboard),
              tooltip: 'Show Leaderboard',
              onPressed: _showLeaderboardOptions,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : matches.isEmpty
                ? const Center(
                    child: Text(
                      'No matchups generated.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final match = matches[index];
                            return _buildMatchCard(match, index);
                          },
                        ),
                      ),
                      if (_allMatchesCompleted)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _generateTeamsRankingPdf,
                                  icon: const Icon(Icons.groups, size: 18),
                                  label: const Text('Teams PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _generateDebatersRankingPdf,
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Debaters PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_allMatchesCompleted && !_isFinalSegment)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _showEliminateTeamDialog,
                            icon: const Icon(Icons.person_remove),
                            label: const Text(
                              'Eliminate a Team',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                      if (_allMatchesCompleted)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton.icon(
                            onPressed: _isFinalSegment
                                ? _closeTournament
                                : _proceedToNextRound,
                            icon: Icon(
                              _isFinalSegment
                                  ? Icons.close
                                  : Icons.arrow_forward,
                            ),
                            label: Text(
                              _isFinalSegment
                                  ? 'Close Tournament'
                                  : 'Proceed to Next Round',
                              style: const TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _isFinalSegment ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildMatchCard(DebateMatch match, int index) {
    final venueText =
        match.venue != null ? 'Venue: ${match.venue}' : 'Venue: TBD';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Match ${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            venueText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${match.teamA.teamName} vs ${match.teamB.teamName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: match.isCompleted
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        match.isCompleted ? 'Completed' : 'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: match.isCompleted
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (match.isCompleted)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${match.teamA.teamName} : ${match.teamAScores.join(', ')}, ${match.teamARebuttal}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            // '${match.teamB.teamName} : ${match.teamBScores.join(', ')}',
                            // Show the rebuttal score as well
                            '${match.teamB.teamName} : ${match.teamBScores.join(', ')}, ${match.teamBRebuttal}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showScoresDialog(match),
                  icon: Icon(match.isCompleted ? Icons.edit : Icons.score,
                      size: 18),
                  label:
                      Text(match.isCompleted ? 'Edit Scores' : 'Submit Scores'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showScoresDialog(DebateMatch match) {
    final isEditing = match.isCompleted;

    String scoreOrDefault(List<int> scores, int i) =>
        (scores.length > i) ? scores[i].toString() : '0';

    final govDeb1 = TextEditingController(
      text: isEditing ? scoreOrDefault(match.teamAScores, 0) : '',
    );
    final govDeb2 = TextEditingController(
      text: isEditing ? scoreOrDefault(match.teamAScores, 1) : '',
    );
    final govDeb3 = TextEditingController(
      text: isEditing ? scoreOrDefault(match.teamAScores, 2) : '',
    );
    final govRebuttal = TextEditingController(
      text: isEditing ? (match.teamARebuttal).toString() : '',
    );

    final oppDeb1 = TextEditingController(
      text: isEditing ? scoreOrDefault(match.teamBScores, 0) : '',
    );
    final oppDeb2 = TextEditingController(
      text: isEditing ? scoreOrDefault(match.teamBScores, 1) : '',
    );
    final oppDeb3 = TextEditingController(
      text: isEditing ? scoreOrDefault(match.teamBScores, 2) : '',
    );
    final oppRebuttal = TextEditingController(
      text: isEditing ? (match.teamBRebuttal).toString() : '',
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Scores' : 'Submit Scores'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Government Team Scores
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Government (${match.teamA.teamName})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
              _buildScoreField(
                  govDeb1,
                  match.teamA.teamMembers.isNotEmpty
                      ? '${match.teamA.teamMembers[0].name} (PM)'
                      : 'Prime Minister'),
              const SizedBox(height: 8),
              _buildScoreField(
                  govDeb2,
                  match.teamA.teamMembers.length > 1
                      ? '${match.teamA.teamMembers[1].name} (DPM)'
                      : 'Deputy Prime Minister'),
              const SizedBox(height: 8),
              _buildScoreField(
                  govDeb3,
                  match.teamA.teamMembers.length > 2
                      ? '${match.teamA.teamMembers[2].name} (MG)'
                      : 'Member of Government'),
              const SizedBox(height: 8),
              _buildScoreField(govRebuttal, 'Rebuttal'),
              const SizedBox(height: 20),

              // Opposition Team Scores
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Opposition (${match.teamB.teamName})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              _buildScoreField(
                  oppDeb1,
                  match.teamB.teamMembers.isNotEmpty
                      ? '${match.teamB.teamMembers[0].name} (LO)'
                      : 'Leader of the Opposition'),
              const SizedBox(height: 8),
              _buildScoreField(
                  oppDeb2,
                  match.teamB.teamMembers.length > 1
                      ? '${match.teamB.teamMembers[1].name} (DLO)'
                      : 'Deputy Leader of the Opposition'),
              const SizedBox(height: 8),
              _buildScoreField(
                  oppDeb3,
                  match.teamB.teamMembers.length > 2
                      ? '${match.teamB.teamMembers[2].name} (MO)'
                      : 'Member of Opposition'),
              const SizedBox(height: 8),
              _buildScoreField(oppRebuttal, 'Rebuttal'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate all fields are filled
              final govScores = [
                govDeb1.text.trim(),
                govDeb2.text.trim(),
                govDeb3.text.trim(),
                govRebuttal.text.trim(),
              ];
              final oppScores = [
                oppDeb1.text.trim(),
                oppDeb2.text.trim(),
                oppDeb3.text.trim(),
                oppRebuttal.text.trim(),
              ];

              if (govScores.any((s) => s.isEmpty) ||
                  oppScores.any((s) => s.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please fill all score fields.')),
                );
                return;
              }

              final parsedGovScores = govScores.map(int.tryParse).toList();
              final parsedOppScores = oppScores.map(int.tryParse).toList();
              if (parsedGovScores.any((s) => s == null) ||
                  parsedOppScores.any((s) => s == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid numeric scores.'),
                  ),
                );
                return;
              }

              final govTotal = _calculateTeamTotal(
                parsedGovScores.take(3).cast<int>().toList(),
                parsedGovScores[3]!,
              );
              final oppTotal = _calculateTeamTotal(
                parsedOppScores.take(3).cast<int>().toList(),
                parsedOppScores[3]!,
              );

              if (govTotal == oppTotal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text("Both teams can't have the same total score."),
                  ),
                );
                return;
              }

              try {
                if (isEditing) {
                  _editMatchScores(
                    match,
                    parsedGovScores.take(3).cast<int>().toList(),
                    parsedOppScores.take(3).cast<int>().toList(),
                    parsedGovScores[3]!,
                    parsedOppScores[3]!,
                  );
                } else {
                  match.submitScores(
                    parsedGovScores.take(3).cast<int>().toList(),
                    parsedOppScores.take(3).cast<int>().toList(),
                    parsedGovScores[3]!,
                    parsedOppScores[3]!,
                    widget.currentTournament,
                  );
                }

                // Save updated matches to the segment and tournamentSegments
                final segment =
                    widget.currentTournament.tournamentSegments != null &&
                            widget.currentTournament.currentSegmentIndex >= 0
                        ? widget.currentTournament.tournamentSegments![
                            widget.currentTournament.currentSegmentIndex]
                        : null;
                if (segment != null) {
                  segment.matchesInThisSegment = [];
                  segment.addMatchesToSegment(matches, segment);

                  final segmentsList =
                      widget.currentTournament.tournamentSegments ?? [];
                  final segIndex = segmentsList.indexWhere(
                    (s) => s.segmentID == segment.segmentID,
                  );
                  if (segIndex != -1) {
                    segmentsList[segIndex] = segment;
                    widget.currentTournament.tournamentSegments = segmentsList;
                  }
                }

                //Update firestore
                await widget.currentTournament.updateTournament();
                // Update widget state
                setState(() {});

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(isEditing
                          ? 'Scores updated successfully.'
                          : 'Scores submitted successfully.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
            child: Text(isEditing ? 'Update' : 'Submit'),
          ),
        ],
      ),
    );
  }

  void _editMatchScores(
    DebateMatch match,
    List<int> newGovDebScores,
    List<int> newOppDebScores,
    int newGovRebuttal,
    int newOppRebuttal,
  ) {
    final newGovTotal = _calculateTeamTotal(newGovDebScores, newGovRebuttal);
    final newOppTotal = _calculateTeamTotal(newOppDebScores, newOppRebuttal);

    if (newGovTotal == newOppTotal) {
      throw Exception("Both teams can't have the same total score.");
    }

    // Get old scores to calculate the difference
    final oldGovDebScores = match.teamAScores;
    final oldOppDebScores = match.teamBScores;
    final oldGovRebuttal = match.teamARebuttal;
    final oldOppRebuttal = match.teamBRebuttal;

    // Calculate old totals (including rebuttal)
    final oldGovTotal = _calculateTeamTotal(oldGovDebScores, oldGovRebuttal);
    final oldOppTotal = _calculateTeamTotal(oldOppDebScores, oldOppRebuttal);
    final oldWinner = _getWinner(oldGovTotal, oldOppTotal);
    final newWinner = _getWinner(newGovTotal, newOppTotal);

    // Update individual debater scores
    for (int i = 0; i < 3; i++) {
      final scoreDifA = newGovDebScores[i] - oldGovDebScores[i];
      final scoreDifB = newOppDebScores[i] - oldOppDebScores[i];

      match.teamA.teamMembers[i].increaseIndividualScore(scoreDifA);
      match.teamB.teamMembers[i].increaseIndividualScore(scoreDifB);

      // Update tournament debaters list
      final debaterAId = match.teamA.teamMembers[i].debaterID;
      final debatersList =
          widget.currentTournament.debatersInTheTournament ?? [];
      final tournamentDebaterA = debatersList.firstWhere(
        (d) => d.debaterID == debaterAId,
        orElse: () => match.teamA.teamMembers[i],
      );
      tournamentDebaterA.increaseIndividualScore(scoreDifA);

      final debaterBId = match.teamB.teamMembers[i].debaterID;
      final tournamentDebaterB = debatersList.firstWhere(
        (d) => d.debaterID == debaterBId,
        orElse: () => match.teamB.teamMembers[i],
      );
      tournamentDebaterB.increaseIndividualScore(scoreDifB);
    }

    // Update team scores by removing old total and adding new total
    final teamScoreDifA = newGovTotal - oldGovTotal;
    final teamScoreDifB = newOppTotal - oldOppTotal;

    match.teamA.increaseTeamScore(teamScoreDifA);
    match.teamB.increaseTeamScore(teamScoreDifB);

    // Update tournament teams list
    final teamsList = widget.currentTournament.teamsInTheTournament ?? [];
    final tournamentTeamA = teamsList.firstWhere(
      (t) => t.teamID == match.teamA.teamID,
      orElse: () => match.teamA,
    );
    final tournamentTeamB = teamsList.firstWhere(
      (t) => t.teamID == match.teamB.teamID,
      orElse: () => match.teamB,
    );

    tournamentTeamA.increaseTeamScore(teamScoreDifA);
    tournamentTeamB.increaseTeamScore(teamScoreDifB);

    if (oldWinner != newWinner) {
      _removePreviousOutcome(match.teamA, oldWinner == 'A');
      _removePreviousOutcome(match.teamB, oldWinner == 'B');
      _applyOutcome(match.teamA, newWinner == 'A');
      _applyOutcome(match.teamB, newWinner == 'B');

      if (!identical(tournamentTeamA, match.teamA)) {
        _removePreviousOutcome(tournamentTeamA, oldWinner == 'A');
        _applyOutcome(tournamentTeamA, newWinner == 'A');
      }
      if (!identical(tournamentTeamB, match.teamB)) {
        _removePreviousOutcome(tournamentTeamB, oldWinner == 'B');
        _applyOutcome(tournamentTeamB, newWinner == 'B');
      }
    }

    // Update match scores and rebuttal scores
    match.teamAScores = newGovDebScores;
    match.teamBScores = newOppDebScores;
    match.teamARebuttal = newGovRebuttal;
    match.teamBRebuttal = newOppRebuttal;
  }

  int _calculateTeamTotal(List<int> speechScores, int rebuttalScore) {
    return speechScores.fold<int>(0, (sum, score) => sum + score) +
        rebuttalScore;
  }

  String _getWinner(int totalA, int totalB) {
    if (totalA > totalB) return 'A';
    if (totalB > totalA) return 'B';
    throw Exception("Both teams can't have the same total score.");
  }

  void _removePreviousOutcome(dynamic team, bool wasWinner) {
    if (wasWinner) {
      if (team.teamWins > 0) {
        team.teamWins -= 1;
      }
    } else {
      if (team.teamLosses > 0) {
        team.teamLosses -= 1;
      }
    }
  }

  void _applyOutcome(dynamic team, bool isWinner) {
    if (isWinner) {
      team.teamWinsADebate();
    } else {
      team.teamLosesADebate();
    }
  }

  Widget _buildScoreField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showLeaderboardOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leaderboard'),
        content: const Text('What would you like to view?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showBestTeams();
            },
            child: const Text('Top Teams'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showBestDebaters();
            },
            child: const Text('Top Debaters'),
          ),
        ],
      ),
    );
  }

  void _showBestTeams() {
    final teams = widget.currentTournament.teamsInTheTournament ?? [];

    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teams found in this tournament.')),
      );
      return;
    }

    // Sort teams by total primarily in wins and then in scores
    final sortedTeams = List.from(teams)
      ..sort((a, b) {
        if (b.teamWins != a.teamWins) {
          return b.teamWins.compareTo(a.teamWins);
        } else if (b.teamScore != a.teamScore) {
          return b.teamScore.compareTo(a.teamScore);
        } else {
          return b.teamLosses.compareTo(a.teamLosses);
        }
      });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Top Teams'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sortedTeams.length,
            itemBuilder: (context, index) {
              final team = sortedTeams[index];
              final isTopThree = index < 3;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isTopThree ? 3 : 1,
                color: isTopThree
                    ? (index == 0
                        ? Colors.amber.shade50
                        : index == 1
                            ? Colors.grey.shade100
                            : Colors.orange.shade50)
                    : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isTopThree
                        ? (index == 0
                            ? Colors.amber
                            : index == 1
                                ? Colors.grey
                                : Colors.orange)
                        : Colors.green,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    team.teamName,
                    style: TextStyle(
                      fontWeight:
                          isTopThree ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'Wins: ${team.teamWins} | Losses: ${team.teamLosses}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${team.teamScore.toStringAsFixed(1)} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBestDebaters() {
    final debaters = widget.currentTournament.debatersInTheTournament ?? [];

    if (debaters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No debaters found in this tournament.')),
      );
      return;
    }

    // Sort debaters by individual score in descending order
    final sortedDebaters = List.from(debaters)
      ..sort((a, b) => b.individualScore.compareTo(a.individualScore));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Top Debaters'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sortedDebaters.length,
            itemBuilder: (context, index) {
              final debater = sortedDebaters[index];
              final isTopThree = index < 3;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: isTopThree ? 3 : 1,
                color: isTopThree
                    ? (index == 0
                        ? Colors.amber.shade50
                        : index == 1
                            ? Colors.grey.shade100
                            : Colors.orange.shade50)
                    : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isTopThree
                        ? (index == 0
                            ? Colors.amber
                            : index == 1
                                ? Colors.grey
                                : Colors.orange)
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    debater.name,
                    style: TextStyle(
                      fontWeight:
                          isTopThree ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    debater.teamName.isEmpty ? 'No Team' : debater.teamName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${debater.individualScore.toStringAsFixed(1)} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
