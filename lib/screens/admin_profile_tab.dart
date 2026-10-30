import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../models/user_profile.dart';
import '../services/firebase_data.dart';

class AdminProfileTab extends StatefulWidget {
  const AdminProfileTab({super.key});

  @override
  State<AdminProfileTab> createState() => _AdminProfileTabState();
}

class _AdminProfileTabState extends State<AdminProfileTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await FirebaseData.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _nameController.text = profile?.displayName ?? '';
        _phoneController.text = profile?.phone ?? '';
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() => _loading = false);
      if (mounted) _notify('Không tải được hồ sơ: $error', error: true);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await FirebaseData.saveMyProfile(
        displayName: _nameController.text,
        phone: _phoneController.text,
      );
      await FirebaseData.auth.currentUser?.updateDisplayName(
        _nameController.text.trim(),
      );
      await _loadProfile();
      if (mounted) _notify('Đã lưu hồ sơ của bạn.');
    } catch (error) {
      if (mounted) _notify('Không lưu được hồ sơ: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final user = FirebaseData.auth.currentUser;
    if (user == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1400,
      );
      if (image == null) return;
      setState(() => _avatarBusy = true);
      final url = await FirebaseData.uploadAvatar(
        uid: user.uid,
        bytes: await image.readAsBytes(),
        fileName: image.name,
      );
      await FirebaseData.saveMyProfile(
        displayName: _nameController.text,
        phone: _phoneController.text,
        avatarUrl: url,
      );
      await _loadProfile();
      if (mounted) _notify('Đã cập nhật ảnh đại diện.');
    } catch (error) {
      if (mounted)
        _notify(
          'Không tải được ảnh. Hãy kiểm tra Firebase Storage và Storage Rules: $error',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    final user = FirebaseData.auth.currentUser;
    if (user == null || _profile?.avatarUrl.isEmpty != false) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa ảnh đại diện?'),
        content: const Text('Ảnh hiện tại sẽ bị xóa khỏi Firebase Storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa ảnh'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _avatarBusy = true);
    try {
      await FirebaseData.deleteAvatar(user.uid);
      await _loadProfile();
      if (mounted) _notify('Đã xóa ảnh đại diện.');
    } catch (error) {
      if (mounted) _notify('Không xóa được ảnh đại diện: $error', error: true);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
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
          width: 440,
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
                      value != next.text ? 'Mật khẩu nhập lại chưa khớp' : null,
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
            child: const Text('Cập nhật mật khẩu'),
          ),
        ],
      ),
    );
    if (values == null) return;
    try {
      await FirebaseData.changePassword(
        currentPassword: values[0],
        newPassword: values[1],
      );
      if (mounted) _notify('Đã đổi mật khẩu.');
    } on FirebaseAuthException catch (error) {
      if (mounted)
        _notify(
          error.code == 'wrong-password' || error.code == 'invalid-credential'
              ? 'Mật khẩu hiện tại không đúng.'
              : 'Không đổi được mật khẩu: ${error.message}',
          error: true,
        );
    } catch (error) {
      if (mounted) _notify('Không đổi được mật khẩu: $error', error: true);
    }
  }

  void _notify(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final profile = _profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text(
          'Hồ sơ quản trị',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Cập nhật thông tin tài khoản và bảo vệ quyền truy cập.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF292344), Color(0xFF593A62), Color(0xFFD47653)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 43,
                    backgroundColor: Colors.white24,
                    backgroundImage: profile?.avatarUrl.isNotEmpty == true
                        ? NetworkImage(profile!.avatarUrl)
                        : null,
                    child: _avatarBusy
                        ? const SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : profile?.avatarUrl.isNotEmpty == true
                        ? null
                        : const Icon(
                            Icons.person_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                  ),
                  if (!_avatarBusy)
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.white,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: 'Đổi ảnh',
                        onPressed: _pickAvatar,
                        icon: const Icon(
                          Icons.edit,
                          size: 15,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.displayName.isNotEmpty == true
                          ? profile!.displayName
                          : 'Quản trị viên',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.email ??
                          FirebaseData.auth.currentUser?.email ??
                          '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          letterSpacing: 1.2,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (profile?.avatarUrl.isNotEmpty == true)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _removeAvatar,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Xóa ảnh đại diện'),
            ),
          ),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Thông tin cá nhân', Icons.badge_outlined),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Tên hiển thị',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _saveProfile,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Lưu hồ sơ'),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'Bảo mật', Icons.shield_outlined),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: Colors.deepOrange,
              ),
            ),
            title: const Text(
              'Đổi mật khẩu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Xác minh mật khẩu hiện tại trước khi cập nhật',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePassword,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String label, IconData icon) =>
      Row(
        children: [
          Icon(icon, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      );
}
