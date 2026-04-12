import 'package:tabdeb/models/tournament.dart';

import '../models/debate_match.dart';
import '../models/debate_team.dart';
import '../models/tournament_segment.dart';

class MatchGenerator {
  (List<DebateMatch>, List<DebateTeam>) generateMatchups(
    Tournament currentTournament,
    TournamentSegment segment,
    List<DebateTeam> teams,
  ) {
    List<DebateMatch> matches = [];
    List<DebateTeam> disqualifiedTeams = [];

    int auto = segment.numberOfTeamsAutoQualifiedForNextRound;
    int start = 0, end = segment.numberOfTeamsInSegment - 1;
    int v = 1; //Venue number

    // Manage the auto-qualified teams
    start = auto;
    end += auto;
    //Add first 'auto' teams to the tournamnt's autoQualifiedTeams list
    for (int i = 0; i < auto; i++) {
      currentTournament.addAutoQualifiedTeam(teams[i]);
    }
    for (int i = end + 1; i < teams.length; i++) {
      disqualifiedTeams.add(teams[i]);
    }

    //Current round index
    int roundIndex = currentTournament.tournamentSegments!.indexOf(segment);

    if (!segment.isTabRound) {
      // Sort teams based on the number of wins first, then total teamScore
      teams.sort((a, b) {
        if (b.teamWins != a.teamWins) {
          return b.teamWins.compareTo(a.teamWins);
        } else {
          return b.teamScore.compareTo(a.teamScore);
        }
      });
    } else if (roundIndex != 0) {
      List<DebateTeam> teamsWon = [];
      List<DebateTeam> teamsLost = [];
      // Teams current status is win, add to teamsWon else add to teamsLost
      for (var team in teams) {
        if (team.teamStatus == 'win') {
          teamsWon.add(team);
        } else {
          teamsLost.add(team);
        }
      }
      teamsWon.sort((a, b) {
        if (b.teamWins != a.teamWins) {
          return b.teamWins.compareTo(a.teamWins);
        } else {
          return b.teamScore.compareTo(a.teamScore);
        }
      });
      teamsLost.sort((a, b) {
        if (b.teamWins != a.teamWins) {
          return b.teamWins.compareTo(a.teamWins);
        } else {
          return b.teamScore.compareTo(a.teamScore);
        }
      });

      // If teamsWon has odd number of teams, move the first element of the teamsLost to teamsWon's end
      if (teamsWon.length % 2 != 0 && teamsLost.isNotEmpty) {
        DebateTeam movedTeam = teamsLost.removeAt(0);
        teamsWon.add(movedTeam);
      }

      List<DebateMatch> winMatches = [];
      List<DebateMatch> loseMatches = [];
      // Pair teams in teamsWon
      int winStart = 0, winEnd = teamsWon.length - 1;
      while (winStart < winEnd) {
        DebateTeam teamA = teamsWon[winStart];
        DebateTeam teamB = teamsWon[winEnd];

        DebateMatch match = DebateMatch(
          teamA: teamA,
          teamB: teamB,
        );

        winMatches.add(match);
        winStart++;
        winEnd--;
      }
      // Pair teams in teamsLost
      int loseStart = 0, loseEnd = teamsLost.length - 1;
      while (loseStart < loseEnd) {
        DebateTeam teamA = teamsLost[loseStart];
        DebateTeam teamB = teamsLost[loseEnd];

        DebateMatch match = DebateMatch(
          teamA: teamA,
          teamB: teamB,
        );

        loseMatches.add(match);
        loseStart++;
        loseEnd--;
      }
      matches = [...winMatches, ...loseMatches]; // Match generation completed
    }

    if (roundIndex == 0 || !segment.isTabRound) {
      while (start < end) {
        DebateTeam teamA = teams[start];
        DebateTeam teamB = teams[end];

        DebateMatch match = DebateMatch(
          teamA: teamA,
          teamB: teamB,
        );

        matches.add(match);
        start++;
        end--;
      }
    } // Matchup generation completed

    // Check match by match. If any team's teamPlayedGovernment is equal to number of rounds or 0, then swap sides.
    roundIndex++;
    for (var match in matches) {
      if (match.teamA.teamPlayedGovernment == roundIndex ||
          match.teamA.teamPlayedGovernment == 0) {
        // Swap sides
        DebateTeam temp = match.teamA;
        match.teamA = match.teamB;
        match.teamB = temp;
      }
      match.venue = v;
      v++;
    }

    (List<DebateMatch>, List<DebateTeam>) result = (matches, disqualifiedTeams);

    return result;
  }
}
