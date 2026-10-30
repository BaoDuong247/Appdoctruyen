import 'package:flutter/material.dart';

import '../models/novel.dart';
import '../services/firebase_data.dart';
import '../widgets/novel_cover.dart';
import 'reader_screen.dart';

class DetailScreen extends StatefulWidget {
  final Novel novel;
  const DetailScreen({super.key, required this.novel});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _chapterSearch = TextEditingController();
  String _chapterQuery = '';
  bool _newestFirst = false;
  bool _showFullDescription = false;
  bool _chaptersTab = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => FirebaseData.recordView(widget.novel).catchError((_) {}),
    );
  }

  @override
  void dispose() {
    _chapterSearch.dispose();
    super.dispose();
  }

  Future<void> _openReader(
    ChapterContent chapter, {
    double progress = 0,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          novel: widget.novel,
          novelTitle: widget.novel.title,
          coverUrl: widget.novel.coverUrl,
          chapters: widget.novel.chapters,
          chapter: chapter,
          initialProgress: progress,
        ),
      ),
    );
  }

  Future<void> _writeReview(List<Map<String, dynamic>> reviews) async {
    final current = await FirebaseData.watchMyReview(widget.novel.id).first;
    if (!mounted) return;
    final rating = ValueNotifier<int>(
      (current?['rating'] as num?)?.toInt() ?? 5,
    );
    final comment = TextEditingController(
      text: current?['comment'] as String? ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(current == null ? 'Đánh giá truyện' : 'Sửa đánh giá'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: rating,
                builder: (context, value, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      onPressed: () => rating.value = i + 1,
                      icon: Icon(
                        i < value
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Colors.amber.shade700,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nhận xét',
                  hintText: 'Chia sẻ cảm nhận của bạn',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gửi đánh giá'),
          ),
        ],
      ),
    );
    if (saved == true) {
      try {
        await FirebaseData.saveReview(
          novelId: widget.novel.id,
          rating: rating.value,
          comment: comment.text,
        );
        if (mounted) _message('Đã lưu đánh giá của bạn.');
      } catch (error) {
        if (mounted) _message('Không lưu được đánh giá: $error', error: true);
      }
    }
    rating.dispose();
    comment.dispose();
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final novel = widget.novel;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 285,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                novel.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'reader-cover-${novel.title}',
                    child: NovelCover(url: novel.coverUrl),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black87, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoTag(
                            icon: Icons.sell_outlined,
                            label: novel.category,
                          ),
                          _InfoTag(
                            icon: Icons.sync_rounded,
                            label: novel.status,
                          ),
                          _InfoTag(
                            icon: Icons.menu_book_outlined,
                            label: '${novel.chapters.length} chương',
                          ),
                          _InfoTag(
                            icon: Icons.visibility_outlined,
                            label: '${novel.viewCount} lượt xem',
                          ),
                          _InfoTag(
                            icon: Icons.star_rounded,
                            label: novel.rating.toStringAsFixed(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tác giả: ${novel.author}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: novel.chapters.isEmpty
                                  ? null
                                  : () => _openReader(novel.chapters.first),
                              icon: const Icon(Icons.menu_book_rounded),
                              label: const Text('Đọc từ đầu'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: FirebaseData.watchLibrary('favorites'),
                            builder: (context, snapshot) {
                              final isFavorite =
                                  snapshot.data?.any(
                                    (entry) => entry['novelId'] == novel.id,
                                  ) ??
                                  false;
                              return OutlinedButton.icon(
                                onPressed: () async {
                                  try {
                                    await FirebaseData.setFavorite(
                                      novel,
                                      !isFavorite,
                                    );
                                  } catch (error) {
                                    if (mounted)
                                      _message(
                                        'Đăng nhập để lưu truyện yêu thích: $error',
                                        error: true,
                                      );
                                  }
                                },
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite ? Colors.pink : null,
                                ),
                                label: Text(
                                  isFavorite ? 'Đang theo dõi' : 'Theo dõi',
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: FirebaseData.watchLibrary('downloads'),
                            builder: (context, snapshot) {
                              final downloaded =
                                  snapshot.data?.any(
                                    (entry) => entry['novelId'] == novel.id,
                                  ) ??
                                  false;
                              return IconButton.filledTonal(
                                tooltip: downloaded
                                    ? 'Đã lưu ngoại tuyến'
                                    : 'Lưu để đọc lại',
                                onPressed: () async {
                                  try {
                                    await FirebaseData.setDownloaded(
                                      novel,
                                      !downloaded,
                                    );
                                    if (mounted)
                                      _message(
                                        downloaded
                                            ? 'Đã xóa khỏi danh sách đã lưu.'
                                            : 'Đã lưu truyện và chương vào tủ sách.',
                                      );
                                  } catch (error) {
                                    if (mounted)
                                      _message(
                                        'Đăng nhập để lưu truyện: $error',
                                        error: true,
                                      );
                                  }
                                },
                                icon: Icon(
                                  downloaded
                                      ? Icons.download_done_rounded
                                      : Icons.download_outlined,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Giới thiệu nội dung',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        novel.description,
                        maxLines: _showFullDescription ? null : 3,
                        overflow: _showFullDescription
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _showFullDescription = !_showFullDescription,
                        ),
                        child: Text(
                          _showFullDescription ? 'Thu gọn' : 'Xem thêm',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('Danh sách chương'),
                            icon: Icon(Icons.format_list_bulleted),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            label: Text('Đánh giá'),
                            icon: Icon(Icons.star_outline),
                          ),
                        ],
                        selected: {_chaptersTab},
                        onSelectionChanged: (value) =>
                            setState(() => _chaptersTab = value.first),
                      ),
                      const SizedBox(height: 14),
                      if (_chaptersTab)
                        _buildChapters(context, novel)
                      else
                        _buildReviews(context, novel),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapters(
    BuildContext context,
    Novel novel,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: FirebaseData.watchLibrary('readingHistory'),
    builder: (context, historySnapshot) {
      final matchingHistory =
          historySnapshot.data
              ?.where((entry) => entry['novelId'] == novel.id)
              .toList() ??
          const [];
      final history = matchingHistory.isEmpty ? null : matchingHistory.first;
      final lastChapter = (history?['chapterNumber'] as num?)?.toInt() ?? 0;
      final progress = (history?['progressPercent'] as num?)?.toDouble() ?? 0;
      final chapters =
          novel.chapters
              .where(
                (chapter) =>
                    _chapterQuery.isEmpty ||
                    '${chapter.chapterNumber} ${chapter.title}'
                        .toLowerCase()
                        .contains(_chapterQuery.toLowerCase()),
              )
              .toList()
            ..sort(
              (a, b) => _newestFirst
                  ? b.chapterNumber.compareTo(a.chapterNumber)
                  : a.chapterNumber.compareTo(b.chapterNumber),
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (history != null && novel.chapters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  final chapter = novel.chapters.firstWhere(
                    (item) => item.chapterNumber == lastChapter,
                    orElse: () => novel.chapters.first,
                  );
                  _openReader(chapter, progress: progress);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Đọc tiếp chương $lastChapter'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chapterSearch,
                  onChanged: (value) =>
                      setState(() => _chapterQuery = value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Tìm số hoặc tên chương',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: _newestFirst
                    ? 'Xếp chương cũ trước'
                    : 'Xếp chương mới trước',
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
                icon: Icon(
                  _newestFirst ? Icons.south_rounded : Icons.north_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (chapters.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Chưa có chương phù hợp.')),
            )
          else
            ...chapters.map((chapter) {
              final read = chapter.chapterNumber <= lastChapter;
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: read
                        ? Colors.green.shade50
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      read ? Icons.done_rounded : Icons.menu_book_outlined,
                      size: 18,
                      color: read
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    'Chương ${chapter.chapterNumber}: ${chapter.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(read ? 'Đã đọc' : novel.status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openReader(chapter),
                ),
              );
            }),
        ],
      );
    },
  );

  Widget _buildReviews(
    BuildContext context,
    Novel novel,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: FirebaseData.watchReviews(novel.id),
    builder: (context, snapshot) {
      final reviews = snapshot.data ?? const <Map<String, dynamic>>[];
      final average = reviews.isEmpty
          ? novel.rating
          : reviews.fold<double>(
                  0,
                  (sum, item) =>
                      sum + ((item['rating'] as num?)?.toDouble() ?? 0),
                ) /
                reviews.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
              Text(
                '${average.toStringAsFixed(1)} / 5  ·  ${reviews.length} đánh giá',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _writeReview(reviews),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Viết đánh giá'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(22),
              child: Center(
                child: Text('Hãy là người đầu tiên để lại cảm nhận.'),
              ),
            )
          else
            ...reviews.map(
              (review) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review['displayName'] as String? ?? 'Độc giả',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          Text('${review['rating'] ?? 5}'),
                        ],
                      ),
                      if ((review['comment'] as String? ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(review['comment'] as String),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
