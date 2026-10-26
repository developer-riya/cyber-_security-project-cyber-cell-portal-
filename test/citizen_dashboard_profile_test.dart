import 'package:cyberuday/screens/home/pages/dashboard_page.dart';
import 'package:cyberuday/screens/profile_screen.dart';
import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/services/hacker_news_service.dart';
import 'package:cyberuday/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocalizationService.instance.setLocale('en'));

  Future<List<HackerNewsStory>> emptyNews() => Future.value(const []);

  testWidgets('citizen dashboard presents protection-first entry points', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: null,
          onNavigate: (_) {},
          latestNewsFuture: emptyNews(),
        ),
      ),
    );

    expect(find.text('Welcome back, there'), findsOneWidget);
    expect(find.text('Your protection overview'), findsOneWidget);
    expect(find.text('What do you need today?'), findsOneWidget);
    expect(find.text('Threat Scanner'), findsOneWidget);
    expect(find.text('Report Cybercrime'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CyberCard && widget.variant == CyberCardVariant.emergency,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CyberCard &&
            widget.variant == CyberCardVariant.criticalAlert,
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'No personal activity to show yet. Scan a link or submit a report to get started.',
      ),
      findsOneWidget,
    );
    expect(find.text('COMMAND CENTER'), findsNothing);
    expect(find.text('Threats Blocked'), findsNothing);
  });

  testWidgets(
    'dashboard remains readable at mobile, tablet, and desktop sizes',
    (WidgetTester tester) async {
      const List<Size> sizes = <Size>[
        Size(390, 844),
        Size(768, 1024),
        Size(1440, 900),
      ];

      for (final Size size in sizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            theme: CyberTheme.lightTheme,
            home: DashboardPage(
              user: null,
              onNavigate: (_) {},
              latestNewsFuture: emptyNews(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('citizen dashboard follows the selected Marathi locale', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('mr');
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: null,
          onNavigate: (_) {},
          latestNewsFuture: emptyNews(),
        ),
      ),
    );

    expect(find.text('तुमचे स्वागत आहे, there'), findsOneWidget);
    expect(find.text('तुमच्या सुरक्षेचा आढावा'), findsOneWidget);
    expect(find.text('सायबर गुन्हा रिपोर्ट करा'), findsOneWidget);
  });

  testWidgets('citizen dashboard follows the selected Hindi locale', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('hi');
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardPage(
          user: null,
          onNavigate: (_) {},
          latestNewsFuture: emptyNews(),
        ),
      ),
    );

    expect(find.text('वापसी पर स्वागत है, there'), findsOneWidget);
    expect(find.text('आपकी सुरक्षा का अवलोकन'), findsOneWidget);
    expect(find.text('साइबर अपराध रिपोर्ट करें'), findsOneWidget);
  });

  testWidgets('dashboard uses the product light theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: DashboardPage(
          user: null,
          onNavigate: (_) {},
          latestNewsFuture: emptyNews(),
        ),
      ),
    );

    expect(find.text('Your protection overview'), findsOneWidget);
    expect(find.text('Emergency Help'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile foundation renders identity and language controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Cyber Uday citizen'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('account menu shows identity and opens the profile action', (
    WidgetTester tester,
  ) async {
    bool profileOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              CyberAccountMenu(
                displayName: 'Uday Payghon',
                email: 'uday@example.com',
                onProfile: () => profileOpened = true,
                onSignOut: () async {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CyberAccountMenu));
    await tester.pumpAndSettle();

    expect(find.text('Uday Payghon'), findsOneWidget);
    expect(find.text('uday@example.com'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(profileOpened, isTrue);
  });

  testWidgets('profile language control follows Hindi and Marathi locales', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('hi');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    expect(find.text('भाषा'), findsOneWidget);

    LocalizationService.instance.setLocale('mr');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    expect(find.text('भाषा'), findsOneWidget);
  });

  testWidgets('profile asks for confirmation before sign out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));

    await tester.scrollUntilVisible(find.text('Sign out'), 300);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of Cyber Uday?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of Cyber Uday?'), findsNothing);
  });

  testWidgets('profile renders authenticated identity details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: const ProfileScreen(
          identity: ProfileIdentity(
            displayName: 'Uday Payghon',
            email: 'uday@example.com',
          ),
        ),
      ),
    );

    expect(find.text('Uday Payghon'), findsOneWidget);
    expect(find.text('uday@example.com'), findsOneWidget);
    expect(find.byType(CyberSettingsGroup), findsNWidgets(1));
  });

  testWidgets('profile uses an initial avatar when no photo is available', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: const ProfileScreen(
          identity: ProfileIdentity(
            displayName: 'Sagar Jadhav',
            email: 'sagar@example.com',
          ),
        ),
      ),
    );

    expect(find.text('SJ'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Account profile image')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('profile overrides an ambient dark theme with product light', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const ProfileScreen(
          identity: ProfileIdentity(
            displayName: 'Light Mode User',
            email: 'light@example.com',
          ),
        ),
      ),
    );

    expect(find.text('Light Mode User'), findsOneWidget);
    expect(find.byType(CyberCard), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Theme && widget.data.brightness == Brightness.light,
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('profile back navigation returns to the dashboard route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open profile'), findsOneWidget);
  });

  testWidgets('profile uses distinct desktop and mobile compositions', (
    WidgetTester tester,
  ) async {
    const ProfileScreen profile = ProfileScreen(
      identity: ProfileIdentity(displayName: 'Responsive User'),
    );

    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpWidget(const MaterialApp(home: profile));
    expect(find.text('Profile'), findsNWidgets(2));

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const MaterialApp(home: profile));
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}
