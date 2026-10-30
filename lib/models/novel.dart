class ChapterContent {
  final int chapterNumber;
  final String title;
  final String content;

  const ChapterContent({
    required this.chapterNumber,
    required this.title,
    required this.content,
  });

  factory ChapterContent.fromMap(Map<String, dynamic> data) => ChapterContent(
    chapterNumber: (data['chapterNumber'] as num?)?.toInt() ?? 0,
    title: data['title'] as String? ?? '',
    content: data['content'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'chapterNumber': chapterNumber,
    'title': title,
    'content': content,
  };
}

class Novel {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String category;
  final String description;
  final double rating;
  final String status;
  final int viewCount;
  final int updatedAtMs;
  final Map<String, int> dailyViews;
  final Map<String, int> weeklyViews;
  final Map<String, int> monthlyViews;
  final List<ChapterContent> chapters;

  const Novel({
    this.id = '',
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.category,
    required this.description,
    required this.rating,
    this.status = 'Đang ra',
    this.viewCount = 0,
    this.updatedAtMs = 0,
    this.dailyViews = const {},
    this.weeklyViews = const {},
    this.monthlyViews = const {},
    this.chapters = const [],
  });

  static Map<String, int> _intMap(dynamic value) => value is Map
      ? value.map(
          (key, item) => MapEntry(key.toString(), (item as num?)?.toInt() ?? 0),
        )
      : const {};

  factory Novel.fromMap(String id, Map<String, dynamic> data) => Novel(
    id: id,
    title: data['title'] as String? ?? '',
    author: data['author'] as String? ?? '',
    coverUrl: data['coverUrl'] as String? ?? '',
    category: data['category'] as String? ?? '',
    description: data['description'] as String? ?? '',
    rating: (data['rating'] as num?)?.toDouble() ?? 0,
    status: data['status'] as String? ?? 'Đang ra',
    viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
    updatedAtMs: (data['updatedAtMs'] as num?)?.toInt() ?? 0,
    dailyViews: _intMap(data['dailyViews']),
    weeklyViews: _intMap(data['weeklyViews']),
    monthlyViews: _intMap(data['monthlyViews']),
    chapters: ((data['chapters'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (chapter) =>
              ChapterContent.fromMap(Map<String, dynamic>.from(chapter)),
        )
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    'category': category,
    'description': description,
    'rating': rating,
    'status': status,
    'viewCount': viewCount,
    'updatedAtMs': updatedAtMs,
    'dailyViews': dailyViews,
    'weeklyViews': weeklyViews,
    'monthlyViews': monthlyViews,
    'chapters': chapters.map((chapter) => chapter.toMap()).toList(),
  };
}
