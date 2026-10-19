import 'package:flutter_test/flutter_test.dart';
import 'package:tabdeb/models/debate_match.dart';
import 'package:tabdeb/models/debate_team.dart';
import 'package:tabdeb/models/debater.dart';
import 'package:tabdeb/models/tournament.dart';

void main() {
  test('editing scores updates shared tournament objects once', () {
    final teamA = _team(1, 101);
    final teamB = _team(2, 201);
    final tournament = _tournament([
      teamA,
      teamB
    ], [
      ...teamA.teamMembers.cast<Debater>(),
      ...teamB.teamMembers.cast<Debater>(),
    ]);
    final match = DebateMatch(teamA: teamA, teamB: teamB);

    match.submitScores([10, 20, 30], [9, 18, 27], 0, 0, tournament);
    match.updateScores([11, 19, 30], [10, 18, 27], 2, 0, tournament);

    expect(teamA.teamScore, 62);
    expect(teamB.teamScore, 55);
    expect(teamA.teamWins, 1);
    expect(teamB.teamLosses, 1);
    expect((teamA.teamMembers[0] as Debater).individualScore, 11);
    expect((teamB.teamMembers[0] as Debater).individualScore, 10);
  });

  test('editing scores updates deserialized tournament copies and winner state',
      () {
    final matchTeamA = _team(1, 101);
    final matchTeamB = _team(2, 201);
    final tournamentTeamA = _team(1, 101);
    final tournamentTeamB = _team(2, 201);
    final tournament = _tournament([
      tournamentTeamA,
      tournamentTeamB
    ], [
      ...tournamentTeamA.teamMembers.cast<Debater>(),
      ...tournamentTeamB.teamMembers.cast<Debater>(),
    ]);
    final match = DebateMatch(teamA: matchTeamA, teamB: matchTeamB);

    match.submitScores([10, 10, 10], [9, 9, 9], 1, 0, tournament);
    match.updateScores([10, 10, 10], [20, 20, 20], 1, 0, tournament);

    expect(matchTeamA.teamScore, 31);
    expect(matchTeamB.teamScore, 60);
    expect(tournamentTeamA.teamScore, 31);
    expect(tournamentTeamB.teamScore, 60);
    expect(matchTeamA.teamWins, 0);
    expect(matchTeamA.teamLosses, 1);
    expect(tournamentTeamA.teamWins, 0);
    expect(tournamentTeamA.teamLosses, 1);
    expect(tournamentTeamB.teamWins, 1);
  });
}

Tournament _tournament(List<DebateTeam> teams, List<Debater> debaters) {
  return Tournament(
    tournamentName: 'Test',
    tournamentID: 'test',
    tournamentClubName: 'Test Club',
    tournamentStartingDate: DateTime(2026),
    tournamentEndingDate: DateTime(2026, 1, 2),
    teamsInTheTournament: teams,
    debatersInTheTournament: debaters,
  );
}

DebateTeam _team(int teamId, int debaterStartId) {
  return DebateTeam(
    teamID: teamId,
    teamName: 'Team $teamId',
    teamMembers: List.generate(
      3,
      (index) => Debater(
        debaterID: debaterStartId + index,
        name: 'Debater ${debaterStartId + index}',
      ),
    ),
  );
}
