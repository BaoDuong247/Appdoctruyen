import 'dart:async';

import 'package:flutter/material.dart';

import '../data/sample_catalog.dart';
import '../models/novel.dart';
import '../models/user_profile.dart';
import '../services/firebase_data.dart';
import '../theme/app_theme.dart';
import '../widgets/novel_cover.dart';
import '../widgets/tambao_logo.dart';
import '../widgets/login_petal_overlay.dart';
import '../widgets/important_announcement_ticker.dart';
import 'auth_screen.dart';
import 'detail_screen.dart';
import 'explore_screen.dart';
import 'library_screen.dart';
import 'user_profile_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.celebrateLogin = false});

  final bool celebrateLogin;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _category;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  late PageController _featuredController;
  Timer? _featuredTimer;
  double _featuredFraction = .36;
  int _featuredCount = 0;
  int _featuredPage = 10000;
  int _selectedTab = 0;
  String _rankPeriod = 'day';
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _featuredController = PageController(
      viewportFraction: _featuredFraction,
      initialPage: _featuredPage,
    );
    _profileFuture = FirebaseData.getMyProfile();
    _featuredTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _moveFeatured(1),
    );
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _featuredController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeSearch(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàảãạăắằẳẵặâấầẩẫậ]'), 'a')
      .replaceAll(RegExp('[éèẻẽẹêếềểễệ]'), 'e')
      .replaceAll(RegExp('[íìỉĩị]'), 'i')
      .replaceAll(RegExp('[óòỏõọôốồổỗộơớờởỡợ]'), 'o')
      .replaceAll(RegExp('[úùủũụưứừửữự]'), 'u')
      .replaceAll(RegExp('[ýỳỷỹỵ]'), 'y')
      .replaceAll('đ', 'd');

  void _setFeaturedFraction(double fraction) {
    if ((fraction - _featuredFraction).abs() < .001) return;
    final oldController = _featuredController;
    final page = oldController.hasClients
        ? oldController.page?.round() ?? _featuredPage
        : _featuredPage;
    _featuredPage = page;
    _featuredFraction = fraction;
    _featuredController = PageController(
      viewportFraction: fraction,
      initialPage: page,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => oldController.dispose(),
    );
  }

  void _moveFeatured(int delta) {
    if (!_featuredController.hasClients || _featuredCount < 2) return;
    final current = _featuredController.page?.round() ?? 0;
    final next = current + delta;
    _featuredPage = next;
    _featuredController.animateToPage(
      next,
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOutCubic,
    );
  }

  String _periodKey(DateTime date, String period) {
    String day(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
    if (period == 'day') return day(date);
    if (period == 'week')
      return day(date.subtract(Duration(days: date.weekday - 1)));
    return '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}';
  }

  int _rankViews(Novel novel) {
    final views = _rankPeriod == 'day'
        ? novel.dailyViews
        : _rankPeriod == 'week'
        ? novel.weeklyViews
        : novel.monthlyViews;
    if (views.isEmpty) return novel.viewCount;
    return views[_periodKey(DateTime.now(), _rankPeriod)] ?? 0;
  }

  Future<void> _signOut() async {
    await FirebaseData.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xFF17131E),
                          Color(0xFF211722),
                          Color(0xFF191724),
                        ]
                      : const [
                          Color(0xFFF6ECFF),
                          Color(0xFFFFF0F3),
                          Color(0xFFF3E9FF),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -110,
            child: _BackdropOrb(
              size: 260,
              color: isDark ? const Color(0x263E2D55) : const Color(0x267F4CC3),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -100,
            child: _BackdropOrb(
              size: 230,
              color: isDark ? const Color(0x263D2636) : const Color(0x20E58CAC),
            ),
          ),
          IndexedStack(
            index: _selectedTab,
            children: [
              _homeContent(),
              const LibraryScreen(),
              const ExploreScreen(),
              const UserProfileScreen(),
            ],
          ),
          if (widget.celebrateLogin) const LoginPetalOverlay(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() {
          _selectedTab = index;
          if (index == 0) _profileFuture = FirebaseData.getMyProfile();
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmarks_rounded),
            label: 'Tủ sách',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  Widget _homeContent() => StreamBuilder<List<Novel>>(
    stream: FirebaseData.watchNovels(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Không tải được truyện: ${snapshot.error}'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final isDemo = snapshot.data!.isEmpty;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final allNovels = isDemo ? SampleCatalog.novels : snapshot.data!;
      return StreamBuilder<List<String>>(
        stream: FirebaseData.watchGenres(),
        builder: (context, genreSnapshot) {
          final dynamicGenres = genreSnapshot.data ?? const <String>[];
          final categories = dynamicGenres.isEmpty
              ? SampleCatalog.genres
              : dynamicGenres;
          final query = _normalizeSearch(_query.trim());
          final novels = allNovels
              .where(
                (novel) =>
                    (_category == null || novel.category == _category) &&
                    (query.isEmpty ||
                        _normalizeSearch(novel.title).contains(query) ||
                        _normalizeSearch(novel.author).contains(query) ||
                        _normalizeSearch(novel.category).contains(query)),
              )
              .toList();
          // Genre chips drive every home recommendation/list so the chosen
          // category produces an immediate, consistent set of results.
          final featured = allNovels;
          _featuredCount = featured.length;
          final recentNovels = novels.toList()
            ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
          final rankedNovels = novels.toList()
            ..sort((a, b) => _rankViews(b).compareTo(_rankViews(a)));
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 88,
                backgroundColor: isDark
                    ? const Color(0xFF4A2C5E)
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(
                    start: 24,
                    bottom: 14,
                  ),
                  title: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TambaoLogo(width: 42, height: 40, radius: 10),
                      SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          'Thế Giới Truyện',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  background: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? const [Color(0xFF382447), Color(0xFF68405F)]
                            : [
                                Theme.of(context).colorScheme.primary,
                                const Color(0xFFE7934A),
                              ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: AppTheme.mode.value == ThemeMode.dark
                        ? 'Chuyển sang giao diện sáng'
                        : 'Chuyển sang giao diện tối',
                    onPressed: () => AppTheme.mode.value =
                        AppTheme.mode.value == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                    icon: Icon(
                      AppTheme.mode.value == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseData.watchUnreadNotifications(),
                    builder: (context, notificationSnapshot) {
                      final count = notificationSnapshot.data?.length ?? 0;
                      final label = count > 99 ? '99+' : '$count';
                      return IconButton(
                        tooltip: count == 0
                            ? 'Thông báo'
                            : '$count thông báo chưa đọc',
                        onPressed: () {
                          final unread = notificationSnapshot.data ?? const [];
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                          unawaited(
                            FirebaseData.markNotificationsRead(
                              unread
                                  .map((item) => item['id'] as String)
                                  .toList(),
                            ).catchError((Object error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Không cập nhật được trạng thái đã đọc: $error',
                                    ),
                                  ),
                                );
                              }
                            }),
                          );
                        },
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none_rounded),
                            if (count > 0)
                              Positioned(
                                top: -7,
                                right: -8,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 17,
                                    minHeight: 17,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF3B45),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  FutureBuilder<UserProfile?>(
                    future: _profileFuture,
                    builder: (context, profileSnapshot) {
                      final url = profileSnapshot.data?.avatarUrl ?? '';
                      return IconButton(
                        tooltip: 'Hồ sơ của tôi',
                        onPressed: () => setState(() => _selectedTab = 3),
                        icon: CircleAvatar(
                          radius: 17,
                          backgroundColor: Colors.white.withValues(alpha: .2),
                          backgroundImage: url.isEmpty
                              ? null
                              : NetworkImage(url),
                          child: url.isEmpty
                              ? const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Đăng xuất',
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SliverToBoxAdapter(child: ImportantAnnouncementTicker()),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1160),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TÌM KHOẢNH KHẮC CỦA BẠN',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.7,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Một câu chuyện hay\nđang chờ bạn mở ra.',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.13,
                                  letterSpacing: -.6,
                                ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onChanged: (value) => setState(() {
                              _query = value;
                              if (value.trim().isNotEmpty) _category = null;
                            }),
                            onSubmitted: (value) {
                              setState(() => _query = value);
                              FocusScope.of(context).unfocus();
                            },
                            decoration: InputDecoration(
                              hintText: 'Tìm truyện, tác giả hoặc thể loại…',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Xóa tìm kiếm',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                ),
                              ),
                            ),
                          ),
                          if (isDemo && query.isEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'Đang xem 6 bộ truyện mẫu. Admin có thể lưu chúng vào Firebase từ mục Truyện.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (query.isEmpty) ...[
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: _SectionTitle(
                                    title: 'Được tuyển chọn',
                                    trailing: isDemo
                                        ? 'MẪU ĐỌC THỬ'
                                        : 'MỚI CẬP NHẬT',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  tooltip: 'Truyện trước',
                                  onPressed: () => _moveFeatured(-1),
                                  icon: const Icon(Icons.chevron_left_rounded),
                                ),
                                IconButton.filledTonal(
                                  tooltip: 'Truyện tiếp theo',
                                  onPressed: () => _moveFeatured(1),
                                  icon: const Icon(Icons.chevron_right_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 13),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final fraction = constraints.maxWidth < 520
                                    ? .88
                                    : constraints.maxWidth < 860
                                    ? .56
                                    : .36;
                                _setFeaturedFraction(fraction);
                                return SizedBox(
                                  height: 222,
                                  child: PageView.builder(
                                    controller: _featuredController,
                                    padEnds: false,
                                    onPageChanged: (page) =>
                                        _featuredPage = page,
                                    itemBuilder: (context, index) {
                                      final novel =
                                          featured[index % featured.length];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 14,
                                        ),
                                        child: _FeaturedCard(
                                          novel: novel,
                                          onTap: () => _openNovel(novel),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 30),
                            _SectionTitle(
                              title: 'Khám phá thể loại',
                              trailing: '${categories.length} THẺ',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 9,
                              runSpacing: 9,
                              children: [
                                _GenreChip(
                                  label: 'Tất cả',
                                  selected: _category == null,
                                  onTap: () => setState(() => _category = null),
                                ),
                                ...categories.map(
                                  (genre) => _GenreChip(
                                    label: genre,
                                    selected: _category == genre,
                                    onTap: () =>
                                        setState(() => _category = genre),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            const _SectionTitle(
                              title: 'Truyện mới cập nhật',
                              trailing: 'VỪA LÊN KỆ',
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: recentNovels.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 9),
                                itemBuilder: (context, index) => _UpdateCard(
                                  novel: recentNovels[index],
                                  label: 'Mới',
                                  onTap: () => _openNovel(recentNovels[index]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                const Expanded(
                                  child: _SectionTitle(
                                    title: 'Truyện xem nhiều',
                                    trailing: 'TOP ĐỌC',
                                  ),
                                ),
                                SegmentedButton<String>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: 'day',
                                      label: Text('Ngày'),
                                    ),
                                    ButtonSegment(
                                      value: 'week',
                                      label: Text('Tuần'),
                                    ),
                                    ButtonSegment(
                                      value: 'month',
                                      label: Text('Tháng'),
                                    ),
                                  ],
                                  selected: {_rankPeriod},
                                  onSelectionChanged: (value) =>
                                      setState(() => _rankPeriod = value.first),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: rankedNovels.take(5).length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 9),
                                itemBuilder: (context, index) => _UpdateCard(
                                  novel: rankedNovels[index],
                                  label:
                                      '#${index + 1} · ${_rankViews(rankedNovels[index])}',
                                  onTap: () => _openNovel(rankedNovels[index]),
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            _PersonalizedSection(
                              novels: novels,
                              onOpen: _openNovel,
                            ),
                            const SizedBox(height: 30),
                          ],
                          _SectionTitle(
                            title: query.isNotEmpty
                                ? 'Kết quả tìm kiếm'
                                : _category == null
                                ? 'Danh sách truyện'
                                : 'Truyện thể loại $_category',
                            trailing: '${novels.length} TRUYỆN',
                          ),
                          const SizedBox(height: 14),
                          if (novels.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 38),
                              child: Center(
                                child: Text(
                                  'Chưa có truyện phù hợp với lựa chọn này.',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = constraints.maxWidth >= 980
                                    ? 4
                                    : constraints.maxWidth >= 700
                                    ? 3
                                    : constraints.maxWidth >= 460
                                    ? 2
                                    : 1;
                                final ratio = columns == 1 ? 2.6 : .67;
                                return GridView.builder(
                                  itemCount: novels.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                        childAspectRatio: ratio,
                                      ),
                                  itemBuilder: (context, index) => _NovelCard(
                                    novel: novels[index],
                                    onTap: () => _openNovel(novels[index]),
                                    compact: columns == 1,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  void _openNovel(Novel novel) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => DetailScreen(novel: novel)),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.3),
        ),
      ),
      Text(
        trailing,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.novel,
    required this.label,
    required this.onTap,
  });
  final Novel novel;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 78,
                  child: NovelCover(url: novel.coverUrl),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      novel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${novel.chapters.length} chương · ${novel.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PersonalizedSection extends StatelessWidget {
  const _PersonalizedSection({required this.novels, required this.onOpen});
  final List<Novel> novels;
  final ValueChanged<Novel> onOpen;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseData.watchLibrary('readingHistory'),
        builder: (context, snapshot) {
          final history = snapshot.data ?? const <Map<String, dynamic>>[];
          final categories = <String, int>{};
          for (final entry in history) {
            final category = entry['category'] as String? ?? '';
            if (category.isNotEmpty)
              categories[category] = (categories[category] ?? 0) + 1;
          }
          final preferred = categories.entries.isEmpty
              ? null
              : categories.entries
                    .reduce((a, b) => a.value >= b.value ? a : b)
                    .key;
          final readIds = history.map((entry) => entry['novelId']).toSet();
          final recommended =
              novels.where((novel) => !readIds.contains(novel.id)).toList()
                ..sort((a, b) {
                  final categoryOrder = (b.category == preferred ? 1 : 0)
                      .compareTo(a.category == preferred ? 1 : 0);
                  return categoryOrder != 0
                      ? categoryOrder
                      : b.rating.compareTo(a.rating);
                });
          final items = recommended.isEmpty ? novels.toList() : recommended;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: 'Gợi ý cho bạn',
                trailing: preferred ?? 'THEO ĐÁNH GIÁ',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 188,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: 270,
                    child: _FeaturedCard(
                      novel: items[index],
                      onTap: () => onOpen(items[index]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.novel, required this.onTap});
  final Novel novel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          NovelCover(url: novel.coverUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0xD9000000)],
                begin: Alignment.center,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            left: 15,
            right: 15,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    novel.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  novel.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${novel.author}  ·  ★ ${novel.rating.toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    labelStyle: TextStyle(
      fontWeight: FontWeight.w700,
      color: selected ? Theme.of(context).colorScheme.onPrimary : null,
    ),
    backgroundColor: Theme.of(context).colorScheme.surface,
    selectedColor: Theme.of(context).colorScheme.primary,
    side: BorderSide(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outlineVariant,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
  );
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({
    required this.novel,
    required this.onTap,
    this.compact = false,
  });
  final Novel novel;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: compact
          ? Row(
              children: [
                SizedBox(
                  width: 82,
                  height: 112,
                  child: NovelCover(url: novel.coverUrl),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 5,
                    ),
                    child: _NovelDetails(novel: novel),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: NovelCover(url: novel.coverUrl),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: _NovelDetails(novel: novel),
                ),
              ],
            ),
    ),
  );
}

class _NovelDetails extends StatelessWidget {
  const _NovelDetails({required this.novel});
  final Novel novel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        novel.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        novel.author,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                novel.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Spacer(),
          Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 15),
          Text(
            novel.rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ],
  );
}
