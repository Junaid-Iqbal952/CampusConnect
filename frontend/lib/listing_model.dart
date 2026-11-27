class Listing {
  final int id;
  final String name;
  final String description;
  final double hourlyRate;
  final String campus;
  final bool negotiable;
  final String imageUrl;
  final String ownerUsername;
  final String condition;
  final int maxDuration;
  final String postedAt;
  final String status; // 'available' for now; later also 'active' etc.

  Listing({
    required this.id,
    required this.name,
    required this.description,
    required this.hourlyRate,
    required this.campus,
    required this.negotiable,
    required this.imageUrl,
    required this.ownerUsername,
    required this.condition,
    required this.maxDuration,
    required this.postedAt,
    this.status = 'available',
  });

  /// Turns one item from the backend's JSON into a Listing.
  /// Used by the feed (GET /listings) and My Dashboard (GET /listings/mine).
  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      hourlyRate: (json['hourly_rate'] as num).toDouble(),
      campus: json['campus'],
      negotiable: json['negotiable'] == true,
      imageUrl: json['image_url'] ?? '',
      ownerUsername: json['owner_username'] ?? '',
      condition: json['condition'] ?? 'Not specified',
      maxDuration: json['max_duration'] ?? 1,
      postedAt: json['posted_at'] ?? '',
      status: json['status'] ?? 'available',
    );
  }
}