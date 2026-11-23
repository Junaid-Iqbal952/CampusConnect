import 'package:flutter/material.dart';

import 'styles.dart';

/// Placeholder for pages that will be built in later sprints
/// (My Profile, My Dashboard, Post a New Listing).
/// When a real page is ready, change its menu item in app_drawer.dart to open it.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text(
          'Coming in a later sprint',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
