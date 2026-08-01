import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sanad_client/shared/widgets/file_extension_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileExtensionIcon Tests', () {
    testWidgets('renders SvgPicture for .dart file', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileExtensionIcon(fileName: 'main.dart', size: 24),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders SvgPicture for .py file', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileExtensionIcon(fileName: 'script.py', size: 20),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders SvgPicture for terminal key', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileExtensionIcon(fileName: 'terminal', size: 18),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders Material Icon for search key', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileExtensionIcon(fileName: 'search', size: 18),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('renders fallback SvgPicture for unknown extension', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FileExtensionIcon(fileName: 'file.unknownext', size: 20),
          ),
        ),
      );

      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
