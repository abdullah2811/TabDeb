import 'debate_team.dart';
import 'debater.dart';
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

    _updateDebaterScores(teamA, scoresA, null);
    _updateDebaterScores(teamB, scoresB, null);

    final tournamentDebaters = tournament.debatersInTheTournament ??= [];
    for (int i = 0; i < 3; i++) {
      final tournamentDebaterA = _findDebater(
        tournamentDebaters,
        teamA.teamMembers[i].debaterID,
        teamA.teamMembers[i],
      );
      final tournamentDebaterB = _findDebater(
        tournamentDebaters,
        teamB.teamMembers[i].debaterID,
        teamB.teamMembers[i],
      );
      if (!identical(tournamentDebaterA, teamA.teamMembers[i])) {
        tournamentDebaterA.increaseIndividualScore(scoresA[i]);
      }
      if (!identical(tournamentDebaterB, teamB.teamMembers[i])) {
        tournamentDebaterB.increaseIndividualScore(scoresB[i]);
      }
    }

    _applyTeamScores(tournament, totalA, totalB);
    _applyOutcome(tournament, totalA > totalB);

    teamAScores = List<int>.from(scoresA);
    teamBScores = List<int>.from(scoresB);
    teamARebuttal = rebA;
    teamBRebuttal = rebB;
    isCompleted = true;
  }

  void updateScores(List<int> scoresA, List<int> scoresB, int rebA, int rebB,
      Tournament tournament) {
    final int oldTotalA = _total(teamAScores, teamARebuttal);
    final int oldTotalB = _total(teamBScores, teamBRebuttal);
    final int newTotalA = _total(scoresA, rebA);
    final int newTotalB = _total(scoresB, rebB);

    if (newTotalA == newTotalB) {
      throw Exception("Both teams can't have the same total score.");
    }

    _updateDebaterScores(teamA, scoresA, teamAScores);
    _updateDebaterScores(teamB, scoresB, teamBScores);

    final tournamentDebaters = tournament.debatersInTheTournament ??= [];
    for (int i = 0; i < 3; i++) {
      final tournamentDebaterA = _findDebater(
        tournamentDebaters,
        teamA.teamMembers[i].debaterID,
        teamA.teamMembers[i],
      );
      final tournamentDebaterB = _findDebater(
        tournamentDebaters,
        teamB.teamMembers[i].debaterID,
        teamB.teamMembers[i],
      );
      final differenceA = scoresA[i] - teamAScores[i];
      final differenceB = scoresB[i] - teamBScores[i];
      if (!identical(tournamentDebaterA, teamA.teamMembers[i])) {
        tournamentDebaterA.increaseIndividualScore(differenceA);
      }
      if (!identical(tournamentDebaterB, teamB.teamMembers[i])) {
        tournamentDebaterB.increaseIndividualScore(differenceB);
      }
    }

    _applyTeamScores(
      tournament,
      newTotalA - oldTotalA,
      newTotalB - oldTotalB,
    );
    _removeOutcome(tournament, oldTotalA > oldTotalB);
    _applyOutcome(tournament, newTotalA > newTotalB);

    teamAScores = List<int>.from(scoresA);
    teamBScores = List<int>.from(scoresB);
    teamARebuttal = rebA;
    teamBRebuttal = rebB;
    isCompleted = true;
  }

  int _total(List<int> scores, int rebuttal) =>
      scores.fold<int>(0, (sum, score) => sum + score) + rebuttal;

  void _updateDebaterScores(
      DebateTeam team, List<int> newScores, List<int>? oldScores) {
    for (int i = 0; i < 3; i++) {
      final difference = newScores[i] - (oldScores == null ? 0 : oldScores[i]);
      team.teamMembers[i].increaseIndividualScore(difference);
    }
  }

  Debater _findDebater(List<Debater> debaters, int id, Debater fallback) {
    return debaters.firstWhere((debater) => debater.debaterID == id,
        orElse: () => fallback);
  }

  void _applyTeamScores(Tournament tournament, int scoreA, int scoreB) {
    teamA.increaseTeamScore(scoreA);
    teamB.increaseTeamScore(scoreB);
    final teams = tournament.teamsInTheTournament ??= [];
    final tournamentTeamA =
        teams.firstWhere((t) => t.teamID == teamA.teamID, orElse: () => teamA);
    final tournamentTeamB =
        teams.firstWhere((t) => t.teamID == teamB.teamID, orElse: () => teamB);
    if (!identical(tournamentTeamA, teamA)) {
      tournamentTeamA.increaseTeamScore(scoreA);
    }
    if (!identical(tournamentTeamB, teamB)) {
      tournamentTeamB.increaseTeamScore(scoreB);
    }
  }

  void _applyOutcome(Tournament tournament, bool aWon) {
    final teams = tournament.teamsInTheTournament ??= [];
    final tournamentTeamA =
        teams.firstWhere((t) => t.teamID == teamA.teamID, orElse: () => teamA);
    final tournamentTeamB =
        teams.firstWhere((t) => t.teamID == teamB.teamID, orElse: () => teamB);
    if (aWon) {
      teamA.teamWinsADebate();
      teamB.teamLosesADebate();
      if (!identical(tournamentTeamA, teamA)) tournamentTeamA.teamWinsADebate();
      if (!identical(tournamentTeamB, teamB))
        tournamentTeamB.teamLosesADebate();
    } else {
      teamB.teamWinsADebate();
      teamA.teamLosesADebate();
      if (!identical(tournamentTeamB, teamB)) tournamentTeamB.teamWinsADebate();
      if (!identical(tournamentTeamA, teamA))
        tournamentTeamA.teamLosesADebate();
    }
  }

  void _removeOutcome(Tournament tournament, bool aWon) {
    if (aWon) {
      if (teamA.teamWins > 0) teamA.teamWins--;
      if (teamB.teamLosses > 0) teamB.teamLosses--;
    } else {
      if (teamB.teamWins > 0) teamB.teamWins--;
      if (teamA.teamLosses > 0) teamA.teamLosses--;
    }
    final teams = tournament.teamsInTheTournament ??= [];
    final tournamentTeamA =
        teams.firstWhere((t) => t.teamID == teamA.teamID, orElse: () => teamA);
    final tournamentTeamB =
        teams.firstWhere((t) => t.teamID == teamB.teamID, orElse: () => teamB);
    if (aWon) {
      if (!identical(tournamentTeamA, teamA) && tournamentTeamA.teamWins > 0) {
        tournamentTeamA.teamWins--;
      }
      if (!identical(tournamentTeamB, teamB) &&
          tournamentTeamB.teamLosses > 0) {
        tournamentTeamB.teamLosses--;
      }
    } else {
      if (!identical(tournamentTeamB, teamB) && tournamentTeamB.teamWins > 0) {
        tournamentTeamB.teamWins--;
      }
      if (!identical(tournamentTeamA, teamA) &&
          tournamentTeamA.teamLosses > 0) {
        tournamentTeamA.teamLosses--;
      }
    }
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
