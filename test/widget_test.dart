import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/core/di/injection.dart';
import 'package:flutter_application_1/core/network/supabase_client_wrapper.dart';
import 'package:flutter_application_1/core/testing/dummy_auth_repository.dart';
import 'package:flutter_application_1/main.dart';

class FakeSupabaseClientWrapper extends Fake implements SupabaseClientWrapper {}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await setupDependencyInjection(
      supabaseClientWrapper: FakeSupabaseClientWrapper(),
      authRepository: DummyAuthRepository.unauthenticated(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'MainAppSelector renders unified LoginScreen when unauthenticated',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MainAppSelector());
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Academy Platform'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.pump(const Duration(seconds: 1));
    },
  );
}
