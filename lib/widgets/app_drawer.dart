
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ta_monitor/providers/theme_provider.dart';
import 'package:ta_monitor/screens/chat/chat_screen.dart';
import 'package:ta_monitor/screens/home/home_page.dart';
import 'package:ta_monitor/screens/profile/profile_page.dart';
import 'package:ta_monitor/services/chat_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Drawer(); // Should not happen if app logic is correct
    }

    return Drawer(
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final role = userData['role'] as String?;

          return Column(
            children: [
              _buildModernHeader(context, userData),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.dashboard_customize_outlined,
                      title: 'Dashboard',
                      isSelected: true,
                      onTap: () {
                        Navigator.pop(context);
                        if (role == 'Dosen') {
                          // Already on dashboard usually
                        } else {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const HomePage()),
                          );
                        }
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.account_circle_outlined,
                      title: 'My Profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ProfilePage()),
                        );
                      },
                    ),
                    if (role == 'Mahasiswa') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Divider(thickness: 0.5),
                      ),
                      _buildStudentChatTile(context, user.uid, userData),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Divider(thickness: 0.5),
                    ),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        final isDark = themeProvider.themeMode == ThemeMode.dark;
                        return _buildMenuItem(
                          context,
                          icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          title: isDark ? 'Light Mode' : 'Dark Mode',
                          onTap: () => themeProvider.toggleTheme(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildLogoutButton(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, Map<String, dynamic> userData) {
    final fullName = userData['fullName'] as String? ?? 'User';
    final email = userData['email'] as String? ?? 'No email';
    final profileImageUrl = userData['profileImageUrl'] as String?;
    final role = userData['role'] as String? ?? 'Student';
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : null,
              child: profileImageUrl == null || profileImageUrl.isEmpty
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
        leading: Icon(
          icon,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentChatTile(BuildContext context, String studentId, Map<String, dynamic> studentData) {
    final lecturerId = studentData['lecturerId'] as String?;
    return _buildMenuItem(
      context,
      icon: Icons.chat_bubble_outline,
      title: 'Chat with Lecturer',
      onTap: () async {
        if (lecturerId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No assigned lecturer.')),
          );
          return;
        }
        Navigator.pop(context);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        try {
          final chatService = ChatService();
          final chatRoom = await chatService.getOrCreateChatRoom(studentId, lecturerId);
          Navigator.pop(context);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => ChatScreen(chatRoom: chatRoom, currentUserId: studentId),
          ));
        } catch (e) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open chat: $e')),
          );
        }
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => FirebaseAuth.instance.signOut(),
      icon: const Icon(Icons.logout, size: 18),
      label: const Text('Logout'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade700,
        elevation: 0,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
