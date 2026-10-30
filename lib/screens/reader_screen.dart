import 'dart:async';

import 'package:flutter/material.dart';

import '../models/novel.dart';
import '../services/firebase_data.dart';
import '../theme/app_theme.dart';
import '../widgets/novel_cover.dart';

enum ReaderPalette { cream, sepia, night }

class ReaderScreen extends StatefulWidget {
  final Novel? novel;
  final String novelTitle;
  final String coverUrl;
  final ChapterContent? chapter;
  final List<ChapterContent> chapters;
  final double initialProgress;

  const ReaderScreen({
    super.key,
    this.novel,
    required this.novelTitle,
    this.coverUrl = '',
    this.chapter,
    this.chapters = const [],
    this.initialProgress = 0,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;
  final ScrollController _scrollController = ScrollController();
  late int _chapterIndex;
  double _fontSize = 19;
  double _lineHeight = 1.85;
  double _readingProgress = 0;
  String _fontFamily = 'Georgia';
  ReaderPalette _palette = ReaderPalette.cream;
  Timer? _progressTimer;
  DateTime _lastCheckpoint = DateTime.now();

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.chapters.indexWhere(
      (item) => item.chapterNumber == widget.chapter?.chapterNumber,
    );
    if (_chapterIndex < 0) _chapterIndex = 0;
    _readingProgress = widget.initialProgress.clamp(0.0, 1.0);
    _palette = AppTheme.mode.value == ThemeMode.dark
        ? ReaderPalette.night
        : ReaderPalette.cream;
    _scrollController.addListener(_onScroll);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _jumpToProgress(_readingProgress),
    );
    _progressTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _saveProgress(),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _saveProgress();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  ChapterContent? get _chapter => widget.chapters.isNotEmpty
      ? widget.chapters[_chapterIndex]
      : widget.chapter;
  Color get _pageColor => switch (_palette) {
    ReaderPalette.cream => const Color(0xFFFFFCF5),
    ReaderPalette.sepia => const Color(0xFFF2E6CE),
    ReaderPalette.night => const Color(0xFF171925),
  };
  Color get _textColor => _palette == ReaderPalette.night
      ? const Color(0xFFE9E6F0)
      : const Color(0xFF342F2B);

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final extent = _scrollController.position.maxScrollExtent;
    final progress = extent <= 0
        ? 0.0
        : (_scrollController.offset / extent).clamp(0.0, 1.0);
    if ((progress - _readingProgress).abs() > .012 && mounted)
      setState(() => _readingProgress = progress);
  }

  void _jumpToProgress(double progress) {
    if (!_scrollController.hasClients) return;
    final extent = _scrollController.position.maxScrollExtent;
    if (extent > 0) _scrollController.jumpTo(extent * progress.clamp(0.0, 1.0));
  }

  Future<void> _saveProgress() async {
    final novel = widget.novel;
    final chapter = _chapter;
    if (novel == null || chapter == null) return;
    final now = DateTime.now();
    final seconds = now.difference(_lastCheckpoint).inSeconds.clamp(0, 90);
    _lastCheckpoint = now;
    try {
      await FirebaseData.saveReadingProgress(
        novel: novel,
        chapterNumber: chapter.chapterNumber,
        progress: _readingProgress,
        secondsRead: seconds,
      );
    } catch (_) {}
  }

  void _moveChapter(int delta) {
    if (widget.chapters.isEmpty) return;
    final next = (_chapterIndex + delta).clamp(0, widget.chapters.length - 1);
    if (next == _chapterIndex) return;
    _saveProgress();
    setState(() {
      _chapterIndex = next;
      _readingProgress = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.hasClients ? _scrollController.jumpTo(0) : null,
    );
  }

  void _openContents() {
    if (widget.chapters.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mục lục · ${widget.novelTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.chapters.length,
                itemBuilder: (context, index) => ListTile(
                  selected: index == _chapterIndex,
                  leading: CircleAvatar(
                    radius: 17,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(
                    'Chương ${widget.chapters[index].chapterNumber}: ${widget.chapters[index].title}',
                  ),
                  trailing: index == _chapterIndex
                      ? const Icon(Icons.graphic_eq_rounded)
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (index == _chapterIndex) return;
                    _saveProgress();
                    setState(() {
                      _chapterIndex = index;
                      _readingProgress = 0;
                    });
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollController.hasClients
                          ? _scrollController.jumpTo(0)
                          : null,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookmark() async {
    final novel = widget.novel;
    final chapter = _chapter;
    if (novel == null || chapter == null) return;
    try {
      await FirebaseData.saveBookmark(
        novel: novel,
        chapterNumber: chapter.chapterNumber,
        progress: _readingProgress,
      );
      if (mounted)
        _message(
          'Đã đánh dấu chương ${chapter.chapterNumber} ở vị trí ${(_readingProgress * 100).round()}%.',
        );
    } catch (error) {
      if (mounted) _message('Đăng nhập để lưu dấu trang: $error', error: true);
    }
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tùy chỉnh trang đọc',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('Màu nền'),
                const SizedBox(height: 6),
                SegmentedButton<ReaderPalette>(
                  segments: const [
                    ButtonSegment(
                      value: ReaderPalette.cream,
                      label: Text('Sáng'),
                      icon: Icon(Icons.light_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ReaderPalette.sepia,
                      label: Text('Kem'),
                      icon: Icon(Icons.wb_sunny_outlined),
                    ),
                    ButtonSegment(
                      value: ReaderPalette.night,
                      label: Text('Tối'),
                      icon: Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                  selected: {_palette},
                  onSelectionChanged: (value) {
                    setState(() => _palette = value.first);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _fontFamily,
                  decoration: const InputDecoration(
                    labelText: 'Phông chữ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Georgia',
                      child: Text('Serif · Georgia'),
                    ),
                    DropdownMenuItem(
                      value: 'Roboto',
                      child: Text('Sans · Roboto'),
                    ),
                    DropdownMenuItem(
                      value: 'monospace',
                      child: Text('Monospace'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _fontFamily = value);
                      setSheetState(() {});
                    }
                  },
                ),
                _settingSlider('Cỡ chữ', _fontSize, 16, 28, (value) {
                  setState(() => _fontSize = value);
                  setSheetState(() {});
                }),
                _settingSlider('Khoảng cách dòng', _lineHeight, 1.4, 2.3, (
                  value,
                ) {
                  setState(() => _lineHeight = value);
                  setSheetState(() {});
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> changed,
  ) => Row(
    children: [
      SizedBox(width: 126, child: Text(label)),
      Expanded(
        child: Slider(
          min: min,
          max: max,
          divisions: 6,
          value: value,
          onChanged: changed,
        ),
      ),
      SizedBox(width: 40, child: Text(value.toStringAsFixed(1))),
    ],
  );

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    final pageCount = widget.chapters.length;
    final title = widget.novel?.title ?? widget.novelTitle;
    final cover = widget.novel?.coverUrl ?? widget.coverUrl;
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
        foregroundColor: _textColor,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Mục lục chương',
            onPressed: _openContents,
            icon: const Icon(Icons.list_alt_rounded),
          ),
          IconButton(
            tooltip: 'Đánh dấu trang',
            onPressed: _bookmark,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: 'Tùy chỉnh',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: chapter == null
          ? Center(
              child: Text(
                'Truyện chưa có chương nào.',
                style: TextStyle(color: _textColor),
              ),
            )
          : Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -120,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          (_palette == ReaderPalette.night
                                  ? const Color(0xFF55478A)
                                  : const Color(0xFFFFD9BB))
                              .withValues(alpha: .18),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _bookHeader(cover, title, chapter),
                                  const SizedBox(height: 28),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 420),
                                    switchInCurve: Curves.easeOutCubic,
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(.035, 0),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        ),
                                    child: Column(
                                      key: ValueKey(chapter.chapterNumber),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          chapter.title,
                                          style: TextStyle(
                                            fontSize: 25,
                                            height: 1.25,
                                            fontWeight: FontWeight.w800,
                                            color: _textColor,
                                            fontFamily: _fontFamily,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        for (final paragraph
                                            in chapter.content
                                                .split(RegExp(r'\n+'))
                                                .where(
                                                  (line) =>
                                                      line.trim().isNotEmpty,
                                                ))
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 17,
                                            ),
                                            child: Text(
                                              paragraph.trim(),
                                              style: TextStyle(
                                                fontSize: _fontSize,
                                                height: _lineHeight,
                                                letterSpacing: .15,
                                                color: _textColor.withValues(
                                                  alpha: .92,
                                                ),
                                                fontFamily: _fontFamily,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Icon(
                                      Icons.auto_awesome,
                                      size: 18,
                                      color: _palette == ReaderPalette.night
                                          ? Colors.deepPurple.shade200
                                          : Colors.deepOrange.shade200,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _chapterNavigation(chapter, pageCount),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _bookHeader(String cover, String title, ChapterContent chapter) =>
      Container(
        height: 176,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(
            colors: [Color(0xFF242B4A), Color(0xFF5A447E), Color(0xFFC26B5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF29233F).withValues(alpha: .2),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: child,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 92,
                  height: 136,
                  child: NovelCover(url: cover),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Chương ${chapter.chapterNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.auto_awesome, color: Color(0xFFFFD6A1), size: 22),
          ],
        ),
      );

  Widget _chapterNavigation(ChapterContent chapter, int pageCount) => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
    decoration: BoxDecoration(
      color: _pageColor,
      border: Border(top: BorderSide(color: _textColor.withValues(alpha: .08))),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _chapterIndex > 0 ? () => _moveChapter(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Chương trước',
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pageCount > 0
                        ? '${_chapterIndex + 1} / $pageCount chương'
                        : 'Chương ${chapter.chapterNumber}',
                    style: TextStyle(
                      color: _textColor.withValues(alpha: .7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (pageCount > 1)
                    LinearProgressIndicator(
                      value: (_chapterIndex + 1) / pageCount,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: _textColor.withValues(alpha: .1),
                      color: Colors.deepOrange,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _chapterIndex < pageCount - 1
                  ? () => _moveChapter(1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Tiếp'),
            ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.vertical_align_center, size: 15),
            Expanded(
              child: Slider(
                value: _readingProgress.clamp(0.0, 1.0).toDouble(),
                onChanged: (value) {
                  setState(() => _readingProgress = value);
                  _jumpToProgress(value);
                },
                onChangeEnd: (_) => _saveProgress(),
              ),
            ),
            Text(
              '${(_readingProgress * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                color: _textColor.withValues(alpha: .7),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
