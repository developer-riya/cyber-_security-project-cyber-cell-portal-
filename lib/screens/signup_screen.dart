import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../core/localization/app_localizations_helper.dart';
import '../core/localization/auth_error_localizer.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'auth_gate.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  AppLocalizations get _localizations =>
      appLocalizationsFor(LocalizationService.instance.currentLocale.value);

  Future<void> _signup() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await _goToAuthGate();
    } catch (error) {
      _showMessage(localizedAuthError(_localizations, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _loading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      await _goToAuthGate();
    } catch (error) {
      _showMessage(localizedAuthError(_localizations, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goToAuthGate() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                  final Widget form = _SignUpForm(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    localizations: localizations,
                    loading: _loading,
                    onSignup: _signup,
                    onGoogleSignup: _continueWithGoogle,
                  );

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
                                        child: _SignUpBrand(
                                          localizations: localizations,
                                          alignStart: true,
                                        ),
                                      ),
                                      CyberSpacing.horizontal(
                                        CyberSpacing.page,
                                      ),
                                      SizedBox(width: 420, child: form),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _SignUpBrand(
                                        localizations: localizations,
                                      ),
                                      CyberSpacing.vertical(CyberSpacing.xxl),
                                      form,
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

class _SignUpBrand extends StatelessWidget {
  const _SignUpBrand({required this.localizations, this.alignStart = false});

  final AppLocalizations localizations;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
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
            localizations.authSignUpIntro,
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

class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.localizations,
    required this.loading,
    required this.onSignup,
    required this.onGoogleSignup,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final AppLocalizations localizations;
  final bool loading;
  final VoidCallback onSignup;
  final VoidCallback onGoogleSignup;

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
              localizations.authSignUpTitle,
              style: theme.textTheme.headlineMedium,
            ),
            CyberSpacing.vertical(CyberSpacing.xs),
            Text(
              localizations.authSignUpIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
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
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: localizations.authPasswordLabel,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) => (value ?? '').length < 6
                  ? localizations.authPasswordLengthValidation
                  : null,
            ),
            CyberSpacing.vertical(CyberSpacing.md),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: localizations.authConfirmPassword,
                prefixIcon: const Icon(Icons.verified_user_outlined),
              ),
              validator: (value) => value != passwordController.text
                  ? localizations.authPasswordMismatch
                  : null,
              onFieldSubmitted: (_) => loading ? null : onSignup(),
            ),
            CyberSpacing.vertical(CyberSpacing.lg),
            CyberButton(
              label: localizations.authCreateAccountAction,
              onPressed: loading ? null : onSignup,
              isLoading: loading,
              expand: true,
              icon: const Icon(Icons.arrow_forward_rounded),
              semanticLabel: localizations.authCreateAccountAction,
            ),
            CyberSpacing.vertical(CyberSpacing.sm),
            OutlinedButton.icon(
              onPressed: loading ? null : onGoogleSignup,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: Text(localizations.authContinueGoogle),
            ),
            const Divider(height: CyberSpacing.lg),
            TextButton(
              onPressed: loading ? null : () => Navigator.of(context).pop(),
              child: Text(localizations.authBackToSignIn),
            ),
          ],
        ),
      ),
    );
  }
}
