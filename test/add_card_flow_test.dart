import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akator_wallet/main.dart';
import 'package:akator_wallet/wallet_card_store.dart';

void main() {
  testWidgets('adds an image-backed card from the overview plus button', (
    tester,
  ) async {
    final draftImages = [
      'assets/cards/credit_card.png',
      'assets/cards/credit_card_2.png',
      'assets/cards/credit_card_3.png',
      'assets/cards/credit_card_4.png',
    ];
    var nextImage = 0;

    final bundle = await const WalletCardStore().load();
    await tester.pumpWidget(
      AddCardFlowHarness(
        initialBundle: bundle,
        pickCardImage: () async {
          return draftImages[nextImage++];
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('overview-add-card')),
    );
    expect(find.byType(AddCardSheet), findsOneWidget);
    expect(find.text('Make an image'), findsOneWidget);
    expect(find.text('Syncthing'), findsOneWidget);
    expect(find.text('Proton Drive'), findsOneWidget);

    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('add-card-path-proton-drive')),
    );
    expect(
      find.byKey(const ValueKey('add-card-type-selector')),
      findsOneWidget,
    );
    expect(find.text('Proton Drive connection placeholder'), findsOneWidget);

    await tapVisibleBounded(tester, find.byTooltip('Choose source'));
    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('add-card-path-image')),
    );
    expect(find.text('Make an image'), findsNothing);
    expect(find.text('Add up to four images'), findsOneWidget);
    expect(find.text('Add image'), findsOneWidget);
    expect(find.text('Images (0/4)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-new-card')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('add-card-type-selector')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Student ID').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('School'), findsOneWidget);
    expect(find.text('Student number'), findsOneWidget);
    expect(find.text('Card number'), findsNothing);

    await tester.enterText(textFieldByLabel('Full name'), 'Ada Student');
    await tester.enterText(textFieldByLabel('School'), 'Akator Academy');

    for (var i = 0; i < 4; i++) {
      await tapVisibleBounded(
        tester,
        find.byKey(const ValueKey('add-draft-image')),
      );
    }

    expect(find.byType(CardImageThumbnail), findsNWidgets(4));
    expect(find.text('Add image'), findsOneWidget);
    expect(find.text('Images (4/4)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('add-draft-image')))
          .onPressed,
      isNull,
    );

    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('card-image-thumb-draft-1')),
    );
    expect(find.text('Set as main image'), findsOneWidget);
    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('set-draft-main-image')),
    );
    expect(find.text('Main image'), findsOneWidget);
    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('set-draft-main-image')),
    );
    expect(find.text('already set as main image'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('already set as main image'), findsNothing);

    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('zoom-draft-main-image')),
    );
    expect(find.byType(CardImageZoomView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('zoom-image-assets/cards/credit_card_2.png')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close zoom'));
    await tester.pump(const Duration(milliseconds: 300));

    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('delete-draft-image-2')),
    );
    expect(find.byType(CardImageThumbnail), findsNWidgets(3));
    expect(find.text('Images (3/4)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-new-card')))
          .onPressed,
      isNotNull,
    );

    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('save-new-card')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AddCardSheet), findsNothing);
    expect(find.text('Ada Student'), findsOneWidget);
    expect(overviewCardIds(tester), hasLength(7));

    await tapVisibleBounded(
      tester,
      find.byKey(const ValueKey('overview-filter-student_ids')),
    );
    expect(find.text('Ada Student'), findsOneWidget);
    expect(overviewCardIds(tester), hasLength(2));
  });

  test('credit card validation supports common issuer lengths', () {
    final template = CardTemplate(
      type: WalletCardType.creditCard,
      label: 'Credit card',
      fields: [
        const CardFieldTemplate(
          key: 'expiration_date',
          label: 'Expiration date',
          input: 'month',
        ),
        const CardFieldTemplate(
          key: 'card_number',
          label: 'Card number',
          input: 'number',
        ),
        const CardFieldTemplate(key: 'cvc', label: 'CVC code', input: 'number'),
      ],
    );

    expect(formatPaymentCardNumber('4111111111111111'), '4111 1111 1111 1111');
    expect(formatExpirationDate('1229'), '12/29');
    expect(
      validationErrorsForTemplate(template, {
        'expiration_date': '12/29',
        'card_number': '4111 1111 1111 1111',
        'cvc': '123',
      }),
      isEmpty,
    );
    expect(
      validationErrorsForTemplate(template, {
        'expiration_date': '12/29',
        'card_number': '3782 822463 10005',
        'cvc': '1234',
      }),
      isEmpty,
    );
    expect(
      validationErrorsForTemplate(template, {
        'expiration_date': '12/29',
        'card_number': '3782 822463 10005',
        'cvc': '123',
      })['cvc'],
      'Use 4 digits',
    );
    expect(
      validationErrorsForTemplate(template, {
        'expiration_date': '13/29',
        'card_number': '4111 1111 1111 1111',
        'cvc': '123',
      })['expiration_date'],
      'Month must be 01-12',
    );
    expect(
      validationErrorsForTemplate(template, {
        'expiration_date': '12/29',
        'card_number': '4111 1111 1111',
        'cvc': '123',
      })['card_number'],
      'Use 13, 16, 19 digits for Visa',
    );
    final luhnWarningFields = {
      'expiration_date': '12/29',
      'card_number': '1234 1234 1234 1234',
      'cvc': '123',
    };
    expect(validationErrorsForTemplate(template, luhnWarningFields), isEmpty);
    expect(
      validationWarningsForTemplate(template, luhnWarningFields)['card_number'],
      'Luhn check not passed',
    );
  });
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

Future<void> tapVisibleBounded(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 120));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Finder textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

class AddCardFlowHarness extends StatefulWidget {
  const AddCardFlowHarness({
    required this.initialBundle,
    required this.pickCardImage,
    super.key,
  });

  final WalletCardBundle initialBundle;
  final PickCardImage pickCardImage;

  @override
  State<AddCardFlowHarness> createState() => _AddCardFlowHarnessState();
}

class _AddCardFlowHarnessState extends State<AddCardFlowHarness> {
  late WalletCardBundle _bundle;

  @override
  void initState() {
    super.initState();
    _bundle = widget.initialBundle;
  }

  void _openAddCard(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AkatorColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (context) => AddCardSheet(
            bundle: _bundle,
            pickCardImage: widget.pickCardImage,
            onSave: (card) {
              setState(() {
                _bundle = WalletCardBundle(
                  templates: _bundle.templates,
                  cards: [..._bundle.cards, card],
                );
              });
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  OverviewSection(
                    expanded: true,
                    bundle: _bundle,
                    onToggle: () {},
                    onView: (_, _) {},
                    onAdd: () => _openAddCard(context),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}
