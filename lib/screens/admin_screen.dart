import 'package:flutter/material.dart';

import '../models/novel.dart';
import '../models/user_profile.dart';
import '../services/firebase_data.dart';
import 'admin_novels_tab.dart';
import 'admin_genres_tab.dart';
import 'admin_profile_tab.dart';
import 'admin_announcements_tab.dart';
import 'admin_users_tab.dart';
import 'auth_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/tambao_logo.dart';
import '../widgets/login_petal_overlay.dart';
import '../widgets/app_backdrop.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, this.celebrateLogin = false});

  final bool celebrateLogin;

  Future<void> _signOut(BuildContext context) async {
    await FirebaseData.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 6,
    child: Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const TambaoLogo(width: 44, height: 42, radius: 11),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Điều hành',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Bảng quản trị',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppTheme.mode.value == ThemeMode.dark
                ? 'Giao diện sáng'
                : 'Giao diện tối',
            onPressed: () =>
                AppTheme.mode.value = AppTheme.mode.value == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark,
            icon: Icon(
              AppTheme.mode.value == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Đăng xuất',
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: Icon(Icons.grid_view_rounded), text: 'Tổng quan'),
            Tab(icon: Icon(Icons.library_books_outlined), text: 'Truyện'),
            Tab(icon: Icon(Icons.sell_outlined), text: 'Thể loại'),
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Người dùng'),
            Tab(icon: Icon(Icons.account_circle_outlined), text: 'Hồ sơ'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Thông báo'),
          ],
        ),
      ),
      body: Stack(
        children: [
          AppBackdrop(
            child: const TabBarView(
              children: [
                AdminOverviewTab(),
                AdminNovelsTab(),
                AdminGenresTab(),
                AdminUsersTab(),
                AdminProfileTab(),
                AdminAnnouncementsTab(),
              ],
            ),
          ),
          if (celebrateLogin) const LoginPetalOverlay(),
        ],
      ),
    ),
  );
}

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  void _openTab(BuildContext context, int index) =>
      DefaultTabController.of(context).animateTo(index);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Novel>>(
    stream: FirebaseData.watchNovels(),
    builder: (context, novelSnapshot) => StreamBuilder<List<UserProfile>>(
      stream: FirebaseData.watchUsers(),
      builder: (context, userSnapshot) {
        if (novelSnapshot.hasError || userSnapshot.hasError) {
          return Center(
            child: Text(
              'Không tải được dữ liệu quản trị. Kiểm tra Firestore Rules.\n${novelSnapshot.error ?? userSnapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        final novels = novelSnapshot.data ?? const <Novel>[];
        final users = userSnapshot.data ?? const <UserProfile>[];
        final admins = users.where((user) => user.role == 'admin').length;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2B2948),
                    Color(0xFF68507B),
                    Color(0xFFE58658),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Xin chào, quản trị viên 👋',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Mọi thứ đang trong tầm tay.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Theo dõi kho truyện và cộng đồng độc giả của bạn.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.78),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const _AnimatedAdminMark(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tổng quan dữ liệu',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (!novelSnapshot.hasData || !userSnapshot.hasData)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width > 700 ? 4 : 2;
                  final cardWidth = (width - (columns - 1) * 10) / columns;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.menu_book_rounded,
                        label: 'Truyện',
                        value: '${novels.length}',
                        color: Colors.deepOrange,
                        onTap: () => _openTab(context, 1),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.people_alt_rounded,
                        label: 'Hồ sơ',
                        value: '${users.length}',
                        color: Colors.indigo,
                        onTap: () => _openTab(context, 3),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.auto_stories_rounded,
                        label: 'Chương',
                        value:
                            '${novels.fold<int>(0, (sum, item) => sum + item.chapters.length)}',
                        color: Colors.teal,
                        onTap: () => _openTab(context, 1),
                      ),
                      _MetricCard(
                        width: cardWidth,
                        icon: Icons.verified_user_rounded,
                        label: 'Quản trị',
                        value: '$admins',
                        color: Colors.purple,
                        onTap: () => _openTab(context, 3),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 22),
            Text(
              'Truy cập nhanh',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _QuickTip(
              icon: Icons.library_add_outlined,
              title: 'Cập nhật kho truyện',
              detail: 'Thêm truyện, sửa thông tin và bổ sung chương mới.',
              onTap: () => _openTab(context, 1),
            ),
            const SizedBox(height: 8),
            _QuickTip(
              icon: Icons.manage_accounts_outlined,
              title: 'Chăm sóc hồ sơ độc giả',
              detail:
                  'Tra cứu tài khoản và cập nhật tên hiển thị, số điện thoại.',
              onTap: () => _openTab(context, 3),
            ),
            const SizedBox(height: 8),
            _QuickTip(
              icon: Icons.photo_camera_back_outlined,
              title: 'Hoàn thiện hồ sơ admin',
              detail:
                  'Thêm ảnh đại diện, thông tin liên hệ và cập nhật mật khẩu.',
              onTap: () => _openTab(context, 4),
            ),
          ],
        );
      },
    ),
  );
}

class _AnimatedAdminMark extends StatefulWidget {
  const _AnimatedAdminMark();
  @override
  State<_AnimatedAdminMark> createState() => _AnimatedAdminMarkState();
}

class _AnimatedAdminMarkState extends State<_AnimatedAdminMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => Transform.translate(
      offset: Offset(0, -4 * _controller.value),
      child: child,
    ),
    child: Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Color(0xFFFFE4B8),
        size: 35,
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
    width: width,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 13),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
    ),
  );
}

class _QuickTip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  const _QuickTip({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.deepOrange),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 12,
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
  );
}
