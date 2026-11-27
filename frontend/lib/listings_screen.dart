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

  String selectedCampus = "All";
  String selectedSort = "newest";

  @override
  void initState() {
    super.initState();
    fetchListings();
  }

  Future<void> fetchListings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
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
              .map((json) => Listing.fromJson(json))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Listings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onSubmitted: (value) => fetchListings(),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  onSelected: (String campus) {
                    setState(() => selectedCampus = campus);
                    fetchListings();
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
                PopupMenuButton<String>(
                  onSelected: (String sortOption) {
                    setState(() => selectedSort = sortOption);
                    fetchListings();
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
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.0,
                          vertical: 16.0,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 24,
                              mainAxisSpacing: 24,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: listings.length,
                        itemBuilder: (context, index) {
                          return _buildListingCard(listings[index]);
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final posted = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateListingScreen(),
            ),
          );
          if (posted == true && mounted) {
            fetchListings();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Listing posted')));
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
            // 1. IMAGE TAKES ALL REMAINING SPACE
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: item.imageUrl.isEmpty
                      ? const Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.grey,
                          ),
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
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // 2. TEXT TAKES EXACTLY WHAT IT NEEDS (No overflow)
            Padding(
              padding: const EdgeInsets.only(
                top: 14.0,
                bottom: 14.0,
                left: 12.0,
                right: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 8),
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
