import 'debate_team.dart';
import 'tournament.dart';

class DebateMatch {
  DebateTeam teamA, teamB;
  List<int> teamAScores, teamBScores;
  int teamARebuttal, teamBRebuttal;
  bool isCompleted;
  int? venue;

  DebateMatch({
    required this.teamA,
    required this.teamB,
    this.teamAScores = const [0, 0, 0],
    this.teamBScores = const [0, 0, 0],
    this.teamARebuttal = 0,
    this.teamBRebuttal = 0,
    this.isCompleted = false,
    this.venue,
  });

  void submitScores(List<int> scoresA, List<int> scoresB, int rebA, int rebB,
      Tournament tournament) {
    final int totalA = scoresA[0] + scoresA[1] + scoresA[2] + rebA;
    final int totalB = scoresB[0] + scoresB[1] + scoresB[2] + rebB;

    // Reject ties before mutating any score/win-loss state.
    if (totalA == totalB) {
      throw Exception("Both teams can't have the same total score.");
    }

    // Update team members' scores in the match
    for (int i = 0; i < 3; i++) {
      teamA.teamMembers[i].increaseIndividualScore(scoresA[i]);
      teamB.teamMembers[i].increaseIndividualScore(scoresB[i]);
    }

    // Also update the corresponding debaters in the tournament's master list
    tournament.debatersInTheTournament ??= [];
    for (int i = 0; i < 3; i++) {
      // Find and update team A debaters
      final debaterAId = teamA.teamMembers[i].debaterID;
      final tournamentDebaterA = tournament.debatersInTheTournament!.firstWhere(
        (d) => d.debaterID == debaterAId,
        orElse: () => teamA.teamMembers[i],
      );
      tournamentDebaterA.increaseIndividualScore(scoresA[i]);

      // Find and update team B debaters
      final debaterBId = teamB.teamMembers[i].debaterID;
      final tournamentDebaterB = tournament.debatersInTheTournament!.firstWhere(
        (d) => d.debaterID == debaterBId,
        orElse: () => teamB.teamMembers[i],
      );
      tournamentDebaterB.increaseIndividualScore(scoresB[i]);
    }

    // Update teams in the tournament's team list
    tournament.teamsInTheTournament ??= [];
    final tournamentTeamA = tournament.teamsInTheTournament!.firstWhere(
      (t) => t.teamID == teamA.teamID,
      orElse: () => teamA,
    );
    final tournamentTeamB = tournament.teamsInTheTournament!.firstWhere(
      (t) => t.teamID == teamB.teamID,
      orElse: () => teamB,
    );

    // Update both match teams and tournament teams
    tournamentTeamA.increaseTeamScore(totalA);
    tournamentTeamB.increaseTeamScore(totalB);

    if (totalA > totalB) {
      teamA.teamWinsADebate();
      teamB.teamLosesADebate();
      tournamentTeamA.teamWinsADebate();
      tournamentTeamB.teamLosesADebate();
    } else if (totalB > totalA) {
      teamB.teamWinsADebate();
      teamA.teamLosesADebate();
      tournamentTeamB.teamWinsADebate();
      tournamentTeamA.teamLosesADebate();
    }

    // Store the individual scores for this match
    teamAScores = scoresA;
    teamBScores = scoresB;
    teamARebuttal = rebA;
    teamBRebuttal = rebB;

    isCompleted = true;
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'teamA': teamA.toJson(),
      'teamB': teamB.toJson(),
      'teamAScores': teamAScores,
      'teamBScores': teamBScores,
      'teamARebuttal': teamARebuttal,
      'teamBRebuttal': teamBRebuttal,
      'isCompleted': isCompleted,
      'venue': venue,
    };
  }

  // Create from JSON
  factory DebateMatch.fromJson(Map<String, dynamic> json) {
    return DebateMatch(
      teamA: DebateTeam.fromJson(json['teamA'] ?? {}),
      teamB: DebateTeam.fromJson(json['teamB'] ?? {}),
      teamAScores: List<int>.from(json['teamAScores'] ?? [0, 0, 0]),
      teamBScores: List<int>.from(json['teamBScores'] ?? [0, 0, 0]),
      teamARebuttal: json['teamARebuttal'] ?? 0,
      teamBRebuttal: json['teamBRebuttal'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      venue: json['venue'],
    );
  }
}
