import 'package:flutter/material.dart';

import 'styles.dart';
import 'listing_model.dart';
import 'request_rent_button.dart';

class ListingDetailScreen extends StatelessWidget {
  final Listing listing;

  const ListingDetailScreen({Key? key, required this.listing})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Listing Detail",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppStyles.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. IMAGE
                        Container(
              width: double.infinity,
              height: 250,
              color: Colors.grey[300],
              child: listing.imageUrl.isEmpty
                  ? const Center(
                      child: Icon(Icons.image, size: 100, color: Colors.grey),
                    )
                  : Image.network(
                      listing.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stack) => const Center(
                        child: Icon(Icons.broken_image,
                            size: 100, color: Colors.grey),
                      ),
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. ITEM NAME
                  Text(
                    listing.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. RATE & NEGOTIABLE ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Rs ${listing.hourlyRate.toInt()} / hr",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.primaryColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: listing.negotiable
                              ? Colors.green[100]
                              : Colors.red[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          listing.negotiable ? "Negotiable" : "Fixed Price",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: listing.negotiable
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. DETAILS TABLE (Now with borders)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey[300]!,
                      ), // Outer border
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildTableRow(
                          "Duration",
                          "Max ${listing.maxDuration} Days",
                          isLast: false,
                        ),
                        _buildTableRow(
                          "Campus",
                          "${listing.campus} Campus",
                          isLast: false,
                        ),
                        _buildTableRow(
                          "Posted by",
                          listing.ownerUsername,
                          isLast: false,
                        ),
                        _buildTableRow(
                          "Posted date",
                          listing.postedAt.substring(0, 10),
                          isLast: true,
                        ), // Last one removes bottom border
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. DESCRIPTION BOX
                  _buildSectionBox(
                    title: "Description",
                    content: listing.description,
                  ),

                  const SizedBox(height: 15),

                  // 6. CONDITION BOX
                  _buildSectionBox(title: "Condition", content: listing.condition),

                  const SizedBox(height: 30),

                  // 7. REQUEST FOR RENT BUTTON (SCRUM-37, request_rent_button.dart)
                  RequestRentButton(listingId: listing.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Table row with borders
  Widget _buildTableRow(String label, String value, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        // Add a bottom border unless it's the last row
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // HELPER: Creates the Description and Condition boxes
  Widget _buildSectionBox({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50], // Slightly lighter background
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}
