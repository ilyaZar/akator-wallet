import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akator_wallet/build_info.dart';
import 'package:akator_wallet/main.dart';
import 'package:akator_wallet/wallet_card_store.dart';

void main() {
  testWidgets('opens the draft menu and settings drawers', (tester) async {
    await tester.pumpWidget(
      const AkatorWalletApp(cardStore: WalletCardStore(loadSavedCards: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Akator Wallet'), findsWidgets);
    expect(find.text('My favorites'), findsOneWidget);
    expect(find.text('Akator Blue'), findsWidgets);
    expect(find.text('Credit card'), findsWidgets);
    expect(find.text('Details hidden'), findsNothing);
    expect(find.text('**** 4242'), findsNothing);
    expect(find.text('John Doe'), findsNothing);
    expect(find.byTooltip('Edit Akator Blue'), findsNothing);
    expect(
      find.byKey(const ValueKey('view-card-image-demo-credit-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('view-card-summary-demo-credit-card')),
      findsNothing,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Explore: Security & Data'), findsOneWidget);
    await tester.tap(find.byTooltip('Open wallet menu'));
    await tester.pumpAndSettle();
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Syncthing'), findsOneWidget);
    expect(find.text('Proton Drive'), findsOneWidget);
    expect(find.text('Not installed'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('drawer-connection-syncthing')));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionsSheet), findsOneWidget);
    expect(
      find.text('Akator stores provider status and folder permission only.'),
      findsOneWidget,
    );
    expect(
      find.text('Use the Proton Drive app. Credentials stay there.'),
      findsOneWidget,
    );
    expect(find.text('Set up connection'), findsWidgets);
    expect(find.textContaining('password', findRichText: true), findsNothing);
    await tester.tap(find.byTooltip('Close connections'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Connection status'), findsOneWidget);
    expect(find.text('Set up connection'), findsWidgets);
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Build'), findsOneWidget);
    expect(find.text(AppBuildInfo.versionLabel), findsOneWidget);
    expect(find.text(AppBuildInfo.revisionLabel), findsOneWidget);
    expect(find.text(AppBuildInfo.releaseTag), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('settings-connection-proton-drive')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionsSheet), findsOneWidget);
    expect(find.text('Delete connection'), findsNothing);
    await tester.tap(find.byTooltip('Close connections'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byTooltip('Cycle favorite card'), findsNothing);
    expectOverviewFilterMapping();
    expect(find.text('card 01'), findsNothing);
    expect(find.text('card 02'), findsNothing);
    expect(find.text('passport/IDs'), findsOneWidget);
    expect(find.text('credit/debit cards'), findsOneWidget);
    expect(find.text('student IDs'), findsOneWidget);
    expect(find.text('health insurance'), findsOneWidget);
    expect(find.text('loyalty cards'), findsOneWidget);
    expect(find.text('driver licenses'), findsOneWidget);
    expect(visibleOverviewFilterIds(tester), [
      'passport_id',
      'credit_debit_cards',
      'student_ids',
      'health_insurance',
      'loyalty_cards',
      'driver_licenses',
    ]);
    expect(overviewCardIds(tester), [
      'demo-credit-card',
      'demo-student-id',
      'demo-personal-id',
      'demo-health-insurance',
      'demo-loyalty-card',
      'demo-driving-license',
      'demo-dc-library-card',
      'demo-customer-loyalty-cards',
      'demo-delta-skymiles-card',
    ]);
    expect(find.byType(OverviewCardTile), findsNWidgets(9));
    expect(find.byKey(const ValueKey('overview-card-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('overview-add-card')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('overview-add-card'))).dy,
      greaterThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('overview-card-scroll')))
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('view-overview-card-demo-credit-card')),
          )
          .dy,
      moreOrLessEquals(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('view-overview-card-demo-student-id')),
            )
            .dy,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('view-overview-card-demo-loyalty-card')),
          )
          .dy,
      moreOrLessEquals(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey('view-overview-card-demo-driving-license'),
              ),
            )
            .dy,
      ),
    );

    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-credit_debit_cards')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), ['demo-credit-card']);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-health_insurance')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), [
      'demo-credit-card',
      'demo-health-insurance',
    ]);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-credit_debit_cards')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), ['demo-health-insurance']);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-health_insurance')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), [
      'demo-credit-card',
      'demo-student-id',
      'demo-personal-id',
      'demo-health-insurance',
      'demo-loyalty-card',
      'demo-driving-license',
      'demo-dc-library-card',
      'demo-customer-loyalty-cards',
      'demo-delta-skymiles-card',
    ]);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-passport_id')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), ['demo-personal-id']);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-student_ids')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), ['demo-student-id', 'demo-personal-id']);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-credit_debit_cards')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), [
      'demo-credit-card',
      'demo-student-id',
      'demo-personal-id',
    ]);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('view-overview-card-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailSheet), findsOneWidget);
    expect(find.text('Card number'), findsOneWidget);
    await tester.tap(find.byTooltip('Close card view'));
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.byKey(const ValueKey('view-card-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailSheet), findsOneWidget);
    expect(find.byTooltip('Edit Akator Blue'), findsOneWidget);
    expect(find.byType(CardImageThumbnail), findsNWidgets(4));

    await tester.tap(
      find.byKey(const ValueKey('zoom-card-main-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardImageZoomView), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('zoom-image-assets/cards/credit_card.png')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close zoom'));
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailSheet), findsOneWidget);

    expect(
      tester
          .widgetList<CardImageThumbnail>(find.byType(CardImageThumbnail))
          .map((thumbnail) => thumbnail.image.uri),
      [
        'assets/cards/credit_card.png',
        'assets/cards/credit_card_2.png',
        'assets/cards/credit_card_3.png',
        'assets/cards/credit_card_4.png',
      ],
    );

    final thumbTop =
        tester
            .getTopLeft(
              find.byKey(const ValueKey('card-image-thumb-demo-credit-card-0')),
            )
            .dy;
    for (var index = 1; index < 4; index++) {
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey('card-image-thumb-demo-credit-card-$index')),
            )
            .dy,
        moreOrLessEquals(thumbTop),
      );
    }

    await tester.tap(
      find.byKey(const ValueKey('card-image-thumb-demo-credit-card-1')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardImagePreviewSheet), findsOneWidget);
    expect(find.text('Set as main image'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('zoom-preview-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardImageZoomView), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('zoom-image-assets/cards/credit_card_2.png')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close zoom'));
    await tester.pumpAndSettle();
    expect(find.byType(CardImagePreviewSheet), findsOneWidget);

    expect(
      tester
          .widget<MainImageButton>(
            find.byKey(const ValueKey('set-main-image-demo-credit-card')),
          )
          .isMainImage,
      isFalse,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('set-main-image-demo-credit-card')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('set-main-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardImagePreviewSheet), findsOneWidget);
    expect(find.text('Main image'), findsOneWidget);
    expect(
      tester
          .widget<MainImageButton>(
            find.byKey(const ValueKey('set-main-image-demo-credit-card')),
          )
          .isMainImage,
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('set-main-image-demo-credit-card')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close image preview'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CardImageThumbnail>(find.byType(CardImageThumbnail))
          .map((thumbnail) => thumbnail.image.uri),
      [
        'assets/cards/credit_card_2.png',
        'assets/cards/credit_card.png',
        'assets/cards/credit_card_3.png',
        'assets/cards/credit_card_4.png',
      ],
    );

    await tester.tap(
      find.byKey(const ValueKey('card-image-thumb-demo-credit-card-0')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MainImageButton>(
            find.byKey(const ValueKey('set-main-image-demo-credit-card')),
          )
          .isMainImage,
      isTrue,
    );

    await tester.tap(
      find.byKey(const ValueKey('set-main-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.text('already set as main image'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('already set as main image'), findsNothing);

    await tester.tap(find.byTooltip('Close image preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit Akator Blue'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Akator Blue'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Card number'), findsOneWidget);
    expect(find.byTooltip('Hold to show CVC code'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == '123' &&
            widget.obscureText,
      ),
      findsOneWidget,
    );

    final cvcGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold-edit-cvc'))),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == '123' &&
            !widget.obscureText,
      ),
      findsOneWidget,
    );
    await cvcGesture.up();
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == '123' &&
            widget.obscureText,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<SaveChangesButton>(find.byType(SaveChangesButton)).saved,
      isFalse,
    );
    expect(
      find.descendant(
        of: find.byType(SaveChangesButton),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );

    await tester.tap(find.byType(SaveChangesButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SaveChangesButton>(find.byType(SaveChangesButton)).saved,
      isTrue,
    );

    await tester.tap(find.byType(SaveChangesButton));
    await tester.pumpAndSettle();
    expect(find.text('Changes already saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Changes already saved'), findsNothing);

    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsNothing);
    expect(findAssetImage('assets/cards/credit_card_2.png'), findsWidgets);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('view-card-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CardDetailSheet)).height, 450);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('CVC code'), findsOneWidget);
    expect(find.text('***'), findsOneWidget);
    expect(find.text('123'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('hold-view-cvc')));
    await tester.pumpAndSettle();
    final viewCvcGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('hold-view-cvc'))),
    );
    await tester.pump();
    expect(find.text('123'), findsOneWidget);
    await viewCvcGesture.up();
    await tester.pumpAndSettle();
    expect(find.text('***'), findsOneWidget);
    expect(find.text('123'), findsNothing);

    await tester.tap(find.byTooltip('Close card view'));
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('view-card-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Card number'), findsOneWidget);

    await tester.tap(find.byTooltip('Close card view'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('favorites-card-carousel')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Campus ID'), findsWidgets);
    expect(find.text('Student ID'), findsWidgets);
    expect(find.text('Akator Academy'), findsNothing);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-credit_debit_cards')),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-passport_id')),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('overview-filter-student_ids')),
    );
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), [
      'demo-credit-card',
      'demo-student-id',
      'demo-personal-id',
      'demo-health-insurance',
      'demo-loyalty-card',
      'demo-driving-license',
      'demo-dc-library-card',
      'demo-customer-loyalty-cards',
      'demo-delta-skymiles-card',
    ]);

    await tapVisible(
      tester,
      find.byKey(const ValueKey('view-overview-card-demo-health-insurance')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailSheet), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Medicare Sample'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Medicare Sample'), findsOneWidget);
    expect(find.text('Delete card'), findsOneWidget);

    await tester.tap(find.text('Delete card'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure to delete the card?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(overviewCardIds(tester), [
      'demo-credit-card',
      'demo-student-id',
      'demo-personal-id',
      'demo-loyalty-card',
      'demo-driving-license',
      'demo-dc-library-card',
      'demo-customer-loyalty-cards',
      'demo-delta-skymiles-card',
    ]);
    expect(
      find.byKey(const ValueKey('overview-filter-health_insurance')),
      findsNothing,
    );

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
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
  });
}

Finder findAssetImage(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName,
  );
}

List<String> overviewCardIds(WidgetTester tester) {
  final grid = find.byType(OverviewCardGrid);
  if (grid.evaluate().isEmpty) {
    return [];
  }

  return tester
      .widget<OverviewCardGrid>(grid)
      .cards
      .map((card) => card.id)
      .toList();
}

List<String> visibleOverviewFilterIds(WidgetTester tester) {
  return tester
      .widgetList<OverviewFilterChip>(find.byType(OverviewFilterChip))
      .map((chip) => chip.filter.id)
      .toList();
}

void expectOverviewFilterMapping() {
  final filters = {for (final filter in overviewFilters) filter.id: filter};

  expect(filters['passport_id']!.matchedTypes, {WalletCardType.personalId});
  expect(filters['credit_debit_cards']!.matchedTypes, {
    WalletCardType.creditCard,
  });
  expect(filters['student_ids']!.matchedTypes, {WalletCardType.studentId});
  expect(filters['health_insurance']!.matchedTypes, {
    WalletCardType.healthInsurance,
  });
  expect(filters['loyalty_cards']!.matchedTypes, {WalletCardType.loyaltyCard});
  expect(filters['driver_licenses']!.matchedTypes, {
    WalletCardType.drivingLicense,
  });
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
