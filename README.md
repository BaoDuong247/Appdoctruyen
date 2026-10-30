# App Đọc Truyện — Firebase

Firebase project: `appdoctruyen-5b8a7`.

## Chạy ứng dụng

```powershell
flutter pub get
flutter run -d chrome
```

Web and Android Firebase identifiers are in `lib/firebase_options.dart` and `android/app/google-services.json`.

## Firebase setup

- Enable **Authentication → Sign-in method → Email/Password**.
- Publish `firestore.rules` and `storage.rules` to the Firebase project. The app reads story, genre, and active announcement data publicly; admins can manage stories, genres, announcements, and profile records.
- Enable **Firebase Storage** before uploading profile photos, story covers, or announcement banners. Cover and announcement images are limited to 10 MB; avatars are limited to 5 MB.
- The **Thể loại** tab manages Firestore genre tags. Story forms select a tag from that collection.
- Admins can create, edit, show/hide, and delete announcements from the **Thông báo** tab. Each announcement supports a title, body, and image URL or uploaded image; active announcements appear on readers' notification screen.
- If Firestore is empty, readers see six original bundled sample stories and covers. Admins can press **Nạp 6 truyện mẫu** to add the stories and starter genres to Firestore.

## Admin account deletion

Deleting a Firebase Authentication account must run on a trusted server. This project includes `functions/adminDeleteUser`, which verifies the Firebase ID token and the caller's Firestore admin role, protects admin accounts, then removes the selected user's Auth account, profile document, and avatar.

Install and deploy the function from the project directory:

```powershell
cd functions
npm install
cd ..
firebase deploy --only firestore:rules,storage,functions:adminDeleteUser
```

The account deletion action reports an error until the function and rules are deployed to the same Firebase project.

## Screens

- **Reader home:** centered responsive layout, live genre chips, search, a slowly advancing swipeable cover carousel with previous/next controls, story grid, sign out, and light/dark theme toggle.
- **Reader profile:** users can update their own display name, phone number, avatar, and password. Email and role remain protected.
- **Admin:** overview, story and chapter management, genre tags, user profile editing/deletion, and administrator profile controls.
- Story covers accept either a web URL or an image selected from the device and uploaded to Firebase Storage.
- User passwords are handled by Firebase Authentication and are never visible in the admin list.
