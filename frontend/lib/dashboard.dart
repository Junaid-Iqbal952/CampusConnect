import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_session.dart';
import 'listing_api.dart';
import 'listing_model.dart';
import 'styles.dart';

/// "My Dashboard" (opened from the hamburger menu).
///
/// The page is a list of SECTIONS, one under the other:
///   1. My Listings (SCRUM-51)
///   2. Pending requests (SCRUM-38, Junaid): add it in build() below.
class MyDashboardScreen extends StatefulWidget {
  final ListingApi? api; // tests can pass a fake one
  const MyDashboardScreen({super.key, this.api});

  @override
  State<MyDashboardScreen> createState() => _MyDashboardScreenState();
}

class _MyDashboardScreenState extends State<MyDashboardScreen> {
  late final ListingApi _api = widget.api ?? ListingApi();

  List<Listing> _myListings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMyListings();
  }

  Future<void> _loadMyListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) {
      if (!mounted) return;
      await clearSessionAndGoToWelcome(context,
          message: 'Session expired. Please log in again');
      return;
    }

    try {
      final items = await _api.getMyListings(token);
      if (!mounted) return;
      setState(() {
        _myListings = items;
        _isLoading = false;
      });
    } on SessionExpiredException catch (e) {
      // must come BEFORE AuthException (it is a child of it)
      if (!mounted) return;
      await clearSessionAndGoToWelcome(context, message: e.message);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'My Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyListings, // pull down to reload
        child: ListView(
          key: const Key('dashboard_list'),
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('My Listings'),
            _myListingsSection(),

            // SCRUM-38 (Junaid): add the "Pending requests" section here, e.g.
            // const SizedBox(height: 24),
            // _sectionTitle('Pending requests'),
            // ...
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppStyles.primaryColor,
        ),
      ),
    );
  }

  /// Spinner, error, "nothing yet", or the list of cards.
  Widget _myListingsSection() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          Text(
            _errorMessage!,
            key: const Key('my_listings_error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadMyListings,
            child: const Text('Try again'),
          ),
        ],
      );
    }

    if (_myListings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "You haven't posted any listings yet.",
          key: Key('my_listings_empty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _myListings.map(_myListingCard).toList(),
    );
  }

  /// One row: photo on the left, name / campus / price / status on the right.
  Widget _myListingCard(Listing item) {
    return Card(
      key: Key('my_listing_${item.id}'),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey[200],
                  child: item.imageUrl.isEmpty
                      ? const Icon(Icons.image, color: Colors.grey)
                      : Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.campus} Campus',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${item.hourlyRate.toInt()} / hr',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(item.status),
            ],
          ),
        ),
    );
  }

  /// Small label like "Available". Green when available, grey otherwise.
  Widget _statusChip(String status) {
    final isAvailable = status == 'available';
    final label = status.isEmpty
        ? ''
        : status[0].toUpperCase() + status.substring(1); // available -> Available
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green[50] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isAvailable ? Colors.green[800] : Colors.grey[700],
        ),
      ),
    );
  }
}