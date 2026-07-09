import 'package:flutter_test/flutter_test.dart';

import 'package:akator_wallet/main.dart';
import 'package:akator_wallet/wallet_card_store.dart';

void main() {
  test('image refs use stable ids derived from uri text', () {
    expect(imageIdForUri('assets/cards/loyalty_card.jpg'), '5f1fb271');
    expect(
      imageIdForUri('content://provider/tree/wallet/document/card-crop.jpg'),
      'ed7f5f29',
    );
  });

  test('card image refs serialize asset and external uri images', () {
    final asset = CardImageRef.fromJson('assets/cards/loyalty_card.jpg');
    expect(asset.kind, CardImageKind.asset);
    expect(asset.provider, CardImageProvider.internal);
    expect(asset.mimeType, 'image/jpeg');

    final external = CardImageRef.externalUri(
      uri:
          'content://com.android.providers.media.documents/document/image%3A42',
      provider: CardImageProvider.syncthing,
      displayName: 'library-card.png',
      mimeType: 'image/png',
    );

    final restored = CardImageRef.fromJson(external.toJson());
    expect(restored, external);
    expect(restored.kind, CardImageKind.externalUri);
    expect(restored.provider, CardImageProvider.syncthing);
    expect(restored.displayName, 'library-card.png');
    expect(restored.mimeType, 'image/png');
  });

  test('wallet cards preserve primary external image ordering', () {
    final first = CardImageRef.asset('assets/cards/loyalty_card.jpg');
    final external = CardImageRef.externalUri(
      uri: 'content://provider/tree/wallet/document/card-crop.jpg',
      provider: CardImageProvider.protonDrive,
      displayName: 'card-crop.jpg',
      mimeType: 'image/jpeg',
    );

    final card = WalletCard(
      id: 'test-card',
      type: WalletCardType.loyaltyCard,
      title: 'Test Card',
      subtitle: 'Loyalty card',
      image: first,
      images: [first, external],
      accent: '#3370E4',
      fields: const {},
      assetSource: const {},
    ).withPrimaryImage(external);

    final restored = WalletCard.fromJson(card.toJson());
    expect(restored.primaryImage, external);
    expect(restored.images, [external, first]);
  });

  test('wallet connections store provider state without credentials', () {
    final connections = const WalletConnections(
      syncthingFolderUri: 'content://syncthing/tree/wallet-cards',
      protonDriveConnected: true,
    );

    final restored = WalletConnections.fromJson(connections.toJson());
    expect(restored.syncthingConnected, isTrue);
    expect(restored.protonDriveConnected, isTrue);

    final wiped = restored.copyWith(
      clearSyncthingFolderUri: true,
      protonDriveConnected: false,
    );
    expect(wiped.syncthingConnected, isFalse);
    expect(wiped.protonDriveConnected, isFalse);

    final payload = wiped.toJson().toString().toLowerCase();
    expect(payload, isNot(contains('password')));
    expect(payload, isNot(contains('credential')));
    expect(payload, isNot(contains('token')));
    expect(payload, isNot(contains('secret')));
  });

  test(
    'connection status is driven by provider availability and saved state',
    () {
      final notInstalled = connectionStateFor(
        available: false,
        connected: true,
      );
      expect(notInstalled.label, 'Not installed');
      expect(notInstalled.detail, 'Set up connection');
      expect(notInstalled.connected, isFalse);

      final disconnected = connectionStateFor(
        available: true,
        connected: false,
      );
      expect(disconnected.label, 'Disconnected');
      expect(disconnected.detail, 'Set up connection');
      expect(disconnected.color, AkatorColors.textHint);
      expect(disconnected.connected, isFalse);

      final connected = connectionStateFor(available: true, connected: true);
      expect(connected.label, 'Connected');
      expect(connected.detail, 'Show files or adjust settings');
      expect(connected.connected, isTrue);
    },
  );
}
