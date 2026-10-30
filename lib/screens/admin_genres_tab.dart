import 'package:flutter/material.dart';

import '../data/sample_catalog.dart';
import '../services/firebase_data.dart';

class AdminGenresTab extends StatelessWidget {
  const AdminGenresTab({super.key});

  Future<void> _addGenre(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo thể loại'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Tên thể loại',
            hintText: 'Ví dụ: Trinh Thám',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Tạo thẻ'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await FirebaseData.saveGenre(name);
      if (context.mounted) _notice(context, 'Đã tạo thẻ “$name”.');
    } catch (error) {
      if (context.mounted)
        _notice(context, 'Không tạo được thể loại: $error', error: true);
    }
  }

  Future<void> _deleteGenre(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa thẻ thể loại?'),
        content: Text('Xóa “$name” khỏi danh sách thể loại?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa thẻ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseData.deleteGenre(name);
      if (context.mounted) _notice(context, 'Đã xóa thẻ “$name”.');
    } catch (error) {
      if (context.mounted)
        _notice(context, 'Không xóa được: $error', error: true);
    }
  }

  static void _notice(
    BuildContext context,
    String message, {
    bool error = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thể loại truyện',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Thẻ ở đây sẽ xuất hiện khi thêm truyện.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _addGenre(context),
              icon: const Icon(Icons.add),
              label: const Text('Tạo thẻ'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<List<String>>(
          stream: FirebaseData.watchGenres(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                child: Text('Không tải được thể loại: ${snapshot.error}'),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final names = snapshot.data!;
            if (names.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sell_outlined, size: 46),
                      const SizedBox(height: 12),
                      const Text(
                        'Chưa có thẻ thể loại',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tạo thể loại mới hoặc nạp bộ truyện mẫu để bắt đầu.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            for (final genre in SampleCatalog.genres) {
                              await FirebaseData.saveGenre(genre);
                            }
                            if (context.mounted)
                              _notice(
                                context,
                                'Đã thêm ${SampleCatalog.genres.length} thể loại gợi ý.',
                              );
                          } catch (error) {
                            if (context.mounted)
                              _notice(
                                context,
                                'Không thêm được: $error',
                                error: true,
                              );
                          }
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Thêm thẻ gợi ý'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: names.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      Icons.sell_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    names[index],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: IconButton(
                    tooltip: 'Xóa thẻ',
                    onPressed: () => _deleteGenre(context, names[index]),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
