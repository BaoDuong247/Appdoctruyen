import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import '../models/novel.dart';
import '../models/user_profile.dart';

class FirebaseData {
  FirebaseData._();
  static final auth = FirebaseAuth.instance;
  static final firestore = FirebaseFirestore.instance;
  static final storage = FirebaseStorage.instance;
  static final novels = firestore.collection('novels');
  static final users = firestore.collection('users');
  static final genres = firestore.collection('genres');
  static final announcements = firestore.collection('announcements');

  static Stream<List<Novel>> watchNovels() => novels
      .orderBy('title')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Novel.fromMap(doc.id, doc.data()))
            .toList(),
      );

  static Future<void> saveNovel(Novel novel) async {
    final doc = novel.id.isEmpty ? novels.doc() : novels.doc(novel.id);
    await doc.set({
      ...novel.toMap(),
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteNovel(String id) => novels.doc(id).delete();

  static CollectionReference<Map<String, dynamic>> _userCollection(
    String name,
  ) {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Bạn chưa đăng nhập.');
    return users.doc(uid).collection(name);
  }

  static Stream<List<Map<String, dynamic>>> watchLibrary(String name) =>
      _userCollection(name).snapshots().map((snapshot) {
        final entries = snapshot.docs
            .map((doc) => {'novelId': doc.id, ...doc.data()})
            .toList();
        entries.sort(
          (a, b) => ((b['savedAtMs'] ?? b['lastReadAtMs'] ?? 0) as num)
              .compareTo((a['savedAtMs'] ?? a['lastReadAtMs'] ?? 0) as num),
        );
        return entries;
      });

  static Future<void> saveReadingProgress({
    required Novel novel,
    required int chapterNumber,
    required double progress,
    int secondsRead = 0,
  }) async {
    if (auth.currentUser == null) return;
    await _userCollection('readingHistory').doc(novel.id).set({
      ...novel.toMap(),
      'novelId': novel.id,
      'chapterNumber': chapterNumber,
      'progressPercent': progress.clamp(0, 1),
      'lastReadAtMs': DateTime.now().millisecondsSinceEpoch,
      'secondsRead': FieldValue.increment(secondsRead),
    }, SetOptions(merge: true));
  }

  static Future<void> setFavorite(Novel novel, bool favorite) async {
    final ref = _userCollection('favorites').doc(novel.id);
    if (!favorite) {
      await ref.delete();
      return;
    }
    await ref.set({
      ...novel.toMap(),
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> setDownloaded(Novel novel, bool downloaded) async {
    final ref = _userCollection('downloads').doc(novel.id);
    if (!downloaded) {
      await ref.delete();
      return;
    }
    await ref.set({
      ...novel.toMap(),
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> saveBookmark({
    required Novel novel,
    required int chapterNumber,
    required double progress,
  }) => _userCollection('bookmarks').doc('${novel.id}-$chapterNumber').set({
    ...novel.toMap(),
    'novelId': novel.id,
    'chapterNumber': chapterNumber,
    'progressPercent': progress.clamp(0, 1),
    'savedAtMs': DateTime.now().millisecondsSinceEpoch,
  });

  static Future<void> deleteLibraryEntry(String collection, String novelId) =>
      _userCollection(collection).doc(novelId).delete();

  static Future<void> clearLibrary(
    String collection,
    Iterable<String> ids,
  ) async {
    final batch = firestore.batch();
    for (final id in ids) {
      batch.delete(_userCollection(collection).doc(id));
    }
    await batch.commit();
  }

  static Future<void> recordView(Novel novel) async {
    final now = DateTime.now();
    String dateKey(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final day = dateKey(now);
    final week = dateKey(now.subtract(Duration(days: now.weekday - 1)));
    final month =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}';
    try {
      await novels.doc(novel.id).update({
        'viewCount': FieldValue.increment(1),
        'dailyViews.$day': FieldValue.increment(1),
        'weeklyViews.$week': FieldValue.increment(1),
        'monthlyViews.$month': FieldValue.increment(1),
      });
    } on FirebaseException catch (error) {
      if (error.code != 'not-found') rethrow;
    }
  }

  static Stream<List<Map<String, dynamic>>> watchReviews(String novelId) =>
      firestore
          .collection('reviews')
          .where('novelId', isEqualTo: novelId)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => {'id': doc.id, ...doc.data()})
                    .toList()
                  ..sort(
                    (a, b) => ((b['createdAtMs'] ?? 0) as num).compareTo(
                      (a['createdAtMs'] ?? 0) as num,
                    ),
                  ),
          );

  static Stream<Map<String, dynamic>?> watchMyReview(String novelId) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return firestore
        .collection('reviews')
        .doc('${novelId}_$uid')
        .snapshots()
        .map((doc) => doc.data());
  }

  static Future<void> saveReview({
    required String novelId,
    required int rating,
    required String comment,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Đăng nhập để đánh giá truyện.');
    await firestore.collection('reviews').doc('${novelId}_${user.uid}').set({
      'novelId': novelId,
      'userId': user.uid,
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName
          : user.email?.split('@').first ?? 'Độc giả',
      'rating': rating,
      'comment': comment.trim(),
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Stream<List<String>> watchGenres() => genres
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => (doc.data()['name'] as String?) ?? doc.id)
            .toList(),
      );

  static Future<void> saveGenre(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty)
      throw ArgumentError('Tên thể loại không được để trống.');
    final id = normalized.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\u00C0-\u024F]+'),
      '-',
    );
    await genres.doc(id).set({
      'name': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteGenre(String name) async {
    final id = name.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9\u00C0-\u024F]+'),
      '-',
    );
    final used = await novels.where('category', isEqualTo: name).limit(1).get();
    if (used.docs.isNotEmpty)
      throw StateError(
        'Thể loại đang được truyện sử dụng. Hãy đổi thể loại truyện trước.',
      );
    await genres.doc(id).delete();
  }

  static Future<bool> isAdmin(String uid) async {
    // A previous offline state can persist in the web client. Re-enable the
    // Firestore network before checking the role after Firebase Auth succeeds.
    await firestore.enableNetwork();
    final user = await users.doc(uid).get();
    return user.data()?['role'] == 'admin';
  }

  static Stream<List<UserProfile>> watchUsers() =>
      users.snapshots().map((snapshot) {
        final profiles = snapshot.docs
            .map((doc) => UserProfile.fromMap(doc.id, doc.data()))
            .toList();
        profiles.sort(
          (a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        );
        return profiles;
      });

  static Stream<List<Map<String, dynamic>>> watchNotifications() {
    return announcements
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
                ..sort(
                  (a, b) => ((b['createdAtMs'] ?? 0) as num).compareTo(
                    (a['createdAtMs'] ?? 0) as num,
                  ),
                ),
        );
  }

  static Stream<List<Map<String, dynamic>>> watchImportantNotifications() =>
      watchNotifications().map(
        (items) => items.where((item) => item['important'] == true).toList(),
      );

  static Stream<List<Map<String, dynamic>>> watchUnreadNotifications() {
    final uid = auth.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    late final StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription<List<Map<String, dynamic>>>? announcementSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? readSubscription;
    var activeAnnouncements = <Map<String, dynamic>>[];
    var readIds = <String>{};

    void emitUnread() {
      if (controller.isClosed) return;
      controller.add(
        activeAnnouncements
            .where((item) => !readIds.contains(item['id']))
            .toList(),
      );
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        announcementSubscription = watchNotifications().listen(
          (items) {
            activeAnnouncements = items;
            emitUnread();
          },
          onError: (Object error, StackTrace stackTrace) =>
              controller.addError(error, stackTrace),
        );
        readSubscription = users
            .doc(uid)
            .collection('readNotifications')
            .snapshots()
            .listen(
              (snapshot) {
                readIds = snapshot.docs.map((doc) => doc.id).toSet();
                emitUnread();
              },
              onError: (Object error, StackTrace stackTrace) =>
                  controller.addError(error, stackTrace),
            );
      },
      onCancel: () async {
        await announcementSubscription?.cancel();
        await readSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  static Future<void> markNotificationsRead(Iterable<String> ids) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    final uniqueIds = ids.toSet().toList();
    final readCollection = users.doc(uid).collection('readNotifications');
    for (var start = 0; start < uniqueIds.length; start += 450) {
      final batch = firestore.batch();
      for (final id in uniqueIds.skip(start).take(450)) {
        batch.set(readCollection.doc(id), {
          'readAtMs': DateTime.now().millisecondsSinceEpoch,
        });
      }
      await batch.commit();
    }
  }

  static Stream<List<Map<String, dynamic>>> watchAllAnnouncements() =>
      announcements.snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList()
              ..sort(
                (a, b) => ((b['updatedAtMs'] ?? 0) as num).compareTo(
                  (a['updatedAtMs'] ?? 0) as num,
                ),
              ),
      );

  static Future<String> saveAnnouncement({
    String? id,
    required String title,
    required String message,
    String? imageUrl,
    List<int>? imageBytes,
    String? fileName,
    bool active = true,
    bool important = false,
  }) async {
    final ref = id == null ? announcements.doc() : announcements.doc(id);
    var resolvedImageUrl = imageUrl?.trim() ?? '';
    if (imageBytes != null && fileName != null) {
      final lowerName = fileName.toLowerCase();
      final contentType = lowerName.endsWith('.png')
          ? 'image/png'
          : lowerName.endsWith('.webp')
          ? 'image/webp'
          : lowerName.endsWith('.gif')
          ? 'image/gif'
          : 'image/jpeg';
      final imageRef = storage.ref('announcements/${ref.id}/banner');
      await imageRef.putData(
        Uint8List.fromList(imageBytes),
        SettableMetadata(contentType: contentType),
      );
      resolvedImageUrl = await imageRef.getDownloadURL();
    }
    await ref.set({
      'title': title.trim(),
      'message': message.trim(),
      'imageUrl': resolvedImageUrl,
      'active': active,
      'important': important,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAtMs': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
    return ref.id;
  }

  static Future<void> deleteAnnouncement(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    await announcements.doc(id).delete();
    final url = item['imageUrl'] as String? ?? '';
    if (url.contains('firebasestorage.googleapis.com') ||
        url.contains('firebasestorage.app')) {
      try {
        await storage.refFromURL(url).delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
    }
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Bạn chưa đăng nhập.');
    await users.doc(user.uid).update({'notificationsEnabled': enabled});
  }

  static Future<UserProfile?> getMyProfile() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final doc = await users
        .doc(user.uid)
        .get()
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw StateError(
            'Firestore không phản hồi. Kiểm tra kết nối mạng rồi thử lại.',
          ),
        );
    return UserProfile.fromMap(user.uid, {
      ...?doc.data(),
      'email': user.email ?? doc.data()?['email'] ?? '',
    });
  }

  static Future<void> saveMyProfile({
    required String displayName,
    required String phone,
    String? avatarUrl,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Bạn chưa đăng nhập.');
    final profileRef = users.doc(user.uid);
    // Update only editable fields so the existing role is preserved without
    // an extra read before the write.
    await profileRef
        .update({
          'email': user.email ?? '',
          'displayName': displayName.trim(),
          'phone': phone.trim(),
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw StateError(
            'Lưu hồ sơ quá thời gian chờ. Kiểm tra kết nối Firestore rồi thử lại.',
          ),
        );
  }

  static Future<void> updateUserProfile({
    required String uid,
    required String displayName,
    required String phone,
  }) => users.doc(uid).update({
    'displayName': displayName.trim(),
    'phone': phone.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  static Future<String> uploadAvatar({
    required String uid,
    required List<int> bytes,
    required String fileName,
  }) async {
    if (bytes.length > 5 * 1024 * 1024)
      throw StateError('Ảnh đại diện cần nhỏ hơn 5 MB.');
    final lowerName = fileName.toLowerCase();
    final contentType = lowerName.endsWith('.png')
        ? 'image/png'
        : lowerName.endsWith('.webp')
        ? 'image/webp'
        : lowerName.endsWith('.gif')
        ? 'image/gif'
        : 'image/jpeg';
    final ref = storage.ref('users/$uid/avatar');
    final upload = ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType),
    );
    try {
      await upload.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw StateError(
          'Tải ảnh quá lâu. Hãy kiểm tra Firebase Storage và kết nối mạng.',
        ),
      );
    } on StateError {
      await upload.cancel();
      rethrow;
    }
    return ref.getDownloadURL().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw StateError(
        'Tải ảnh xong nhưng Firebase Storage chưa trả đường dẫn. Hãy thử lại.',
      ),
    );
  }

  static Future<String> uploadNovelCover({
    required String novelId,
    required List<int> bytes,
    required String fileName,
  }) async {
    if (bytes.length > 10 * 1024 * 1024)
      throw StateError('Ảnh bìa cần nhỏ hơn 10 MB.');
    final lowerName = fileName.toLowerCase();
    final contentType = lowerName.endsWith('.png')
        ? 'image/png'
        : lowerName.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    final ref = storage.ref('novels/$novelId/cover');
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }

  static Future<void> deleteAvatar(String uid) async {
    try {
      await storage.ref('users/$uid/avatar').delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
    await users.doc(uid).set({
      'avatarUrl': '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null)
      throw StateError('Không tìm thấy tài khoản email đang đăng nhập.');
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  static Future<void> deleteUserAccount(String uid) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Bạn chưa đăng nhập.');
    final token = await user.getIdToken(true);
    final uri = Uri.https(
      'asia-southeast1-appdoctruyen-5b8a7.cloudfunctions.net',
      '/adminDeleteUser',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'data': {'uid': uid},
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400 || body['error'] != null) {
      final message =
          (body['error'] as Map?)?['message']?.toString() ??
          'Không xóa được tài khoản.';
      throw StateError(message);
    }
  }
}
