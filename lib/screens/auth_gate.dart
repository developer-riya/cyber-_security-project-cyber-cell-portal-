import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/cyber_design_system.dart';
import '../services/auth_service.dart';
import '../services/onboarding_preference_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingPreferenceService.instance.isComplete(),
      builder: (context, onboardingSnapshot) {
        if (onboardingSnapshot.connectionState != ConnectionState.done) {
          return const _AuthGateLoader();
        }

        if (onboardingSnapshot.data != true) {
          return const OnboardingScreen();
        }

        return StreamBuilder<User?>(
          stream: AuthService.instance.authStateChanges,
          builder: (context, snapshot) {
            // Show a themed loader while checking auth state.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _AuthGateLoader();
            }

            // If user is logged in, show HomeScreen.
            if (snapshot.hasData && snapshot.data != null) {
              return const HomeScreen();
            }

            // Otherwise, show LoginScreen.
            return const LoginScreen();
          },
        );
      },
    );
  }
}

class _AuthGateLoader extends StatelessWidget {
  const _AuthGateLoader();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = CyberTheme.lightTheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: const Center(child: _AuthGateLoaderContent()),
      ),
    );
  }
}

class _AuthGateLoaderContent extends StatelessWidget {
  const _AuthGateLoaderContent();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.secondary,
          ),
          strokeWidth: 3,
        ),
        const SizedBox(height: 24),
        Text(
          'VERIFYING IDENTITY...',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            letterSpacing: 2,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
