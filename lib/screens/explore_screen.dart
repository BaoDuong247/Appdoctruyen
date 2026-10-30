import 'package:flutter/material.dart';

import '../data/sample_catalog.dart';
import '../models/novel.dart';
import '../services/firebase_data.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/novel_cover.dart';
import 'detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _period = 'day';

  String _key(DateTime now, String period) {
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
    if (period == 'day') return date(now);
    if (period == 'week')
      return date(now.subtract(Duration(days: now.weekday - 1)));
    return '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}';
  }

  int _views(Novel novel) {
    final now = DateTime.now();
    final key = _key(now, _period);
    final values = _period == 'day'
        ? novel.dailyViews
        : _period == 'week'
        ? novel.weeklyViews
        : novel.monthlyViews;
    return values[key] ?? novel.viewCount;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Khám phá & bảng xếp hạng',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: AppBackdrop(
      child: StreamBuilder<List<Novel>>(
        stream: FirebaseData.watchNovels(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(
              child: Text('Không tải được bảng xếp hạng: ${snapshot.error}'),
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final novels = snapshot.data!.isEmpty
              ? SampleCatalog.novels.toList()
              : snapshot.data!.toList();
          novels.sort((a, b) => _views(b).compareTo(_views(a)));
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF382447), Color(0xFF68405F)]
                        : [
                            Theme.of(context).colorScheme.primary,
                            const Color(0xFFE79A57),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ĐỌC CÙNG CỘNG ĐỒNG',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Những câu chuyện\nđang được yêu thích.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Bảng xếp hạng',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'day', label: Text('Ngày')),
                  ButtonSegment<String>(value: 'week', label: Text('Tuần')),
                  ButtonSegment<String>(value: 'month', label: Text('Tháng')),
                ],
                selected: {_period},
                onSelectionChanged: (value) =>
                    setState(() => _period = value.first),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < novels.length; index++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScreen(novel: novels[index]),
                      ),
                    ),
                    leading: SizedBox(
                      width: 48,
                      height: 64,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: NovelCover(url: novels[index].coverUrl),
                          ),
                          Align(
                            alignment: Alignment.topLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: index < 3
                                    ? Colors.deepOrange
                                    : Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      novels[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${novels[index].category}  ·  ${novels[index].author}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 16),
                        Text(
                          _views(novels[index]).toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
