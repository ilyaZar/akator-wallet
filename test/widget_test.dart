import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akator_wallet/main.dart';

void main() {
  testWidgets('opens the draft menu and settings drawers', (tester) async {
    await tester.pumpWidget(const AkatorWalletApp());

    expect(find.text('Akator Wallet'), findsWidgets);
    expect(find.text('My favorites'), findsOneWidget);
    expect(find.text('Explore: Security & Data'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byTooltip('Cycle favorite card'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Collapse Section 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Collapse Section 3'));
    await tester.pumpAndSettle();
    expect(find.text('Explore: Security & Data'), findsOneWidget);
    expect(find.text('Own cloud storage'), findsNothing);
    expect(find.byTooltip('Expand Section 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Expand Section 3'));
    await tester.pumpAndSettle();
    expect(find.text('Own cloud storage'), findsOneWidget);

    await tester.tap(find.byTooltip('Open wallet menu'));
    await tester.pumpAndSettle();
    expect(find.text('johnDoe@gmail.com'), findsOneWidget);
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Syncthing'), findsOneWidget);

    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Wallet Settings'), findsOneWidget);
    expect(find.text('Connection status'), findsOneWidget);
    expect(find.text('add/remove items'), findsOneWidget);
  });
}
