import 'package:flutter/material.dart';

import '../models/novel.dart';
import '../services/firebase_data.dart';
import '../widgets/novel_cover.dart';
import '../widgets/app_backdrop.dart';
import 'detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tủ sách của tôi',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.history_rounded), text: 'Lịch sử đọc'),
            Tab(icon: Icon(Icons.favorite_border_rounded), text: 'Yêu thích'),
            Tab(icon: Icon(Icons.download_done_rounded), text: 'Đã lưu'),
          ],
        ),
      ),
      body: AppBackdrop(
        child: const TabBarView(
          children: [
            _LibraryList(collection: 'readingHistory'),
            _LibraryList(collection: 'favorites'),
            _LibraryList(collection: 'downloads'),
          ],
        ),
      ),
    ),
  );
}

class _LibraryList extends StatefulWidget {
  const _LibraryList({required this.collection});
  final String collection;

  @override
  State<_LibraryList> createState() => _LibraryListState();
}

class _LibraryListState extends State<_LibraryList> {
  final Set<String> _selected = {};
  bool get _history => widget.collection == 'readingHistory';

  Future<void> _deleteSelected(List<Map<String, dynamic>> entries) async {
    final ids = _selected.toList();
    try {
      await FirebaseData.clearLibrary(widget.collection, ids);
      if (mounted) setState(_selected.clear);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không xóa được: $error')));
    }
  }

  void _open(Novel novel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetailScreen(novel: novel)),
  );

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: FirebaseData.watchLibrary(widget.collection),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Center(child: Text('Không tải được tủ sách: ${snapshot.error}'));
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final entries = snapshot.data!;
      if (entries.isEmpty)
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _history
                      ? Icons.auto_stories_outlined
                      : widget.collection == 'favorites'
                      ? Icons.favorite_border
                      : Icons.download_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _history
                      ? 'Chưa có lịch sử đọc'
                      : widget.collection == 'favorites'
                      ? 'Chưa có truyện yêu thích'
                      : 'Chưa có truyện đã lưu',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mở một truyện và dùng các nút lưu để thêm vào tủ sách.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      return Column(
        children: [
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(child: Text('${_selected.length} truyện đã chọn')),
                  TextButton.icon(
                    onPressed: () => setState(_selected.clear),
                    icon: const Icon(Icons.close),
                    label: const Text('Bỏ chọn'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _deleteSelected(entries),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa đã chọn'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final data = entries[index];
                final id = data['novelId'] as String? ?? '';
                final novel = Novel.fromMap(
                  id,
                  Map<String, dynamic>.from(data),
                );
                final selected = _selected.contains(id);
                final percent =
                    ((data['progressPercent'] as num?)?.toDouble() ?? 0).clamp(
                      0.0,
                      1.0,
                    );
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    selected: selected,
                    onLongPress: () => setState(
                      () => selected ? _selected.remove(id) : _selected.add(id),
                    ),
                    onTap: () => _selected.isNotEmpty
                        ? setState(
                            () => selected
                                ? _selected.remove(id)
                                : _selected.add(id),
                          )
                        : _open(novel),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selected.isNotEmpty)
                          Checkbox(
                            value: selected,
                            onChanged: (value) => setState(
                              () => value == true
                                  ? _selected.add(id)
                                  : _selected.remove(id),
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: SizedBox(
                            width: 52,
                            height: 70,
                            child: NovelCover(url: novel.coverUrl),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      novel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _history
                              ? 'Chương ${data['chapterNumber'] ?? 1}  ·  ${novel.author}'
                              : '${novel.category}  ·  ${novel.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_history) ...[
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: percent,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ],
                      ],
                    ),
                    trailing: _selected.isEmpty
                        ? IconButton(
                            tooltip: 'Xóa khỏi tủ sách',
                            onPressed: () => FirebaseData.deleteLibraryEntry(
                              widget.collection,
                              id,
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
