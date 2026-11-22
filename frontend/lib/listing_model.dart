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
  });
}
