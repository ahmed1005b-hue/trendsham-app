import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../utils/role_router.dart';
import 'auth/login_screen.dart';
import 'home/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  Future<void> _checkAuth() async {
    final auth = context.read<AuthProvider>();
    try {
      await auth.loadFromStorage();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LoginScreen(initialMessage: e.message),
          ),
        );
        return;
      }
      setState(() => _errorMessage = e.message);
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'تعذّر الاتصال بالسيرفر.');
      }
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => auth.isLoggedIn
            ? roleHomeScreen(auth.user!.role)
            : const MainScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(_errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _errorMessage = null);
                      _checkAuth();
                    },
                    child: const AppText('إعادة المحاولة'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    ),
                    child: const AppText('تصفّح كضيف'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      // نفس لون أيقونة التطبيق وشاشة البداية الأصلية
      backgroundColor: Color(0xFFFF3B5C),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              'تريندشام',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
