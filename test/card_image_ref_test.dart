import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  test('remote image refs store provider paths without connection secrets', () {
    final image = CardImageRef.remote(
      path: 'cards/front.png',
      provider: CardImageProvider.protonDrive,
      displayName: 'front.png',
      mimeType: 'image/png',
    );

    final restored = CardImageRef.fromJson(image.toJson());
    expect(restored, image);
    expect(restored.kind, CardImageKind.remote);
    expect(restored.uri, 'cards/front.png');
    expect(restored.toJson().toString(), isNot(contains('token')));
  });

  test('wallet connections store companion credentials securely', () {
    final connections = const WalletConnections(
      companionBaseUrl: 'https://wallet.example.test',
      companionAccessToken: '0123456789abcdef0123456789abcdef',
      legacySyncthingFolderUri: 'content://syncthing/tree/wallet-cards',
    );

    final restored = WalletConnections.fromJson(connections.toJson());
    expect(restored.companionConfigured, isTrue);
    expect(restored.legacySyncthingFolderUri, startsWith('content://'));

    final wiped = restored.copyWith(clearCompanion: true);
    expect(wiped.companionConfigured, isFalse);
    expect(wiped.legacySyncthingFolderUri, startsWith('content://'));
  });

  test(
    'wallet connection store persists the companion configuration',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const secureStorage = FlutterSecureStorage();
      const store = WalletConnectionStore(secureStorage: secureStorage);
      const connections = WalletConnections(
        companionBaseUrl: 'https://wallet.example.test',
        companionAccessToken: '0123456789abcdef0123456789abcdef',
      );

      await store.save(connections);
      final restored = await store.load();

      expect(restored.companionBaseUrl, connections.companionBaseUrl);
      expect(restored.companionAccessToken, connections.companionAccessToken);
      final stored = await secureStorage.readAll();
      expect(stored.keys, contains('akator_wallet_connections_v1'));
      expect(stored.keys, isNot(contains('akator_wallet_cards_v1')));
    },
  );

  test('connection status is driven by companion and backend health', () {
    final notConfigured = connectionStateFor(
      configured: false,
      available: false,
    );
    expect(notConfigured.label, 'Not configured');
    expect(notConfigured.detail, 'Set up host companion');
    expect(notConfigured.connected, isFalse);

    final unavailable = connectionStateFor(configured: true, available: false);
    expect(unavailable.label, 'Unavailable');
    expect(unavailable.detail, 'Check host companion');
    expect(unavailable.color, AkatorColors.danger);
    expect(unavailable.connected, isFalse);

    final connected = connectionStateFor(configured: true, available: true);
    expect(connected.label, 'Connected');
    expect(connected.detail, 'Show files or adjust settings');
    expect(connected.connected, isTrue);
  });
}
