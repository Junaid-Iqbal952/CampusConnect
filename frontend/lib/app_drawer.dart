import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';
import 'change_OR_reset_pw.dart';
import 'coming_soon_screen.dart';
import 'styles.dart';

/// SCRUM-26: the hamburger menu (see "Hamburger Menu" wireframe).
///
/// Add it to any page with:   Scaffold(drawer: const AppDrawer(), ...)
/// The page's top-left menu button then opens it.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  // Saved at login/sign-up by auth_session.dart.
  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _userName = prefs.getString('user_name') ?? '');
  }

  /// Close the menu first, then open the page on top of the current one,
  /// so Back returns to where the user was.
  void _open(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('app_drawer'),
      backgroundColor: AppStyles.backgroundColor,
      shape: const RoundedRectangleBorder(), // square corners like the wireframe
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: "Campus Connect"  ...  "Close x"
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Campus Connect',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primaryColor,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('drawer_close'),
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.black87),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Close'),
                        SizedBox(width: 4),
                        Icon(Icons.close, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Who is logged in
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName.isEmpty ? 'Student' : _userName,
                    key: const Key('drawer_user_name'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Campus member',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Menu items (wireframe order)
            _item(
              icon: Icons.person_outline,
              label: 'My Profile',
              onTap: () => _open(const ComingSoonScreen(title: 'My Profile')),
            ),
            _item(
              icon: Icons.dashboard_outlined,
              label: 'My Dashboard',
              onTap: () => _open(const ComingSoonScreen(title: 'My Dashboard')),
            ),
            _item(
              icon: Icons.add_box_outlined,
              label: 'Post a New Listing',
              onTap: () => _open(const ComingSoonScreen(title: 'Post a New Listing')),
            ),
            _item(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () => _open(const ResetPasswordScreen(isChangePassword: true)),
            ),
            _item(
              icon: Icons.logout,
              label: 'Logout',
              // Don't close the menu first: this clears every screen (menu included)
              // and goes to Welcome. Closing first would remove the menu before
              // logout finishes, and it would never reach Welcome.
              onTap: () => logoutAndGoToWelcome(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon, color: AppStyles.primaryColor),
            title: Text(label, style: const TextStyle(fontSize: 15)),
            onTap: onTap,
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
