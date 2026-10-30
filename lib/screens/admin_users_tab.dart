import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/firebase_data.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _editUser(UserProfile profile) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: profile.displayName);
    final phone = TextEditingController(text: profile.phone);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cập nhật hồ sơ'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.email,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await FirebaseData.updateUserProfile(
        uid: profile.uid,
        displayName: name.text,
        phone: phone.text,
      );
      if (mounted) _notify('Đã cập nhật hồ sơ người dùng.');
    } catch (error) {
      if (mounted) _notify('Không cập nhật được: $error', error: true);
    }
  }

  Future<void> _deleteUser(UserProfile profile) async {
    if (profile.role == 'admin') {
      _notify(
        'Tài khoản quản trị được bảo vệ và không thể xóa tại đây.',
        error: true,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.person_remove_alt_1_rounded,
          color: Colors.red.shade700,
        ),
        title: const Text('Xóa tài khoản người dùng?'),
        content: Text(
          'Tài khoản ${profile.email} cùng hồ sơ và ảnh đại diện sẽ bị xóa vĩnh viễn. Người dùng sẽ không thể đăng nhập lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseData.deleteUserAccount(profile.uid);
      if (mounted) _notify('Đã xóa tài khoản ${profile.email}.');
    } catch (error) {
      if (mounted) _notify('Không xóa được tài khoản: $error', error: true);
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
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Người dùng',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Tra cứu và cập nhật tên, số điện thoại hồ sơ.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email hoặc số điện thoại',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<List<UserProfile>>(
          stream: FirebaseData.watchUsers(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                child: Text('Không tải được người dùng: ${snapshot.error}'),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final users = snapshot.data!
                .where(
                  (user) =>
                      _query.isEmpty ||
                      user.email.toLowerCase().contains(_query) ||
                      user.displayName.toLowerCase().contains(_query) ||
                      user.phone.toLowerCase().contains(_query),
                )
                .toList();
            if (users.isEmpty)
              return Center(
                child: Text(
                  _query.isEmpty
                      ? 'Chưa có hồ sơ người dùng.'
                      : 'Không tìm thấy người dùng phù hợp.',
                ),
              );
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final profile = users[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: _UserAvatar(profile: profile),
                    title: Text(
                      profile.displayName.isEmpty
                          ? profile.email
                          : profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          profile.email,
                          if (profile.phone.isNotEmpty) profile.phone,
                        ].join('  ·  '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RoleBadge(role: profile.role),
                        PopupMenuButton<String>(
                          tooltip: 'Thao tác người dùng',
                          onSelected: (action) {
                            if (action == 'edit') _editUser(profile);
                            if (action == 'delete') _deleteUser(profile);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Sửa hồ sơ'),
                              ),
                            ),
                            if (profile.role != 'admin' &&
                                profile.uid !=
                                    FirebaseData.auth.currentUser?.uid)
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.person_remove_alt_1_outlined,
                                    color: Colors.red,
                                  ),
                                  title: Text('Xóa tài khoản'),
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

class _UserAvatar extends StatelessWidget {
  final UserProfile profile;
  const _UserAvatar({required this.profile});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 25,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    backgroundImage: profile.avatarUrl.isEmpty
        ? null
        : NetworkImage(profile.avatarUrl),
    child: profile.avatarUrl.isEmpty
        ? Text(
            _initials(
              profile.displayName.isEmpty ? profile.email : profile.displayName,
            ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          )
        : null,
  );
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});
  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isAdmin
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Người đọc',
        style: TextStyle(
          color: isAdmin
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSecondaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _initials(String text) {
  final parts = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  return parts.length == 1
      ? parts.first.substring(0, 1).toUpperCase()
      : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
