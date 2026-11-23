import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'app_drawer.dart';
import 'styles.dart';
import 'listing_model.dart';
import 'listing_detail_screen.dart';
import 'api_service.dart';
import 'create_listing_screen.dart';

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({Key? key}) : super(key: key);

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Listing> listings = [];
  bool isLoading = true;
  String? errorMessage;

  // Filter & Sort State
  String selectedCampus = "All";
  String selectedSort =
      "newest"; // 'newest', 'oldest', 'price_asc', 'price_desc', 'alpha'

  @override
  void initState() {
    super.initState();
    fetchListings();
  }

  // 1. The API Call (Now accepts query parameters)
  Future<void> fetchListings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Build the URL with parameters
      String url = '$apiBaseUrl/listings?';

      if (_searchController.text.isNotEmpty) {
        url += 'q=${Uri.encodeComponent(_searchController.text)}&';
      }
      if (selectedCampus != "All") {
        url += 'campus=${Uri.encodeComponent(selectedCampus)}&';
      }
      url += 'sort=$selectedSort';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data']['items'] as List;

        setState(() {
          listings = items
              .map(
                (json) => Listing(
                  id: json['id'],
                  name: json['name'],
                  description: json['description'],
                  hourlyRate: json['hourly_rate'].toDouble(),
                  campus: json['campus'],
                  negotiable: json['negotiable'],
                  imageUrl: json['image_url'],
                  ownerUsername: json['owner_username'],
                  condition: json['condition'],
                  maxDuration: json['max_duration'],
                  postedAt: json['posted_at'],
                ),
              )
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              "Failed to load listings (Status: ${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error connecting to server: $e";
        isLoading = false;
      });
    }
  }

  // Helper to show the Sort menu
  /* void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Sort By",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Newest First'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedSort = 'newest');
                  fetchListings();
                },
              ),
              ListTile(
                title: const Text('Oldest First'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedSort = 'oldest');
                  fetchListings();
                },
              ),
              ListTile(
                title: const Text('Price: Low to High'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedSort = 'price_asc');
                  fetchListings();
                },
              ),
              ListTile(
                title: const Text('Price: High to Low'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedSort = 'price_desc');
                  fetchListings();
                },
              ),
              ListTile(
                title: const Text('Alphabetical (A-Z)'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => selectedSort = 'alpha');
                  fetchListings();
                },
              ),
            ],
          ),
        );
      },
    );
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const AppDrawer(), // SCRUM-26 hamburger menu
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Listings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
        // Builder gives a context *inside* the Scaffold, so openDrawer() finds it.
        leading: Builder(
          builder: (context) => IconButton(
            key: const Key('menu_button'),
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onSubmitted: (value) =>
                  fetchListings(), // Fetch from backend on Enter
              decoration: InputDecoration(
                hintText: "Search by item name or description",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => fetchListings(),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // FILTER AND SORT ROW
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // CAMPUS FILTER
                PopupMenuButton<String>(
                  onSelected: (String campus) {
                    setState(() {
                      selectedCampus = campus;
                    });
                    fetchListings(); // Re-fetch from backend
                  },
                  itemBuilder: (BuildContext context) {
                    return ['All', 'Main', 'City'].map((String choice) {
                      return PopupMenuItem<String>(
                        value: choice,
                        child: Text(
                          choice == 'All' ? 'All Campuses' : '$choice Campus',
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          selectedCampus == 'All'
                              ? 'Filter'
                              : '$selectedCampus Campus',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // SORT BUTTON (PopupMenu)
                PopupMenuButton<String>(
                  onSelected: (String sortOption) {
                    setState(() {
                      selectedSort = sortOption;
                    });
                    fetchListings(); // Re-fetch from backend
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      {'label': 'Newest First', 'value': 'newest'},
                      {'label': 'Oldest First', 'value': 'oldest'},
                      {'label': 'Price: Low to High', 'value': 'price_asc'},
                      {'label': 'Price: High to Low', 'value': 'price_desc'},
                      {'label': 'Alphabetical (A-Z)', 'value': 'alpha'},
                    ].map((option) {
                      return PopupMenuItem<String>(
                        value: option['value'],
                        child: Text(option['label']!),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sort, size: 18),
                        SizedBox(width: 4),
                        Text("Sort"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // LISTINGS GRID
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : listings.isEmpty
                ? const Center(child: Text("No items found"))
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.75,
                        ),
                    itemCount: listings.length,
                    itemBuilder: (context, index) {
                      final item = listings[index];
                      return _buildListingCard(item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Open the form and wait. It comes back with true if a listing was posted.
          final posted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const CreateListingScreen()),
          );
          if (posted == true && mounted) {
            fetchListings(); // reload so the new item shows up
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Listing posted')),
            );
          }
        },
                backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }

  Widget _buildListingCard(Listing item) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListingDetailScreen(listing: item),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                        ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                height: 100,
                width: double.infinity,
                color: Colors.grey[300],
                child: item.imageUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.image, size: 50, color: Colors.grey),
                      )
                    : Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                        errorBuilder: (context, error, stack) => const Center(
                          child: Icon(Icons.broken_image,
                              size: 50, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${item.campus} Campus",
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Rs ${item.hourlyRate.toInt()} / hr",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppStyles.primaryColor,
                      fontSize: 15,
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
}
