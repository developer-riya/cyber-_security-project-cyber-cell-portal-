import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/cyber_layout.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _submitting = false;

  static const Set<String> _adminEmails = {
    'founder@cyberuday.com',
    'udaypayghon@gmail.com',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _submitting = true);
    final email = _emailController.text.trim().toLowerCase();

    try {
      await AuthService.instance.login(
        email: email,
        password: _passwordController.text,
      );

      if (!_adminEmails.contains(email)) {
        await AuthService.instance.logout();
        throw const AuthFailure(
          'This account is not authorized for admin access.',
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Admin Access Granted.')));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CyberLayout(
      heroTag: 'ADMIN ACCESS',
      title: 'Restricted access for the Cyber Uday command team.',
      subtitle:
          'Use this page for operator review, escalations, premium case handling, and verified internal workflows.',
      sideNote: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF1E4A67)),
          color: const Color(0xFF0B1823).withValues(alpha: 0.82),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Internal controls',
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF3FFFD7),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Case review dashboard',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manual premium support routing',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'User-bank emergency escalation',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin login', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Only verified team members should proceed.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Admin email',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Enter admin email.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Enter password.';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const Text('Validate Access'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }
}
