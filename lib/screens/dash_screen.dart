import 'package:tabdeb/screens/create_a_tournament_screen.dart';
import 'package:tabdeb/screens/own_tournaments_screen.dart';
import 'package:tabdeb/screens/search_debaters_screen.dart';
import 'package:tabdeb/screens/search_tournaments_screen.dart';
import 'package:tabdeb/screens/summarizer.dart';
import 'package:tabdeb/screens/timer_screen.dart';
import 'package:tabdeb/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app.dart';
import '../models/user.dart' as app_user;
import 'profile_screen.dart';

class DashScreen extends StatefulWidget {
  final app_user.User? currentUser;
  final bool isRegistered;

  const DashScreen({
    Key? key,
    this.currentUser,
    this.isRegistered = true,
  }) : super(key: key);

  @override
  State<DashScreen> createState() => _DashScreenState();
}

class _DashScreenState extends State<DashScreen> {
  App? _appStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAppStats();
  }

  Future<void> _fetchAppStats() async {
    try {
      final stats = await App.fetchAppStats();
      setState(() {
        _appStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: !widget.isRegistered
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                },
              )
            : null,
        actions: [
          if (widget.isRegistered)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    _showNotificationsPanel(context);
                  },
                ),
                if (_appStats != null && _appStats!.notifications.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${_appStats!.notifications.length > 9 ? '9+' : _appStats!.notifications.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          if (widget.isRegistered)
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                if (widget.currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProfileScreen(currentUser: widget.currentUser!),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Section
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade700,
                    Colors.blue.shade500,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isRegistered ? 'Welcome Back!' : 'Welcome!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isRegistered
                          ? 'Manage your debate tournaments'
                          : 'Browse tournaments and debaters',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // App Stats Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'App Statistics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red[400], size: 48),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load stats',
                              style: TextStyle(color: Colors.red[400]),
                            ),
                            TextButton(
                              onPressed: _fetchAppStats,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.emoji_events,
                            value: '${_appStats?.tournamentsCreated ?? 0}',
                            subtitle: 'Tournaments',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.groups,
                            value: '${_appStats?.teamsHandled ?? 0}',
                            subtitle: 'Teams',
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.person,
                            value: '${_appStats?.debatersHandled ?? 0}',
                            subtitle: 'Debaters',
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.people,
                            value: '${_appStats?.usersRegistered ?? 0}',
                            subtitle: 'Users',
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Main Options Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isRegistered ? 'Quick Actions' : 'Browse',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Create Tournament Card (Only for registered users)
                  if (widget.isRegistered)
                    _buildActionCard(
                      context: context,
                      icon: Icons.add_circle,
                      title: 'Create a Tournament',
                      subtitle: 'Start a new debate tournament',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const CreateATournamentScreen(),
                          ),
                        );
                      },
                    ),

                  if (widget.isRegistered) const SizedBox(height: 12),

                  // // Adjudicator Area Card (Only for registered users)
                  // if (widget.isRegistered)
                  //   _buildActionCard(
                  //     context: context,
                  //     icon: Icons.gavel,
                  //     title: 'Adjudicator Area',
                  //     subtitle: 'Manage adjudicators and assignments',
                  //     color: Colors.red,
                  //     onTap: () {
                  //       Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (context) => const AdjudicatorScreen(),
                  //         ),
                  //       );
                  //     },
                  //   ),

                  // if (widget.isRegistered) const SizedBox(height: 12),

                  // Manage Tournaments Card (Only for registered users)
                  if (widget.isRegistered)
                    _buildActionCard(
                      context: context,
                      icon: Icons.edit,
                      title: 'Manage Your Tournaments',
                      subtitle: 'View and edit your tournaments',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OwnTournamentsScreen(
                                currentUser: widget.currentUser!),
                          ),
                        );
                      },
                    ),

                  if (widget.isRegistered) const SizedBox(height: 12),

                  // Time Keeping Button (Only for registered users)
                  if (widget.isRegistered)
                    _buildActionCard(
                      context: context,
                      icon: Icons.timer,
                      title: 'Time Keeping',
                      subtitle: 'Smart Stopwatch for Adjudcators',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TimerScreen(),
                          ),
                        );
                      },
                    ),

                  if (widget.isRegistered) const SizedBox(height: 12),

                  // AI Summarization Button (Only for registered users)
                  if (widget.isRegistered)
                    _buildActionCard(
                      context: context,
                      icon: Icons.smart_toy,
                      title: 'AI Summarization',
                      subtitle:
                          'Record speech, transcribe, summarize, and export PDF',
                      color: Colors.pink,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SummarizerScreen(),
                          ),
                        );
                      },
                    ),

                  if (widget.isRegistered) const SizedBox(height: 12),

                  // Search Tournaments Card
                  _buildActionCard(
                    context: context,
                    icon: Icons.search,
                    title: 'Search Tournaments',
                    subtitle: 'Browse all available tournaments',
                    color: Colors.brown,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchTournamentsScreen(
                            isGuest: !widget.isRegistered,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Search Debaters Card
                  _buildActionCard(
                    context: context,
                    icon: Icons.person_search,
                    title: 'Search Debaters',
                    subtitle: 'Find debaters and their statistics',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SearchDebatersScreen(
                            isGuest: !widget.isRegistered,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 70),

            // Footer Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 82,
                        height: 82,
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'TabDeb',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Organize, manage, and track debate tournaments with ease.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialLink(
                        assetPath: 'assets/icons/facebook.svg',
                        color: const Color(0xFF1877F2),
                        url: 'https://www.facebook.com/abdullahiar2811',
                      ),
                      const SizedBox(width: 20),
                      _buildSocialLink(
                        assetPath: 'assets/icons/linkedin.svg',
                        color: const Color(0xFF1877F2),
                        url: 'https://www.linkedin.com/in/abdullahcsembstu2811',
                      ),
                      const SizedBox(width: 20),
                      _buildSocialLink(
                        assetPath: 'assets/icons/github.svg',
                        color: const Color(0xFF1877F2),
                        url: 'https://github.com/abdullah2811',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    '© 2026 Debate Tournament App. All rights reserved.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context) {
    final notifications = _appStats?.notifications ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${notifications.length} ${notifications.length == 1 ? 'message' : 'messages'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Notifications list
            Flexible(
              child: notifications.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'ll see notifications here when there are updates.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.campaign,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            notification,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLink({
    required String assetPath,
    required Color color,
    required String url,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: SvgPicture.asset(
          assetPath,
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
