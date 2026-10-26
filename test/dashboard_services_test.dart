import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/screens/home/pages/bank_security_page.dart';
import 'package:cyberuday/screens/home/widgets/cyber_news_preview.dart';
import 'package:cyberuday/services/hacker_news_service.dart';
import 'package:cyberuday/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocalizationService.instance.setLocale('en'));

  testWidgets('dashboard news preview renders real story data and view all', (
    WidgetTester tester,
  ) async {
    bool viewAllTapped = false;
    final HackerNewsStory story = HackerNewsStory(
      id: 42,
      title: 'A real security story',
      author: 'citizen-news',
      score: 10,
      commentCount: 2,
      time: DateTime(2026, 8, 9),
      url: 'https://news.ycombinator.com/item?id=42',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: Scaffold(
          body: CyberNewsPreview(
            storiesFuture: Future.value(<HackerNewsStory>[story]),
            onViewAll: () => viewAllTapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Latest cyber news'), findsOneWidget);
    expect(find.text('A real security story'), findsOneWidget);
    await tester.tap(find.text('View all'));
    expect(viewAllTapped, isTrue);
  });

  testWidgets('dashboard news preview reports an honest empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: Scaffold(
          body: CyberNewsPreview(
            storiesFuture: Future.value(const []),
            onViewAll: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No latest news is available right now.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'bank security explains that only a permission request is saved',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CyberTheme.lightTheme,
          home: BankSecurityPage(
            permissionStream:
                Stream<DocumentSnapshot<Map<String, dynamic>>>.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bank Security'), findsOneWidget);
      expect(find.text('No support permission requested yet'), findsOneWidget);
      expect(find.text('Request support'), findsOneWidget);
      expect(find.textContaining('does not connect a bank'), findsOneWidget);
    },
  );
}
