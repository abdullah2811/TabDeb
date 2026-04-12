import 'package:cloud_firestore/cloud_firestore.dart';
import 'debate_team.dart';
import 'debate_match.dart';
import 'debater.dart';
import 'tournament_segment.dart';
import 'package:tabdeb/models/user.dart';

enum TournamentFormat {
  asianParliamentary,
  britishParliamentary,
  lincolnDouglas,
  policyDebate,
  publicForum,
  studentCongress,
}

class Tournament {
  String tournamentName;
  String tournamentID;
  String tournamentClubName;
  String? tournamentLocation;
  String? tournamentDescription;
  DateTime tournamentStartingDate;
  DateTime tournamentEndingDate;
  int numberOfTeamsInTournament = 0;
  int? maxTeams;
  double? prizePool;
  TournamentFormat tournamentFormat;
  int currentSegmentIndex = -1;
  String? createdByUserID;
  DateTime? createdAt;
  List<Debater>? debatersInTheTournament;
  List<DebateTeam>? teamsInTheTournament;
  List<DebateTeam>? autoQualifiedTeams;
  List<TournamentSegment>? tournamentSegments;
  bool teamAdditionClosed = false;
  bool roadmapLocked = false;
  bool isClosed = false;
  List<User> usersRunningTheTournament = [];

  Tournament({
    required this.tournamentName,
    required this.tournamentID,
    required this.tournamentClubName,
    required this.tournamentStartingDate,
    required this.tournamentEndingDate,
    this.tournamentLocation,
    this.tournamentDescription,
    this.numberOfTeamsInTournament = 0,
    this.maxTeams,
    this.prizePool,
    this.tournamentFormat = TournamentFormat.asianParliamentary,
    this.currentSegmentIndex = -1,
    this.createdByUserID,
    this.createdAt,
    this.debatersInTheTournament,
    this.teamsInTheTournament,
    this.autoQualifiedTeams,
    this.tournamentSegments,
    this.teamAdditionClosed = false,
    this.isClosed = false,
    this.roadmapLocked = false,
    this.usersRunningTheTournament = const [],
  });

  CollectionReference<Map<String, dynamic>> get _tournamentsCollection =>
      FirebaseFirestore.instance.collection('tournaments');

  // Save tournament to Firestore
  Future<void> saveTournament() async {
    try {
      await _tournamentsCollection.doc(tournamentID).set(toJson());
    } catch (e) {
      throw Exception('Error saving tournament: $e');
    }
  }

  // Update tournament in Firestore
  Future<void> updateTournament() async {
    try {
      await _tournamentsCollection.doc(tournamentID).update(toJson());
    } catch (e) {
      throw Exception('Error updating tournament: $e');
    }
  }

  // Get tournament from Firestore
  static Future<Tournament?> getTournament(String tournamentID) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentID)
          .get();
      if (doc.exists) {
        return Tournament.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Error getting tournament: $e');
    }
  }

  void addDebater(Debater debater) {
    debatersInTheTournament ??= [];
    debatersInTheTournament!.add(debater);
    updateTournament();
  }

  void removeDebater(Debater debater) {
    debatersInTheTournament ??= [];
    debatersInTheTournament!
        .removeWhere((d) => d.debaterID == debater.debaterID);
    updateTournament();
  }

  void addTeam(Tournament tournament, DebateTeam team) {
    final newTeam = team;
    tournament.teamsInTheTournament ??= [];
    tournament.teamsInTheTournament!.add(newTeam);
    tournament.numberOfTeamsInTournament++;
    tournament.updateTournament();
    //Add the debaters to the debaters list
    for (var debater in team.teamMembers) {
      tournament.addDebater(debater);
    }
  }

  void removeTeam(Tournament tournament, DebateTeam team) {
    tournament.teamsInTheTournament ??= [];
    tournament.teamsInTheTournament!.removeWhere((t) =>
        t.teamName == team.teamName &&
        t.teamMembers.length == 3 &&
        t.teamMembers[0].debaterID == team.teamMembers[0].debaterID &&
        t.teamMembers[1].debaterID == team.teamMembers[1].debaterID &&
        t.teamMembers[2].debaterID == team.teamMembers[2].debaterID);
    tournament.numberOfTeamsInTournament--;
    //Remove the debaters from the debaters list
    tournament.debatersInTheTournament ??= [];
    tournament.debatersInTheTournament!.removeWhere((debater) =>
        debater.debaterID == team.teamMembers[0].debaterID ||
        debater.debaterID == team.teamMembers[1].debaterID ||
        debater.debaterID == team.teamMembers[2].debaterID);
    tournament.updateTournament();
  }

  void addAutoQualifiedTeam(DebateTeam team) {
    autoQualifiedTeams ??= [];
    autoQualifiedTeams!.add(team);
    updateTournament();
  }

  void addUserRunningTheTournament(User user) {
    usersRunningTheTournament.add(user);
    updateTournament();
  }

  // Add a co-owner to the tournament
  Future<void> addCoOwner(User user) async {
    try {
      // Check if user is already a co-owner
      final isAlreadyOwner =
          usersRunningTheTournament.any((u) => u.userID == user.userID);

      if (isAlreadyOwner) {
        throw Exception('User is already a co-owner of this tournament');
      }

      // Add to tournament's users list
      usersRunningTheTournament.add(user);
      await updateTournament();

      // Add tournament to user's tournaments list
      user.tournamentsRunByUser.add(this);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.userID)
          .update({
        'tournamentsRunByUser':
            user.tournamentsRunByUser.map((t) => t.tournamentID).toList(),
      });
    } catch (e) {
      throw Exception('Error adding co-owner: $e');
    }
  }

  // Remove a co-owner from the tournament (only creator can do this)
  Future<void> removeCoOwner(User user, String requestingUserID) async {
    try {
      // Only the creator can remove co-owners
      if (createdByUserID != requestingUserID) {
        throw Exception('Only the tournament creator can remove co-owners');
      }

      // Cannot remove the creator
      if (user.userID == createdByUserID) {
        throw Exception('Cannot remove the tournament creator');
      }

      // Check if user is actually a co-owner
      final isCoOwner =
          usersRunningTheTournament.any((u) => u.userID == user.userID);

      if (!isCoOwner) {
        throw Exception('User is not a co-owner of this tournament');
      }

      // Remove from tournament's users list
      usersRunningTheTournament.removeWhere((u) => u.userID == user.userID);
      await updateTournament();

      // Remove tournament from user's tournaments list
      user.tournamentsRunByUser
          .removeWhere((t) => t.tournamentID == tournamentID);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.userID)
          .update({
        'tournamentsRunByUser':
            user.tournamentsRunByUser.map((t) => t.tournamentID).toList(),
      });
    } catch (e) {
      throw Exception('Error removing co-owner: $e');
    }
  }

  void closeTeamAddition() {
    teamAdditionClosed = true;
    updateTournament();
  }

  void closeTournament() {
    isClosed = true;
    updateTournament();
  }

  // void addSegment(TournamentSegment segment) {
  //   tournamentSegments ??= [];
  //   tournamentSegments!.add(segment);
  //   updateTournament();
  // }

  // void removeSegment(TournamentSegment segment) {
  //   tournamentSegments ??= [];
  //   tournamentSegments!.removeWhere((s) => s.segmentID == segment.segmentID);
  //   updateTournament();
  // }

  (List<DebateMatch>, List<DebateTeam>) generateMatchups(
    Tournament currentTournament,
    TournamentSegment segment,
    List<DebateTeam> teams,
  ) {
    List<DebateMatch> matches = [];
    List<DebateTeam> disqualifiedTeams = [];

    int auto = segment.numberOfTeamsAutoQualifiedForNextRound;
    // Clamp teamsCount to available teams
    int teamsCount = segment.numberOfTeamsInSegment > 0
        ? (segment.numberOfTeamsInSegment > teams.length
            ? teams.length
            : segment.numberOfTeamsInSegment)
        : teams.length;
    int start = 0, end = teamsCount - 1;

    // Manage the auto-qualified teams
    // Clamp auto to available teamsCount
    if (auto > teamsCount) auto = teamsCount;
    start = auto;
    // Ensure end doesn't exceed actual teams available
    if (end >= teams.length) {
      end = teams.length - 1;
    }
    // Add first 'auto' teams to the tournament's autoQualifiedTeams list
    for (int i = 0; i < auto; i++) {
      addAutoQualifiedTeam(teams[i]);
    }
    for (int i = end + 1; i < teams.length; i++) {
      disqualifiedTeams.add(teams[i]);
    }

    //Current round index
    int roundIndex = tournamentSegments!.indexOf(segment);

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
    }
    for (var match in matches) {
      if (match.teamB.teamPlayedGovernment == roundIndex ||
          match.teamB.teamPlayedGovernment == 0) {
        // Swap sides
        DebateTeam temp = match.teamA;
        match.teamA = match.teamB;
        match.teamB = temp;
      }
    }

    // Assign distinct venue numbers (1 to number of matches)
    int venueNumber = 1;
    for (var match in matches) {
      match.venue = venueNumber;
      venueNumber++;
    }

    (List<DebateMatch>, List<DebateTeam>) result = (matches, disqualifiedTeams);

    return result;
  }

  void proceedToNextSegment() {
    if (tournamentSegments != null &&
        currentSegmentIndex < (tournamentSegments!.length - 1)) {
      currentSegmentIndex++;
      TournamentSegment? currentSegment =
          tournamentSegments?[currentSegmentIndex];

      tournamentSegments?[currentSegmentIndex].matchesInThisSegment =
          generateMatchups(this, currentSegment!, teamsInTheTournament ?? [])
              .$1;

      // //Print message that the matchups have been generated and print the matchups also in the console
      // print('Generated matchups for segment: ${currentSegment!.segmentName}');
      // for (var match in teamsInTheTournament!) {
      //   print('Team: ${match.teamName}');
      // }
      // print('Matchups:');
      // for (var match in currentMatches!) {
      //   print(
      //       'Venue ${match.venue}: ${match.teamA.teamName} vs ${match.teamB.teamName}');
      // }

      updateTournament();
    }
  }

  Future<void> deleteTournament() async {
    try {
      await _tournamentsCollection.doc(tournamentID).delete();
    } catch (e) {
      throw Exception('Error deleting tournament: $e');
    }
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'tournamentName': tournamentName,
      'tournamentID': tournamentID,
      'tournamentClubName': tournamentClubName,
      'tournamentLocation': tournamentLocation,
      'tournamentDescription': tournamentDescription,
      'tournamentStartingDate': tournamentStartingDate.toIso8601String(),
      'tournamentEndingDate': tournamentEndingDate.toIso8601String(),
      'currentSegmentIndex': currentSegmentIndex,
      'numberOfTeamsInTournament': numberOfTeamsInTournament,
      'maxTeams': maxTeams,
      'prizePool': prizePool,
      'tournamentFormat': tournamentFormat.index,
      'createdByUserID': createdByUserID,
      'createdAt': createdAt?.toIso8601String(),
      'debatersInTheTournament':
          debatersInTheTournament?.map((debater) => debater.toJson()).toList(),
      'teamsInTheTournament':
          teamsInTheTournament?.map((team) => team.toJson()).toList(),
      'autoQualifiedTeams':
          autoQualifiedTeams?.map((team) => team.toJson()).toList(),
      'tournamentSegments':
          tournamentSegments?.map((segment) => segment.toJson()).toList(),
      'teamAdditionClosed': teamAdditionClosed,
      'isClosed': isClosed,
      'roadmapLocked': roadmapLocked,
      'usersRunningTheTournament':
          usersRunningTheTournament.map((user) => user.userID).toList(),
    };
  }

  // Create from JSON
  factory Tournament.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        return DateTime.tryParse(dateValue);
      }
      return null;
    }

    return Tournament(
      tournamentClubName: json['tournamentClubName'] ?? '',
      tournamentName: json['tournamentName'] ?? '',
      tournamentID: json['tournamentID'] ?? '',
      tournamentLocation: json['tournamentLocation'],
      tournamentDescription: json['tournamentDescription'],
      tournamentStartingDate:
          parseDate(json['tournamentStartingDate']) ?? DateTime.now(),
      tournamentEndingDate:
          parseDate(json['tournamentEndingDate']) ?? DateTime.now(),
      currentSegmentIndex: json['currentSegmentIndex'] ?? -1,
      numberOfTeamsInTournament: json['numberOfTeamsInTournament'] ?? 0,
      maxTeams: json['maxTeams'],
      prizePool: json['prizePool']?.toDouble(),
      tournamentFormat: TournamentFormat.values[json['tournamentFormat'] ?? 1],
      createdByUserID: json['createdByUserID'],
      createdAt: parseDate(json['createdAt']),
      debatersInTheTournament: (json['debatersInTheTournament'] as List?)
          ?.map((debaterJson) => Debater.fromJson(debaterJson))
          .toList(),
      teamsInTheTournament: (json['teamsInTheTournament'] as List?)
          ?.map((teamJson) => DebateTeam.fromJson(teamJson))
          .toList(),
      autoQualifiedTeams: (json['autoQualifiedTeams'] as List?)
          ?.map((teamJson) => DebateTeam.fromJson(teamJson))
          .toList(),
      tournamentSegments: (json['tournamentSegments'] as List?)
          ?.map((segmentJson) => TournamentSegment.fromJson(segmentJson))
          .toList(),
      teamAdditionClosed: json['teamAdditionClosed'] ?? false,
      isClosed: json['isClosed'] ?? false,
      roadmapLocked: json['roadmapLocked'] ?? false,
      usersRunningTheTournament: (json['usersRunningTheTournament'] as List?)
              ?.map((userID) =>
                  User(userID: userID, name: '', email: '', password: ''))
              .toList() ??
          [],
    );
  }
}
