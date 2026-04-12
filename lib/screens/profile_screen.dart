import 'package:tabdeb/screens/welcome_screen.dart';
import 'package:flutter/material.dart';

import '../models/user.dart' as app_user;

class ProfileScreen extends StatefulWidget {
  final app_user.User? currentUser;

  const ProfileScreen({Key? key, this.currentUser}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: widget.currentUser == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 100),
                      Icon(
                        Icons.lock,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Profile Not Available',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please log in to view your profile',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _buildProfileContent(context),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context) {
    if (widget.currentUser == null) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        // Profile Header Section
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
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 58,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.blue.shade700,
                          ),
                          onPressed: () {
                            // TODO: Change profile picture
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.currentUser!.name.isNotEmpty
                      ? widget.currentUser!.name
                      : 'User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${widget.currentUser!.userID}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.currentUser!.clubName != null
                        ? 'Member of ${widget.currentUser!.clubName}'
                        : 'No Club/Organization',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Statistics Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.emoji_events,
                  value: '12',
                  label: 'Tournaments\nOrganized',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.groups,
                  value: '156',
                  label: 'Teams\nManaged',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  value: '4.8',
                  label: 'Average\nRating',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Profile Information Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              _buildInfoCard(
                icon: Icons.email,
                title: 'Email',
                value: widget.currentUser!.email,
                color: Colors.blue,
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.badge,
                title: 'User ID',
                value: '@${widget.currentUser!.userID}',
                color: Colors.green,
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.school,
                title: 'Club/Organization',
                value: widget.currentUser!.clubName ?? 'Not provided',
                color: Colors.purple,
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.location_on,
                title: 'Location',
                value: widget.currentUser!.address ?? 'Not provided',
                color: Colors.orange,
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.phone,
                title: 'Phone',
                value: widget.currentUser!.phoneNumber ?? 'Not provided',
                color: Colors.red,
              ),

              const SizedBox(height: 12),

              _buildInfoCard(
                icon: Icons.calendar_today,
                title: 'Member Since',
                value: widget.currentUser!.memberSince != null
                    ? '${widget.currentUser!.memberSince!.day}/${widget.currentUser!.memberSince!.month}/${widget.currentUser!.memberSince!.year}'
                    : 'N/A',
                color: Colors.teal,
              ),

              const SizedBox(height: 24),

              // Action Buttons
              const Text(
                'Account Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              _buildActionButton(
                icon: Icons.edit,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                color: Colors.blue,
                onTap: () {
                  _updatePersonalInfo(widget.currentUser!, context, setState);
                },
              ),

              const SizedBox(height: 12),

              _buildActionButton(
                icon: Icons.lock,
                title: 'Change Password',
                subtitle: 'Update your account password',
                color: Colors.orange,
                onTap: () {
                  _changePassword(widget.currentUser!, context, setState);
                },
              ),

              const SizedBox(height: 12),

              _buildActionButton(
                icon: Icons.history,
                title: 'Activity History',
                subtitle: 'View your tournament history',
                color: Colors.purple,
                onTap: () {
                  // TODO: Navigate to activity history
                },
              ),

              const SizedBox(height: 12),

              _buildActionButton(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                color: Colors.red,
                onTap: () {
                  _logout(context);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color color = Colors.blue,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
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
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _changePassword(app_user.User currentUser, BuildContext context,
    void Function(void Function()) setState) {
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmNewPasswordController =
      TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
              ),
              obscureText: true,
            ),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
              ),
              obscureText: true,
            ),
            TextField(
              controller: confirmNewPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newPassword = newPasswordController.text.trim();
            final confirmPassword = confirmNewPasswordController.text.trim();

            if (newPassword.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password cannot be empty'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            if (newPassword != confirmPassword) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Passwords do not match'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            currentUser.updatePassword(newPassword).then((_) {
              Navigator.of(dialogContext).pop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }).catchError((error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            });
          },
          child: const Text('Update Password'),
        ),
      ],
    ),
  );
}

void _logout(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const WelcomeScreen(),
                ));
          },
          child: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}

void _updatePersonalInfo(app_user.User currentUser, BuildContext context,
    void Function(void Function()) setState) {
  final TextEditingController nameController =
      TextEditingController(text: currentUser.name);
  final TextEditingController emailController =
      TextEditingController(text: currentUser.email);
  final TextEditingController clubNameController =
      TextEditingController(text: currentUser.clubName ?? '');
  final TextEditingController phoneNumberController =
      TextEditingController(text: currentUser.phoneNumber ?? '');
  final TextEditingController addressController =
      TextEditingController(text: currentUser.address ?? '');

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clubNameController,
              decoration: const InputDecoration(
                labelText: 'Club/Organization',
                prefixIcon: Icon(Icons.school),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneNumberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final name = nameController.text.trim();
            final email = emailController.text.trim();
            final clubName = clubNameController.text.trim().isEmpty
                ? null
                : clubNameController.text.trim();
            final phoneNumber = phoneNumberController.text.trim().isEmpty
                ? null
                : phoneNumberController.text.trim();
            final address = addressController.text.trim().isEmpty
                ? null
                : addressController.text.trim();

            if (name.isEmpty || email.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Name and Email are required'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            try {
              // Show loading indicator
              showDialog(
                context: dialogContext,
                barrierDismissible: false,
                builder: (loadingContext) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              // Update all fields
              await Future.wait([
                if (name != currentUser.name) currentUser.updateName(name),
                if (email != currentUser.email) currentUser.updateEmail(email),
                if (clubName != currentUser.clubName)
                  currentUser.updateClubName(clubName),
                if (phoneNumber != currentUser.phoneNumber)
                  currentUser.updatePhoneNumber(phoneNumber),
                if (address != currentUser.address)
                  currentUser.updateAddress(address),
              ]);

              // Close loading dialog
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }

              // Close edit dialog
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }

              // Refresh the UI
              setState(() {});

              // Show success message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (error) {
              // Close loading dialog if open
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating profile: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text('Save Changes'),
        ),
      ],
    ),
  );
}
