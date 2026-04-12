import 'package:tabdeb/models/debate_match.dart';
import 'package:tabdeb/models/debate_team.dart';

class TournamentSegment {
  String segmentName;
  int segmentID;
  List<DebateTeam>? teamsInThisSegment; // Will contain DebateTeam objects
  List<DebateMatch>? matchesInThisSegment;
  int numberOfTeamsInSegment;
  int numberOfTeamsAutoQualifiedForNextRound = 0;
  bool isTabRound;

  TournamentSegment({
    required this.segmentName,
    required this.segmentID,
    this.teamsInThisSegment,
    this.matchesInThisSegment,
    this.numberOfTeamsInSegment = 0,
    this.numberOfTeamsAutoQualifiedForNextRound = 0,
    this.isTabRound = true,
  });

  void addMatchesToSegment(
      List<DebateMatch> matches, TournamentSegment segment) {
    matchesInThisSegment ??= [];
    matchesInThisSegment!.addAll(matches);
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'segmentName': segmentName,
      'segmentID': segmentID,
      // Support both model objects and raw maps already coming from Firestore
      'teamsInThisSegment': teamsInThisSegment?.map((team) {
            if (team is Map<String, dynamic>) {
              return team;
            }
            try {
              return team.toJson();
            } catch (_) {
              return team;
            }
          }).toList() ??
          [],
      'matchesInThisSegment': matchesInThisSegment?.map((match) {
            if (match is Map<String, dynamic>) {
              return match;
            }
            try {
              return match.toJson();
            } catch (_) {
              return match;
            }
          }).toList() ??
          [],
      'numberOfTeamsInSegment': numberOfTeamsInSegment,
      'numberOfTeamsAutoQualifiedForNextRound':
          numberOfTeamsAutoQualifiedForNextRound,
      'isTabRound': isTabRound,
    };
  }

  // Create from JSON
  factory TournamentSegment.fromJson(Map<String, dynamic> json) {
    return TournamentSegment(
      segmentName: json['segmentName'] ?? '',
      segmentID: json['segmentID'] ?? 0,
      teamsInThisSegment: (json['teamsInThisSegment'] as List?)
              ?.map((teamJson) => DebateTeam.fromJson(teamJson))
              .toList() ??
          [],
      matchesInThisSegment: (json['matchesInThisSegment'] as List?)
              ?.map((matchJson) => DebateMatch.fromJson(matchJson))
              .toList() ??
          [],
      numberOfTeamsInSegment: json['numberOfTeamsInSegment'] ?? 0,
      numberOfTeamsAutoQualifiedForNextRound:
          json['numberOfTeamsAutoQualifiedForNextRound'] ?? 0,
      isTabRound: json['isTabRound'] ?? true,
    );
  }
}
