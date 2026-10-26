import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../core/localization/app_localizations_helper.dart';
import '../core/localization/auth_error_localizer.dart';
import '../dev/demo_dashboard_screen.dart';
import '../dev/development_access.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AppLocalizations get _localizations =>
      appLocalizationsFor(LocalizationService.instance.currentLocale.value);

  Future<void> _login() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (error) {
      _showMessage(localizedAuthError(_localizations, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (error) {
      _showMessage(localizedAuthError(_localizations, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final AppLocalizations localizations = _localizations;
    final String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage(localizations.authResetEmailPrompt);
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      _showMessage(localizations.authResetEmailSent(email));
    } catch (error) {
      _showMessage(localizedAuthError(localizations, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openSignUp() {
    if (_loading) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SignUpScreen()));
  }

  void _openDemoDashboard() {
    if (!cyberUdayDevelopmentAccessEnabled || _loading) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DemoDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LocalizationService.instance.currentLocale,
      builder: (BuildContext context, String localeCode, Widget? child) {
        final AppLocalizations localizations = appLocalizationsFor(localeCode);
        final ThemeData authTheme = CyberTheme.lightTheme;
        return Theme(
          data: authTheme,
          child: Scaffold(
            backgroundColor: authTheme.scaffoldBackgroundColor,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool wide = constraints.maxWidth >= 860;
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: wide
                                ? CyberSpacing.page
                                : CyberSpacing.md,
                            vertical: CyberSpacing.xl,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1080),
                            child: wide
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: _CitizenBrandPanel(
                                          localizations: localizations,
                                          alignStart: true,
                                        ),
                                      ),
                                      CyberSpacing.horizontal(
                                        CyberSpacing.page,
                                      ),
                                      SizedBox(
                                        width: 420,
                                        child: _SignInForm(
                                          formKey: _formKey,
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          localizations: localizations,
                                          loading: _loading,
                                          onLogin: _login,
                                          onGoogleLogin: _loginWithGoogle,
                                          onResetPassword: _resetPassword,
                                          onCreateAccount: _openSignUp,
                                          onDemoAccess:
                                              cyberUdayDevelopmentAccessEnabled
                                              ? _openDemoDashboard
                                              : null,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _CitizenBrandPanel(
                                        localizations: localizations,
                                      ),
                                      CyberSpacing.vertical(CyberSpacing.xxl),
                                      _SignInForm(
                                        formKey: _formKey,
                                        emailController: _emailController,
                                        passwordController: _passwordController,
                                        localizations: localizations,
                                        loading: _loading,
                                        onLogin: _login,
                                        onGoogleLogin: _loginWithGoogle,
                                        onResetPassword: _resetPassword,
                                        onCreateAccount: _openSignUp,
                                        onDemoAccess:
                                            cyberUdayDevelopmentAccessEnabled
                                            ? _openDemoDashboard
                                            : null,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CitizenBrandPanel extends StatelessWidget {
  const _CitizenBrandPanel({
    required this.localizations,
    this.alignStart = false,
  });

  final AppLocalizations localizations;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CrossAxisAlignment axis = alignStart
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    return Column(
      crossAxisAlignment: axis,
      children: [
        Semantics(
          image: true,
          label: localizations.authBrandLine,
          child: Image.asset(
            'assets/cyber_uday_mark.png',
            width: alignStart ? 112 : 88,
            height: alignStart ? 112 : 88,
            fit: BoxFit.contain,
          ),
        ),
        CyberSpacing.vertical(CyberSpacing.lg),
        Text(
          'CYBER UDAY',
          style: theme.textTheme.headlineLarge,
          textAlign: alignStart ? TextAlign.left : TextAlign.center,
        ),
        CyberSpacing.vertical(CyberSpacing.xs),
        Text(
          localizations.authBrandLine,
          style: theme.textTheme.titleLarge?.copyWith(
            color: CyberColors.brandAccent,
          ),
          textAlign: alignStart ? TextAlign.left : TextAlign.center,
        ),
        CyberSpacing.vertical(CyberSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            localizations.authSignInIntro,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
            textAlign: alignStart ? TextAlign.left : TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.localizations,
    required this.loading,
    required this.onLogin,
    required this.onGoogleLogin,
    required this.onResetPassword,
    required this.onCreateAccount,
    this.onDemoAccess,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final AppLocalizations localizations;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onResetPassword;
  final VoidCallback onCreateAccount;
  final VoidCallback? onDemoAccess;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CyberCard(
      variant: CyberCardVariant.elevated,
      padding: const EdgeInsets.all(CyberSpacing.xl),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              localizations.authWelcomeBack,
              style: theme.textTheme.headlineMedium,
            ),
            CyberSpacing.vertical(CyberSpacing.xs),
            Text(
              localizations.authSignInIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: CyberColors.textSecondary,
              ),
            ),
            CyberSpacing.vertical(CyberSpacing.xl),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: localizations.authEmailLabel,
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) {
                final String text = value?.trim() ?? '';
                return text.isEmpty || !text.contains('@')
                    ? localizations.authEmailValidation
                    : null;
              },
            ),
            CyberSpacing.vertical(CyberSpacing.md),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: localizations.authPasswordLabel,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) => (value ?? '').isEmpty
                  ? localizations.authPasswordValidation
                  : null,
              onFieldSubmitted: (_) => loading ? null : onLogin(),
            ),
            CyberSpacing.vertical(CyberSpacing.lg),
            CyberButton(
              label: localizations.authSignIn,
              onPressed: loading ? null : onLogin,
              isLoading: loading,
              expand: true,
              icon: const Icon(Icons.arrow_forward_rounded),
              semanticLabel: localizations.authSignIn,
            ),
            CyberSpacing.vertical(CyberSpacing.sm),
            OutlinedButton.icon(
              onPressed: loading ? null : onGoogleLogin,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: Text(localizations.authContinueGoogle),
            ),
            CyberSpacing.vertical(CyberSpacing.sm),
            _SecurityNotice(text: localizations.authSecurityNotice),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: loading ? null : onResetPassword,
                child: Text(localizations.authForgotPassword),
              ),
            ),
            const Divider(height: CyberSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: CyberSpacing.xxs,
              children: [
                Text(
                  localizations.authNoAccount,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: loading ? null : onCreateAccount,
                  child: Text(localizations.authCreateAccount),
                ),
              ],
            ),
            if (onDemoAccess != null) ...[
              const Divider(height: CyberSpacing.lg),
              Text(
                localizations.authDevPreview,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
              CyberSpacing.vertical(CyberSpacing.xs),
              CyberButton(
                label: localizations.authDevAccessDashboard,
                variant: CyberButtonVariant.secondary,
                icon: const Icon(Icons.visibility_outlined),
                expand: true,
                onPressed: loading ? null : onDemoAccess,
                semanticLabel: localizations.authDevAccessDashboard,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: theme.colorScheme.secondary,
        ),
        CyberSpacing.horizontal(CyberSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
            ),
          ),
        ),
      ],
    );
  }
}
