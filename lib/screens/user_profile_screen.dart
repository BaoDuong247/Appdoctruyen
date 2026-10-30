import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/firebase_data.dart';
import '../widgets/app_backdrop.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _photoBusy = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await FirebaseData.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _name.text = profile?.displayName ?? '';
        _phone.text = profile?.phone ?? '';
        _notificationsEnabled = profile?.notificationsEnabled ?? true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Không tải được hồ sơ: $error', error: true);
    }
  }

  Future<void> _save() async {
    if (_saving || _photoBusy) return;
    setState(() => _saving = true);
    try {
      await FirebaseData.saveMyProfile(
        displayName: _name.text,
        phone: _phone.text,
      );
      await FirebaseData.auth.currentUser?.updateDisplayName(_name.text.trim());
      if (mounted) _message('Đã cập nhật hồ sơ.');
    } catch (error) {
      if (mounted) _message('Không lưu được hồ sơ: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_photoBusy || _saving) return;
    final user = FirebaseData.auth.currentUser;
    if (user == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1400,
      );
      if (image == null) return;
      setState(() => _photoBusy = true);
      final url = await FirebaseData.uploadAvatar(
        uid: user.uid,
        bytes: await image.readAsBytes(),
        fileName: image.name,
      );
      await FirebaseData.saveMyProfile(
        displayName: _name.text,
        phone: _phone.text,
        avatarUrl: url,
      );
      final profile = _profile;
      if (mounted && profile != null) {
        setState(() {
          _profile = UserProfile(
            uid: profile.uid,
            email: profile.email,
            displayName: _name.text.trim(),
            phone: _phone.text.trim(),
            avatarUrl: url,
            role: profile.role,
            createdAt: profile.createdAt,
            notificationsEnabled: profile.notificationsEnabled,
          );
        });
      }
      if (mounted) _message('Đã cập nhật ảnh đại diện.');
    } catch (error) {
      if (mounted)
        _message(
          'Không hoàn tất cập nhật ảnh đại diện: $error',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = FirebaseData.auth.currentUser;
    if (user == null || _profile?.avatarUrl.isEmpty != false) return;
    try {
      await FirebaseData.deleteAvatar(user.uid);
      await _load();
      if (mounted) _message('Đã xóa ảnh đại diện.');
    } catch (error) {
      if (mounted) _message('Không xóa được ảnh: $error', error: true);
    }
  }

  Future<void> _changePassword() async {
    final key = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Nhập mật khẩu hiện tại'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? 'Mật khẩu cần tối thiểu 6 ký tự'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu mới',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value != next.text ? 'Mật khẩu chưa khớp' : null,
                ),
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
              if (key.currentState!.validate())
                Navigator.pop(dialogContext, [current.text, next.text]);
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
    if (values == null) {
      current.dispose();
      next.dispose();
      confirm.dispose();
      return;
    }
    try {
      await FirebaseData.changePassword(
        currentPassword: values[0],
        newPassword: values[1],
      );
      if (mounted) _message('Đã đổi mật khẩu.');
    } on FirebaseAuthException catch (error) {
      if (mounted)
        _message(
          error.code == 'wrong-password' || error.code == 'invalid-credential'
              ? 'Mật khẩu hiện tại không đúng.'
              : 'Không đổi được mật khẩu: ${error.message}',
          error: true,
        );
    } catch (error) {
      if (mounted) _message('Không đổi được mật khẩu: $error', error: true);
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
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
    if (_loading)
      return const Scaffold(
        body: AppBackdrop(child: Center(child: CircularProgressIndicator())),
      );
    final profile = _profile;
    final avatarUrl = profile?.avatarUrl ?? '';
    final role = profile?.role == 'admin'
        ? 'Quản trị viên'
        : profile?.role == 'vip'
        ? 'VIP'
        : 'Người dùng';
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ của tôi')),
      body: AppBackdrop(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 54,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              backgroundImage: avatarUrl.isEmpty
                                  ? null
                                  : NetworkImage(avatarUrl),
                              child: _photoBusy
                                  ? const SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : avatarUrl.isEmpty
                                  ? Icon(
                                      Icons.person_outline_rounded,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    )
                                  : null,
                            ),
                            if (!_photoBusy)
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Đổi ảnh',
                                  onPressed: _saving || _photoBusy
                                      ? null
                                      : _pickPhoto,
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          profile?.email ?? '',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                        if (avatarUrl.isNotEmpty)
                          TextButton.icon(
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Xóa ảnh đại diện'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _ProfileReadingStats(),
                const SizedBox(height: 20),
                Text(
                  'Thông tin cá nhân',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 13),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Email và vai trò tài khoản được bảo vệ, không thể chỉnh sửa tại đây.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _saving || _photoBusy ? null : _save,
                  icon: _saving || _photoBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_photoBusy ? 'Đang tải ảnh…' : 'Lưu thay đổi'),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.lock_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: const Text('Đổi mật khẩu'),
                    subtitle: const Text(
                      'Xác minh mật khẩu hiện tại trước khi cập nhật',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Cài đặt ứng dụng',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile.adaptive(
                    value: _notificationsEnabled,
                    onChanged: (value) async {
                      setState(() => _notificationsEnabled = value);
                      try {
                        await FirebaseData.setNotificationsEnabled(value);
                      } catch (error) {
                        if (!mounted) return;
                        setState(() => _notificationsEnabled = !value);
                        _message('Không lưu được cài đặt: $error', error: true);
                      }
                    },
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Thông báo cập nhật truyện'),
                    subtitle: const Text(
                      'Cho phép hiển thị thông báo trong ứng dụng',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: const Text('Xóa bộ nhớ đệm ảnh'),
                    subtitle: const Text(
                      'Làm mới ảnh bìa và ảnh đại diện đã xem',
                    ),
                    onTap: () {
                      PaintingBinding.instance.imageCache.clear();
                      PaintingBinding.instance.imageCache.clearLiveImages();
                      _message('Đã xóa bộ nhớ đệm ảnh.');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileReadingStats extends StatelessWidget {
  const _ProfileReadingStats();

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: FirebaseData.watchLibrary('readingHistory'),
    builder: (context, snapshot) {
      final entries = snapshot.data ?? const <Map<String, dynamic>>[];
      final seconds = entries.fold<int>(
        0,
        (sum, item) => sum + ((item['secondsRead'] as num?)?.toInt() ?? 0),
      );
      final completed = entries.where((item) {
        final chapterCount = ((item['chapters'] as List?) ?? const []).length;
        final current = (item['chapterNumber'] as num?)?.toInt() ?? 0;
        final progress = (item['progressPercent'] as num?)?.toDouble() ?? 0;
        return chapterCount > 0 && current >= chapterCount && progress >= .9;
      }).length;
      return Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Thời gian đọc',
              value: '${(seconds / 3600).toStringAsFixed(1)} giờ',
              icon: Icons.schedule_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Truyện hoàn thành',
              value: '$completed',
              icon: Icons.task_alt_rounded,
            ),
          ),
        ],
      );
    },
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
