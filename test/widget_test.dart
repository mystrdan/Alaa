import 'package:alaa/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Alaa opens on the offline-first home screen', (tester) async {
    await tester.pumpWidget(const AlaaApp());
    expect(find.text('What do you need to do?'), findsOneWidget);
    expect(find.text('Works offline'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Favourites'), findsOneWidget);
  });
}
