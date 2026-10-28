import 'package:flutter_test/flutter_test.dart';
import 'package:compilelens/main.dart';

void main() {
  testWidgets('CompileLens smoke test loads pipeline', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CompileLensApp());

    // Verify that the title bar and primary button exist
    expect(find.text('CompileLens'), findsOneWidget);
    expect(find.text('Compile & Visualize'), findsOneWidget);
  });
}
