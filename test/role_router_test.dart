import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/screens/admin/admin_main_screen.dart';
import 'package:trendsham/utils/role_router.dart';

void main() {
  test('normalizes the authenticated role before routing', () {
    final user = AppUser.fromJson({
      'id': 1,
      'role': ' Admin ',
    });

    expect(user.role, 'admin');
    expect(roleHomeScreen(user.role), isA<AdminMainScreen>());
  });

  test('does not silently route an unsupported role to the customer screen',
      () {
    expect(() => roleHomeScreen('unknown'), throwsArgumentError);
  });

  testWidgets('customer authentication returns to the previous action',
      (tester) async {
    bool? authenticated;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                authenticated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (loginContext) => Scaffold(
                      body: ElevatedButton(
                        onPressed: () => routeAfterAuthentication(
                          loginContext,
                          'customer',
                          returnToCaller: true,
                        ),
                        child: const Text('Finish login'),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open login'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish login'));
    await tester.pumpAndSettle();

    expect(authenticated, isTrue);
    expect(find.text('Open login'), findsOneWidget);
  });
}
