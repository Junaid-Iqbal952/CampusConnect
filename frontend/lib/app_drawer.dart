import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import 'auth_session.dart';
import 'change_OR_reset_pw.dart';
import 'coming_soon_screen.dart';
import 'styles.dart';
import 'create_listing_screen.dart';
import 'profile_screen.dart';

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
  bool _mapsExpanded = false;

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

  void _openCampusMap(
    BuildContext rootContext, {
    required String campusName,
    required String assetPath,
  }) {
    Navigator.pop(context); // close the drawer first
    showDialog<void>(
      context: rootContext,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppStyles.backgroundColor,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: AppStyles.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      campusName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.7,
              ),
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Campus map image not found.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('app_drawer'),
      backgroundColor: AppStyles.backgroundColor,
      shape:
          const RoundedRectangleBorder(), // square corners like the wireframe
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
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black87,
                    ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
              onTap: () => _open(const ProfileScreen()),
            ),
            _item(
              icon: Icons.dashboard_outlined,
              label: 'My Dashboard',
              onTap: () => _open(const MyDashboardScreen()),
            ),
            _item(
              icon: Icons.add_box_outlined,
              label: 'Post a New Listing',
              onTap: () => _open(const CreateListingScreen()),
            ),
            _campusMapsItem(context),
            _item(
              icon: Icons.lock_outline,
              label: 'Change Password',
              onTap: () =>
                  _open(const ResetPasswordScreen(isChangePassword: true)),
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

  Widget _campusMapsItem(BuildContext rootContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: Icon(Icons.map_outlined, color: AppStyles.primaryColor),
              title: const Text('Campus Maps', style: TextStyle(fontSize: 15)),
              trailing: Icon(
                _mapsExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.black54,
              ),
              onExpansionChanged: (expanded) =>
                  setState(() => _mapsExpanded = expanded),
              children: [
                ListTile(
  contentPadding: const EdgeInsets.only(left: 40),
  title: const Text('Main Campus', style: TextStyle(fontSize: 14)),
  onTap: () => _openCampusMap(
    rootContext,
    campusName: 'IBA Main Campus Map',
    assetPath: 'assets/main_campus_map.jpg',
  ),
),
ListTile(
  contentPadding: const EdgeInsets.only(left: 40),
  title: const Text('City Campus', style: TextStyle(fontSize: 14)),
  onTap: () => _openCampusMap(
    rootContext,
    campusName: 'IBA City Campus Map',
    assetPath: 'assets/city_campus_map.jpg',
  ),
),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
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