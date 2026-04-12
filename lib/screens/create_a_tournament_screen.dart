import 'package:tabdeb/models/app.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:uuid/uuid.dart';
import '../models/tournament.dart';
import 'dash_screen.dart';
import 'package:tabdeb/models/user.dart';

class CreateATournamentScreen extends StatefulWidget {
  final User? creatorUser;
  const CreateATournamentScreen({this.creatorUser, Key? key}) : super(key: key);

  @override
  State<CreateATournamentScreen> createState() =>
      _CreateATournamentScreenState();
}

class _CreateATournamentScreenState extends State<CreateATournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tournamentNameController;
  late TextEditingController _clubNameController;
  late TextEditingController _locationController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _descriptionController;
  late TextEditingController _prizePoolController;
  late TextEditingController _maxTeamsController;

  String _selectedFormat = 'Asian Parliamentary';
  bool _agreeToTerms = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tournamentNameController = TextEditingController();
    _clubNameController = TextEditingController();
    _locationController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _descriptionController = TextEditingController();
    _prizePoolController = TextEditingController();
    _maxTeamsController = TextEditingController();
  }

  @override
  void dispose() {
    _tournamentNameController.dispose();
    _clubNameController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _descriptionController.dispose();
    _prizePoolController.dispose();
    _maxTeamsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        controller.text = '${picked.month}/${picked.day}/${picked.year}';
      });
    }
  }

  Future<void> _createTournament() async {
    if (!_formKey.currentState!.validate() || !_agreeToTerms) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please agree to terms and conditions'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Get username from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (userDoc.docs.isEmpty) {
        throw Exception('User data not found');
      }

      final username = userDoc.docs.first.id;

      // Parse dates
      final startDate = _parseDateString(_startDateController.text);
      final endDate = _parseDateString(_endDateController.text);

      if (startDate == null || endDate == null) {
        throw Exception('Invalid dates');
      }

      if (endDate.isBefore(startDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date must be after start date'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Create tournament ID
      const uuid = Uuid();
      final tournamentID = uuid.v4();

      // Create tournament format enum
      final formatMap = {
        'Asian Parliamentary': TournamentFormat.asianParliamentary,
        'British Parliamentary': TournamentFormat.britishParliamentary,
        'Lincoln-Douglas': TournamentFormat.lincolnDouglas,
        'Policy Debate': TournamentFormat.policyDebate,
        'Public Forum': TournamentFormat.publicForum,
        'Student Congress': TournamentFormat.studentCongress,
      };

      final prizePoolValue = _prizePoolController.text.trim().isEmpty
          ? null
          : double.tryParse(_prizePoolController.text.trim());
      final maxTeamsValue = _maxTeamsController.text.trim().isEmpty
          ? null
          : int.tryParse(_maxTeamsController.text.trim());

      // Create tournament object
      final tournament = Tournament(
        tournamentName: _tournamentNameController.text.trim(),
        tournamentID: tournamentID,
        tournamentClubName: _clubNameController.text.trim(),
        tournamentLocation: _locationController.text.trim(),
        tournamentDescription: _descriptionController.text.trim(),
        tournamentStartingDate: startDate,
        tournamentEndingDate: endDate,
        tournamentFormat:
            formatMap[_selectedFormat] ?? TournamentFormat.asianParliamentary,
        maxTeams: maxTeamsValue,
        prizePool: prizePoolValue,
        createdByUserID: username,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await tournament.saveTournament();
      await App.incrementTournamentsCreated();
      // Update the user's tournamentsRunByUser List with the new tournament
      widget.creatorUser?.updateTournamentsRunByUser(tournament);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tournament created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating tournament: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  DateTime? _parseDateString(String dateString) {
    try {
      final parts = dateString.split('/');
      if (parts.length != 3) return null;
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Create Tournament'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_circle,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'New Tournament',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fill in the details to create a new tournament',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Basic Information Section
                const Text(
                  'Basic Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Tournament Name
                TextFormField(
                  controller: _tournamentNameController,
                  decoration: InputDecoration(
                    labelText: 'Tournament Name',
                    hintText: 'e.g., Inter-University Debate 2025',
                    prefixIcon: const Icon(Icons.sports),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Tournament name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Club Name
                TextFormField(
                  controller: _clubNameController,
                  decoration: InputDecoration(
                    labelText: 'Club / Organization Name',
                    hintText: 'e.g., National Debate Club',
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Club name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Location
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g., Grand Hall, University',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Location is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Date & Format Section
                const Text(
                  'Date & Format',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Start Date
                TextFormField(
                  controller: _startDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    hintText: 'MM/DD/YYYY',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  onTap: () => _selectDate(_startDateController),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Start date is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // End Date
                TextFormField(
                  controller: _endDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    hintText: 'MM/DD/YYYY',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  onTap: () => _selectDate(_endDateController),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'End date is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Tournament Format
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tournament Format',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedFormat,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: <String>[
                          'Asian Parliamentary',
                          'British Parliamentary',
                          'Lincoln-Douglas',
                          'Policy Debate',
                          'Public Forum',
                          'Student Congress',
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFormat = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Additional Details Section
                const Text(
                  'Additional Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Max Teams
                TextFormField(
                  controller: _maxTeamsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Maximum Number of Teams (Optional)',
                    hintText: 'e.g., 24',
                    prefixIcon: const Icon(Icons.groups),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Prize Pool
                TextFormField(
                  controller: _prizePoolController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Prize Pool (Optional)',
                    hintText: 'e.g., 10000',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Tournament Description (Optional)',
                    hintText: 'Enter tournament description...',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 24),

                // Terms & Conditions
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (bool? value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                          activeColor: Colors.blue,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'I agree to the ',
                                    style: TextStyle(color: Colors.black87),
                                  ),
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DashScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel),
                            SizedBox(width: 8),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createTournament,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoading)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            else
                              const Icon(Icons.check_circle),
                            const SizedBox(width: 8),
                            Text(
                              _isLoading ? 'Creating...' : 'Create',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
