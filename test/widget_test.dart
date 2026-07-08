import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akator_wallet/main.dart';

void main() {
  testWidgets('opens the draft menu and settings drawers', (tester) async {
    await tester.pumpWidget(const AkatorWalletApp());
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
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Explore: Security & Data'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.byTooltip('Cycle favorite card'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('view-card-image-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardDetailSheet), findsOneWidget);
    expect(find.byTooltip('Edit Akator Blue'), findsOneWidget);
    expect(find.byType(CardImageThumbnail), findsNWidgets(4));
    expect(
      tester
          .widgetList<CardImageThumbnail>(find.byType(CardImageThumbnail))
          .map((thumbnail) => thumbnail.image),
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
          .map((thumbnail) => thumbnail.image),
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

    await tester.tap(find.byTooltip('Close editor'));
    await tester.pumpAndSettle();
    expect(find.text('John Doe'), findsNothing);
    expect(findAssetImage('assets/cards/credit_card_2.png'), findsOneWidget);

    await tester.tap(
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
      find.byKey(const ValueKey('view-card-summary-demo-credit-card')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Card number'), findsOneWidget);

    await tester.tap(find.byTooltip('Close card view'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Campus ID'), findsWidgets);
    expect(find.text('Student ID'), findsWidgets);
    expect(find.text('Akator Academy'), findsNothing);

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

Finder findAssetImage(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName,
  );
}
