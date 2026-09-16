/// A customer's rating of the app, as every customer reads it.
class AppReview {
  const AppReview({
    required this.id,
    required this.displayName,
    required this.rating,
    required this.comment,
    required this.writtenAt,
    this.edited = false,
    this.mine = false,
  });

  final String id;

  /// A first name and an initial — "Chioma A." — never the whole name.
  final String displayName;

  /// One to five.
  final int rating;
  final String comment;
  final DateTime writtenAt;

  /// Rewritten since it was first left.
  final bool edited;

  /// Written by the reader: the one they may edit or withdraw.
  final bool mine;

  static AppReview fromApi(Map<String, dynamic> j) => AppReview(
        id: j['id'] as String? ?? '',
        displayName: j['displayName'] as String? ?? 'A customer',
        rating: ((j['rating'] as num?)?.toInt() ?? 0).clamp(0, 5),
        comment: j['comment'] as String? ?? '',
        writtenAt: DateTime.tryParse(j['writtenAt'] as String? ?? '') ??
            DateTime.now(),
        edited: j['edited'] as bool? ?? false,
        mine: j['mine'] as bool? ?? false,
      );
}

/// The headline: the average, the count, and how many gave each star.
class ReviewSummary {
  const ReviewSummary({
    required this.average,
    required this.count,
    required this.perStar,
  });

  /// One decimal, or null until anybody has rated.
  final double? average;
  final int count;

  /// Index 1..5; index 0 unused.
  final List<int> perStar;

  static const empty = ReviewSummary(
    average: null,
    count: 0,
    perStar: [0, 0, 0, 0, 0, 0],
  );

  static ReviewSummary fromApi(Map<String, dynamic> j) => ReviewSummary(
        average: (j['average'] as num?)?.toDouble(),
        count: (j['count'] as num?)?.toInt() ?? 0,
        perStar: [
          0,
          (j['oneStar'] as num?)?.toInt() ?? 0,
          (j['twoStar'] as num?)?.toInt() ?? 0,
          (j['threeStar'] as num?)?.toInt() ?? 0,
          (j['fourStar'] as num?)?.toInt() ?? 0,
          (j['fiveStar'] as num?)?.toInt() ?? 0,
        ],
      );
}
