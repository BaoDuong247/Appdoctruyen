import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firebase_data.dart';

class AdminAnnouncementsTab extends StatefulWidget {
  const AdminAnnouncementsTab({super.key});

  @override
  State<AdminAnnouncementsTab> createState() => _AdminAnnouncementsTabState();
}

class _AdminAnnouncementsTabState extends State<AdminAnnouncementsTab> {
  Future<void> _editAnnouncement([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title'] as String? ?? '');
    final message = TextEditingController(
      text: item?['message'] as String? ?? '',
    );
    final imageUrl = TextEditingController(
      text: item?['imageUrl'] as String? ?? '',
    );
    XFile? selectedImage;
    var active = item?['active'] as bool? ?? true;
    var important = item?['important'] as bool? ?? false;
    var pickingImage = false;
    var saving = false;
    var closingAfterSave = false;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Tạo thông báo' : 'Chỉnh sửa thông báo'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: title,
                      maxLength: 90,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập tiêu đề'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: message,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung hiển thị',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Vui lòng nhập nội dung'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: imageUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Đường dẫn ảnh (hoặc chọn ảnh bên dưới)',
                        hintText: 'https://…',
                        prefixIcon: Icon(Icons.link_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: pickingImage
                          ? null
                          : () async {
                              setDialogState(() => pickingImage = true);
                              try {
                                final file = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 88,
                                  maxWidth: 1800,
                                );
                                if (file != null) {
                                  selectedImage = file;
                                  setDialogState(() {});
                                }
                              } finally {
                                if (dialogContext.mounted) {
                                  setDialogState(() => pickingImage = false);
                                }
                              }
                            },
                      icon: pickingImage
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        selectedImage == null
                            ? 'Chọn ảnh từ thiết bị'
                            : 'Đã chọn: ${selectedImage!.name}',
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (selectedImage != null)
                      FutureBuilder<List<int>>(
                        future: selectedImage!.readAsBytes(),
                        builder: (context, snapshot) => snapshot.hasData
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  Uint8List.fromList(snapshot.data!),
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const SizedBox(
                                height: 100,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                      )
                    else if (imageUrl.text.trim().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          imageUrl.text.trim(),
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 60,
                            child: Center(
                              child: Text('Không tải được ảnh xem trước'),
                            ),
                          ),
                        ),
                      ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hiển thị cho người dùng'),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.redAccent,
                      ),
                      title: const Text('Thông Báo Quan Trọng'),
                      subtitle: const Text(
                        'Chạy dòng chữ đỏ trên trang người dùng 3 lần',
                      ),
                      value: important,
                      onChanged: (value) =>
                          setDialogState(() => important = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await FirebaseData.saveAnnouncement(
                          id: item?['id'] as String?,
                          title: title.text,
                          message: message.text,
                          imageUrl: selectedImage == null
                              ? imageUrl.text
                              : null,
                          imageBytes: selectedImage == null
                              ? null
                              : await selectedImage!.readAsBytes(),
                          fileName: selectedImage?.name,
                          active: active,
                          important: important,
                        );
                        if (dialogContext.mounted) {
                          closingAfterSave = true;
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Đã lưu thông báo.')),
                          );
                        }
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Không lưu được: $error')),
                          );
                        }
                      } finally {
                        if (dialogContext.mounted && !closingAfterSave) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu thông báo'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    message.dispose();
    imageUrl.dispose();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thông báo?'),
        content: Text('“${item['title'] ?? 'Thông báo'}” sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirebaseData.deleteAnnouncement(item);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Không xóa được: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông báo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text('Gửi nội dung và ảnh đến mục Thông báo của độc giả.'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _editAnnouncement(),
              icon: const Icon(Icons.add),
              label: const Text('Tạo thông báo'),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FirebaseData.watchAllAnnouncements(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Không tải được thông báo: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'Chưa có thông báo. Tạo thông báo đầu tiên để độc giả nhìn thấy.',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = snapshot.data![index];
                final image = item['imageUrl'] as String? ?? '';
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: image.isEmpty
                        ? const CircleAvatar(
                            child: Icon(Icons.campaign_outlined),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              image,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                width: 72,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['title'] as String? ?? 'Thông báo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (item['important'] == true)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Chip(
                              avatar: Icon(
                                Icons.campaign_rounded,
                                size: 15,
                                color: Colors.redAccent,
                              ),
                              label: Text('Quan trọng'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        Chip(
                          label: Text(
                            item['active'] == true ? 'Đang hiện' : 'Đã ẩn',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      item['message'] as String? ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Chỉnh sửa',
                          onPressed: () => _editAnnouncement(item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Xóa',
                          onPressed: () => _delete(item),
                          icon: const Icon(Icons.delete_outline),
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
