import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smartcity_lpwan/providers/ai_provider.dart';
import 'package:smartcity_lpwan/providers/dashboard_provider.dart';
import 'package:smartcity_lpwan/screens/mobile_home_screen.dart';

void main() {
  testWidgets('SmartCity mobile shell renders SC1 domain overview',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
              create: (_) => DashboardProvider()..initialize()),
          ChangeNotifierProvider(create: (_) => AiProvider()),
        ],
        child: const MaterialApp(home: MobileHomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('SmartCity LPWAN'), findsOneWidget);

    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -420));
    await tester.pump();

    expect(find.text('Domain Nodes'), findsOneWidget);
    expect(find.text('Building & Irrigation'), findsWidgets);
    expect(find.text('Gateway'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
