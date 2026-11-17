import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_exception.dart';
import '../../services/social_sign_in.dart';
import '../../utils/role_router.dart';
import '../../widgets/preference_buttons.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool returnAfterAuth;
  final String? initialMessage;

  const LoginScreen({
    super.key,
    this.returnAfterAuth = false,
    this.initialMessage,
    this.socialSignIn,
  });

  /// للاختبارات؛ الافتراضي SocialSignIn().
  final SocialSignIn? socialSignIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late String? _errorMessage;
  late final SocialSignIn _social = widget.socialSignIn ?? SocialSignIn();
  Set<String> _providers = const {};

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialMessage;
    _social.availableProviders().then((providers) {
      if (mounted) setState(() => _providers = providers);
    });
  }

  /// نافذة رمز تطبيق المصادقة؛ تعيد الرمز أو null عند الإلغاء.
  Future<String?> _askTwoFactorCode() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const AppText('التحقق بخطوتين'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText(
              'افتح تطبيق المصادقة على هاتفك واكتب الرمز المكوّن من 6 أرقام.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('two-factor-code'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.visiblePassword,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLength: 20,
              style: const TextStyle(
                fontSize: 22,
                letterSpacing: 6,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                helperText: context.tr(
                  'فقدت هاتفك؟ اكتب أحد رموز الاسترداد بدلاً من ذلك.',
                ),
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('إلغاء'),
          ),
          FilledButton(
            key: const ValueKey('two-factor-submit'),
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) Navigator.pop(ctx, code);
            },
            child: const AppText('تأكيد ودخول'),
          ),
        ],
      ),
    );
  }

  Future<void> _socialLogin(String provider) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final messenger = ScaffoldMessenger.of(context);
      final auth = context.read<AuthProvider>();
      final token = await _social.token(provider);
      if (token == null) return; // ألغى المستخدم
      final notice = await auth.socialLogin(provider, token);
      if (!mounted) return;
      routeAfterAuthentication(
        context,
        auth.user!.role,
        returnToCaller: widget.returnAfterAuth,
      );
      if (notice != null) {
        messenger.showSnackBar(SnackBar(content: AppText(notice)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = AppLocalizations.of(context).translate(e.message),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = context.tr('تعذّر إكمال الدخول.'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _socialButtons() {
    if (_providers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: AppText(
                  'أو تابع كعميل عبر',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 12),
          if (_providers.contains('google'))
            OutlinedButton.icon(
              key: const ValueKey('social-google'),
              onPressed: _isLoading ? null : () => _socialLogin('google'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1F1F1F),
                side: const BorderSide(color: Color(0xFFDADCE0)),
              ),
              icon: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              label: const AppText('المتابعة بـ Google'),
            ),
          if (_providers.length == 2) const SizedBox(height: 10),
          if (_providers.contains('facebook'))
            FilledButton.icon(
              key: const ValueKey('social-facebook'),
              onPressed: _isLoading ? null : () => _socialLogin('facebook'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.facebook),
              label: const AppText('المتابعة بـ Facebook'),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final enteredIdentifier = _identifierController.text.trim();
      final identifier = enteredIdentifier.contains('@')
          ? enteredIdentifier.replaceAll(RegExp(r'\s+'), '')
          : enteredIdentifier;
      final messenger = ScaffoldMessenger.of(context);
      final auth = context.read<AuthProvider>();
      String? notice;
      try {
        notice = await auth.login(identifier, _passwordController.text);
      } on TwoFactorRequired catch (e) {
        final code = await _askTwoFactorCode();
        if (code == null) return; // ألغى
        notice = await auth.completeTwoFactor(e.challenge, code);
      }

      if (!mounted) return;
      final role = context.read<AuthProvider>().user!.role;
      routeAfterAuthentication(
        context,
        role,
        returnToCaller: widget.returnAfterAuth,
      );
      // مثل: «أهلاً بعودتك! أُلغي طلب حذف حسابك»
      if (notice != null) {
        messenger.showSnackBar(SnackBar(content: AppText(notice)));
      }
    } on ApiException catch (e) {
      setState(
        () => _errorMessage = AppLocalizations.of(context).translate(e.message),
      );
    } catch (_) {
      setState(() => _errorMessage = context.tr('تعذّر الاتصال بالسيرفر.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // شريط شفاف: رجوع (إن فُتحت الشاشة من مكان آخر) + اللغة والمظهر قبل الدخول
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [PreferenceButtons(), SizedBox(width: 4)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: context.tr('تريند'),
                          style: const TextStyle(color: AppColors.emerald),
                        ),
                        TextSpan(
                          text: context.tr('شام'),
                          style: const TextStyle(color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'سجّل دخولك للمتابعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 32),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppText(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  TextFormField(
                    controller: _identifierController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).translate('البريد الإلكتروني أو رقم الهاتف'),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? AppLocalizations.of(context).translate('مطلوب')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(
                        context,
                      ).translate('كلمة السر'),
                      suffixIcon: IconButton(
                        tooltip: context.tr(
                          _obscurePassword
                              ? 'إظهار كلمة المرور'
                              : 'إخفاء كلمة المرور',
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? AppLocalizations.of(context).translate('مطلوب')
                        : null,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: AppText(
                      AppLocalizations.of(
                        context,
                      ).translate('نسيت كلمة المرور؟'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const AppText('تسجيل الدخول'),
                  ),
                  _socialButtons(),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final registered = await navigator.push<bool>(
                        MaterialPageRoute(
                          builder: (_) => RegisterScreen(
                            returnAfterAuth: widget.returnAfterAuth,
                          ),
                        ),
                      );
                      if (registered == true &&
                          widget.returnAfterAuth &&
                          navigator.mounted) {
                        navigator.pop(true);
                      }
                    },
                    child: const AppText('ليس لديك حساب؟ أنشئ حساباً جديداً'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
