import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/sample_catalog.dart';
import '../models/novel.dart';
import '../services/firebase_data.dart';
import '../widgets/novel_cover.dart';

class AdminNovelsTab extends StatelessWidget {
  const AdminNovelsTab({super.key});

  Future<void> _editNovel(BuildContext context, {Novel? novel}) async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController(text: novel?.title ?? '');
    final author = TextEditingController(text: novel?.author ?? '');
    final cover = TextEditingController(text: novel?.coverUrl ?? '');
    String? category = novel?.category;
    String? status = novel?.status ?? 'Đang ra';
    final description = TextEditingController(text: novel?.description ?? '');
    var coverBusy = false;
    final novelId = novel?.id.isNotEmpty == true
        ? novel!.id
        : FirebaseData.novels.doc().id;
    final result = await showDialog<Novel>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(novel == null ? 'Thêm truyện mới' : 'Chỉnh sửa truyện'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _formField(title, 'Tên truyện'),
                    _formField(author, 'Tác giả'),
                    _formField(cover, 'Đường dẫn ảnh bìa', hint: 'https://...'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: coverBusy
                              ? null
                              : () async {
                                  final image = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 88,
                                    maxWidth: 1800,
                                  );
                                  if (image == null) return;
                                  setDialogState(() => coverBusy = true);
                                  try {
                                    final url =
                                        await FirebaseData.uploadNovelCover(
                                          novelId: novelId,
                                          bytes: await image.readAsBytes(),
                                          fileName: image.name,
                                        );
                                    cover.text = url;
                                  } catch (error) {
                                    if (dialogContext.mounted)
                                      _message(
                                        dialogContext,
                                        'Không tải được ảnh. Kiểm tra Storage Rules: $error',
                                        error: true,
                                      );
                                  } finally {
                                    if (dialogContext.mounted)
                                      setDialogState(() => coverBusy = false);
                                  }
                                },
                          icon: coverBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload_outlined),
                          label: Text(
                            coverBusy
                                ? 'Đang tải ảnh…'
                                : 'Chọn ảnh từ thiết bị',
                          ),
                        ),
                      ),
                    ),
                    StreamBuilder<List<String>>(
                      stream: FirebaseData.watchGenres(),
                      builder: (context, snapshot) {
                        final genres = snapshot.data ?? const <String>[];
                        return DropdownButtonFormField<String>(
                          key: ValueKey('genre-${genres.join('|')}-$category'),
                          initialValue: genres.contains(category)
                              ? category
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Thể loại',
                            border: const OutlineInputBorder(),
                            helperText: genres.isEmpty
                                ? 'Hãy tạo thẻ trong tab Thể loại trước.'
                                : null,
                          ),
                          items: genres
                              .map(
                                (genre) => DropdownMenuItem(
                                  value: genre,
                                  child: Text(genre),
                                ),
                              )
                              .toList(),
                          onChanged: genres.isEmpty
                              ? null
                              : (value) =>
                                    setDialogState(() => category = value),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Chọn một thể loại'
                              : null,
                        );
                      },
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey('status-$status'),
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Đang ra',
                          child: Text('Đang ra'),
                        ),
                        DropdownMenuItem(
                          value: 'Hoàn thành',
                          child: Text('Hoàn thành'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value),
                    ),
                    _formField(description, 'Giới thiệu', maxLines: 4),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (coverBusy) return;
                if (!key.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  Novel(
                    id: novelId,
                    title: title.text.trim(),
                    author: author.text.trim(),
                    coverUrl: cover.text.trim(),
                    category: category ?? '',
                    description: description.text.trim(),
                    rating: novel?.rating ?? 0,
                    status: status ?? 'Đang ra',
                    viewCount: novel?.viewCount ?? 0,
                    dailyViews: novel?.dailyViews ?? const {},
                    weeklyViews: novel?.weeklyViews ?? const {},
                    monthlyViews: novel?.monthlyViews ?? const {},
                    chapters: novel?.chapters ?? const [],
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu truyện'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    try {
      await FirebaseData.saveNovel(result);
      if (context.mounted) _message(context, 'Đã lưu “${result.title}”.');
    } catch (error) {
      if (context.mounted)
        _message(context, 'Không lưu được truyện: $error', error: true);
    }
  }

  Future<void> _addChapter(BuildContext context, Novel novel) async {
    final key = GlobalKey<FormState>();
    final title = TextEditingController();
    final content = TextEditingController();
    final nextNumber =
        novel.chapters.fold<int>(
          0,
          (highest, chapter) =>
              chapter.chapterNumber > highest ? chapter.chapterNumber : highest,
        ) +
        1;
    final chapter = await showDialog<ChapterContent>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Thêm chương cho “${novel.title}”'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: '$nextNumber',
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Số chương'),
                ),
                const SizedBox(height: 12),
                _formField(title, 'Tên chương'),
                _formField(content, 'Nội dung', maxLines: 8),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!key.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                ChapterContent(
                  chapterNumber: nextNumber,
                  title: title.text.trim(),
                  content: content.text.trim(),
                ),
              );
            },
            child: const Text('Thêm chương'),
          ),
        ],
      ),
    );
    if (chapter == null) return;
    try {
      await FirebaseData.saveNovel(
        Novel(
          id: novel.id,
          title: novel.title,
          author: novel.author,
          coverUrl: novel.coverUrl,
          category: novel.category,
          description: novel.description,
          rating: novel.rating,
          status: novel.status,
          viewCount: novel.viewCount,
          dailyViews: novel.dailyViews,
          weeklyViews: novel.weeklyViews,
          monthlyViews: novel.monthlyViews,
          chapters: [...novel.chapters, chapter],
        ),
      );
      if (context.mounted)
        _message(context, 'Đã thêm chương ${chapter.chapterNumber}.');
    } catch (error) {
      if (context.mounted)
        _message(context, 'Không lưu được chương: $error', error: true);
    }
  }

  Future<void> _deleteNovel(BuildContext context, Novel novel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa truyện?'),
        content: Text(
          '“${novel.title}” và danh sách chương sẽ bị xóa khỏi Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa truyện'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseData.deleteNovel(novel.id);
      if (context.mounted) _message(context, 'Đã xóa truyện.');
    } catch (error) {
      if (context.mounted)
        _message(context, 'Không xóa được truyện: $error', error: true);
    }
  }

  Future<void> _seedSamples(BuildContext context) async {
    try {
      for (final genre in SampleCatalog.genres) {
        await FirebaseData.saveGenre(genre);
      }
      for (final sample in SampleCatalog.novels) {
        await FirebaseData.saveNovel(
          Novel(
            id: sample.id,
            title: sample.title,
            author: sample.author,
            coverUrl: sample.coverUrl,
            category: sample.category,
            description: sample.description,
            rating: sample.rating,
            status: sample.status,
            viewCount: sample.viewCount,
            dailyViews: sample.dailyViews,
            weeklyViews: sample.weeklyViews,
            monthlyViews: sample.monthlyViews,
            chapters: sample.chapters,
          ),
        );
      }
      if (context.mounted)
        _message(
          context,
          'Đã lưu 6 truyện mẫu, mỗi truyện 10 chương, và ${SampleCatalog.genres.length} thể loại vào Firebase.',
        );
    } catch (error) {
      if (context.mounted)
        _message(context, 'Không nạp được dữ liệu mẫu: $error', error: true);
    }
  }

  static Widget _formField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Vui lòng nhập $label' : null,
    ),
  );

  static void _message(
    BuildContext context,
    String text, {
    bool error = false,
  }) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red.shade700 : null,
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kho truyện',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Thêm, cập nhật nội dung và chương',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _editNovel(context),
              icon: const Icon(Icons.add),
              label: const Text('Thêm truyện'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<List<Novel>>(
          stream: FirebaseData.watchNovels(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                child: Text('Không tải được truyện: ${snapshot.error}'),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty)
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _EmptyState(
                        icon: Icons.auto_stories_outlined,
                        title: 'Kho truyện đang trống',
                        detail: 'Thêm truyện mới hoặc nạp 6 bộ mẫu có bìa, mỗi bộ có 10 chương.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _seedSamples(context),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Nạp 6 truyện mẫu'),
                      ),
                    ],
                  ),
                ),
              );
            return ListView.separated(
              padding: const EdgeInsets.all(18),
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final novel = snapshot.data![index];
                return Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: novel.coverUrl.isEmpty
                              ? Container(
                                  width: 66,
                                  height: 90,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Icon(
                                    Icons.book_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                )
                              : SizedBox(
                                  width: 66,
                                  height: 90,
                                  child: NovelCover(url: novel.coverUrl),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                novel.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${novel.author}  ·  ${novel.category}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _InfoPill(
                                    icon: Icons.menu_book_outlined,
                                    label: '${novel.chapters.length} chương',
                                  ),
                                  _InfoPill(
                                    icon: Icons.star_outline,
                                    label: novel.rating.toStringAsFixed(1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'chapter')
                              _addChapter(context, novel);
                            if (action == 'edit')
                              _editNovel(context, novel: novel);
                            if (action == 'delete')
                              _deleteNovel(context, novel);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'chapter',
                              child: ListTile(
                                leading: Icon(Icons.post_add),
                                title: Text('Thêm chương'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Sửa truyện'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                title: Text('Xóa truyện'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.deepOrange),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.deepOrange.shade300),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
