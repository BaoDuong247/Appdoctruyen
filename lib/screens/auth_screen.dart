import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../services/firebase_data.dart';
import '../widgets/tambao_logo.dart';
import 'home_screen.dart'; // Màn hình người xem
import 'admin_screen.dart'; // Màn hình admin

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Các controller quản lý dữ liệu formflutterfire configure
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoginMode = true; // true: Đăng nhập, false: Đăng ký
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Vui lòng điền đầy đủ thông tin bắt buộc!');
      return;
    }

    if (!_isLoginMode) {
      final phone = _phoneController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (phone.isEmpty) {
        _showSnackBar('Vui lòng nhập số điện thoại!');
        return;
      }
      if (password != confirmPassword) {
        _showSnackBar('Mật khẩu nhập lại không khớp!');
        return;
      }
      if (password.length < 6) {
        _showSnackBar('Mật khẩu phải có ít nhất 6 ký tự!');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isLoginMode) {
        final credential = await FirebaseData.auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final admin = await FirebaseData.isAdmin(credential.user!.uid);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => admin
                ? const AdminScreen(celebrateLogin: true)
                : const HomeScreen(celebrateLogin: true),
          ),
        );
      } else {
        final credential = await FirebaseData.auth
            .createUserWithEmailAndPassword(email: email, password: password);
        await credential.user!.updateDisplayName(_nameController.text.trim());
        await FirebaseData.firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set({
              'email': email,
              'displayName': _nameController.text.trim(),
              'phone': _phoneController.text.trim(),
              'role': 'user',
              'createdAt': DateTime.now().toUtc().toIso8601String(),
            });
        if (!mounted) return;
        setState(() {
          _isLoginMode = true;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
        _showSnackBar('Đăng ký thành công. Bạn có thể đăng nhập.');
      }
    } catch (error) {
      _showSnackBar(_friendlyAuthError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyAuthError(Object error) {
    if (error is FirebaseException &&
        (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
      return 'Đăng nhập Firebase thành công nhưng chưa kết nối được Firestore. '
          'Hãy kiểm tra Internet hoặc thử mạng khác, tải lại ứng dụng sau khi cập nhật. '
          'Lỗi này thường do kết nối Firestore bị chặn; nếu nhận permission-denied, hãy xuất bản Firestore Rules cho dự án appdoctruyen-5b8a7.';
    }
    final message = error.toString();
    if (message.contains('email-already-in-use'))
      return 'Email này đã được đăng ký.';
    if (message.contains('invalid-credential') ||
        message.contains('user-not-found') ||
        message.contains('wrong-password'))
      return 'Email hoặc mật khẩu không đúng.';
    if (message.contains('weak-password'))
      return 'Mật khẩu cần ít nhất 6 ký tự.';
    if (message.contains('permission-denied'))
      return 'Firebase Security Rules chưa cho phép thao tác này.';
    return 'Có lỗi khi xác thực: $message';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldTextColor = isDark
        ? const Color(0xFFF5ECFA)
        : const Color(0xFF30253A);
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme
            .copyWith(primary: const Color(0xFF7040B2)),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2233) : const Color(0xFFF8F5FC),
          prefixIconColor: isDark
              ? const Color(0xFFD6C5E8)
              : const Color(0xFF665575),
          suffixIconColor: isDark
              ? const Color(0xFFD6C5E8)
              : const Color(0xFF665575),
          labelStyle: TextStyle(
            color: isDark ? const Color(0xFFD6C5E8) : const Color(0xFF665575),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: isDark ? const Color(0xFF655570) : const Color(0xFFD3C5E1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8B58D0), width: 2),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isLoginMode ? 'Đăng Nhập Hệ Thống' : 'Đăng Ký Tài Khoản',
          ),
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF5A2A9D),
          flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF49217F), Color(0xFF8050C8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          elevation: 0,
          centerTitle: true,
        ),
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
                            Color(0xFFF4ECFF),
                            Color(0xFFE9DCFF),
                            Color(0xFFFAF7FF),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -95,
              right: -65,
              child: _LoginGlow(
                size: 260,
                color: isDark
                    ? const Color(0x263E2D55)
                    : const Color(0x357B42C4),
              ),
            ),
            Positioned(
              bottom: -110,
              left: -90,
              child: _LoginGlow(
                size: 290,
                color: isDark
                    ? const Color(0x263D2636)
                    : const Color(0x287B42C4),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 22),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF211B29)
                          : Colors.white.withValues(alpha: .98),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF40344B)
                            : const Color(0xFFE4D7F7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0x50000000)
                              : const Color(0x267343A8),
                          blurRadius: 40,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF392A48)
                                : const Color(0xFFF2E9FF),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F7543B8),
                                blurRadius: 18,
                                offset: Offset(0, 7),
                              ),
                            ],
                          ),
                          child: const TambaoLogo(
                            width: 150,
                            height: 140,
                            radius: 21,
                          ),
                        ),
                        const SizedBox(height: 19),
                        Text(
                          _isLoginMode
                              ? 'Chào mừng bạn quay lại!'
                              : 'Tạo tài khoản mới',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFF3EAF8)
                                : const Color(0xFF342344),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Đăng nhập để tiếp tục hành trình đọc của bạn',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFC6B8D1)
                                : const Color(0xFF6F627A),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Trường Email / Tên đăng nhập
                        TextField(
                          controller: _emailController,
                          style: TextStyle(color: fieldTextColor),
                          decoration: const InputDecoration(
                            labelText: 'Email hoặc Tên đăng nhập',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Trường Số điện thoại (Chỉ hiện khi Đăng ký)
                        if (!_isLoginMode) ...[
                          TextField(
                            controller: _nameController,
                            style: TextStyle(color: fieldTextColor),
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Tên hiển thị',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _phoneController,
                            style: TextStyle(color: fieldTextColor),
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Trường Mật khẩu
                        TextField(
                          controller: _passwordController,
                          style: TextStyle(color: fieldTextColor),
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Trường Nhập lại mật khẩu (Chỉ hiện khi Đăng ký)
                        if (!_isLoginMode) ...[
                          TextField(
                            controller: _confirmPasswordController,
                            style: TextStyle(color: fieldTextColor),
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Nhập lại mật khẩu',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirmPassword
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Nút Xác nhận (Đăng nhập / Đăng ký)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7040B2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                              shadowColor: const Color(0x557040B2),
                            ),
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _isLoginMode ? 'ĐĂNG NHẬP' : 'ĐĂNG KÝ',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Nút chuyển đổi qua lại giữa Đăng nhập và Đăng ký
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                            });
                          },
                          child: Text(
                            _isLoginMode
                                ? 'Chưa có tài khoản? Đăng ký ngay'
                                : 'Đã có tài khoản? Đăng nhập',
                            style: const TextStyle(
                              color: const Color(0xFF7040B2),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginGlow extends StatelessWidget {
  const _LoginGlow({required this.size, required this.color});

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
