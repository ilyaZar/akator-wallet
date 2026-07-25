import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:akator_wallet/main.dart';
import 'package:akator_wallet/remote_storage.dart';
import 'package:akator_wallet/wallet_card_store.dart';

void main() {
  testWidgets('browses remote folders and selects an image', (tester) async {
    final storage = FakeRemoteStorage();
    RemoteStorageEntry? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    selected = await showRemoteImageBrowser(
                      context,
                      storage: storage,
                      provider: CardImageProvider.syncthing,
                      selectImage: true,
                    );
                  },
                  child: const Text('Browse'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('Syncthing host'), findsOneWidget);
    expect(find.text('cards'), findsOneWidget);

    await tester.tap(find.text('cards'));
    await tester.pumpAndSettle();
    expect(find.text('cards/front.png'), findsNothing);
    expect(find.text('front.png'), findsOneWidget);

    await tester.tap(find.text('front.png'));
    await tester.pumpAndSettle();
    expect(selected?.path, 'cards/front.png');
    expect(storage.listedPaths, ['', 'cards']);
  });

  testWidgets('shows a useful unavailable state and retries', (tester) async {
    final storage = FakeRemoteStorage(failLists: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteImageBrowser(
            storage: storage,
            provider: CardImageProvider.protonDrive,
            selectImage: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('The selected host backend is unavailable.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(storage.listedPaths, ['', '']);
  });

  testWidgets('renders a remote reference through the backend client', (
    tester,
  ) async {
    final storage = FakeRemoteStorage();
    final image = CardImageRef.remote(
      path: 'cards/front.png',
      provider: CardImageProvider.syncthing,
      displayName: 'front.png',
      mimeType: 'image/png',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteStorageScope(
          storage: storage,
          child: Scaffold(
            body: RemoteWalletImage(image: image, fit: BoxFit.cover),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(storage.readPaths, ['cards/front.png']);
  });

  testWidgets('keeps remote storage available in the zoom route', (
    tester,
  ) async {
    final storage = FakeRemoteStorage();
    final image = CardImageRef.remote(
      path: 'cards/front.png',
      provider: CardImageProvider.syncthing,
      displayName: 'front.png',
      mimeType: 'image/png',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteStorageScope(
          storage: storage,
          child: Builder(
            builder:
                (context) => FilledButton(
                  onPressed: () => showCardImageZoom(context, image),
                  child: const Text('Zoom'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Zoom'));
    await tester.pumpAndSettle();

    expect(find.byType(CardImageZoomView), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(storage.readPaths, ['cards/front.png']);
  });

  testWidgets('keeps remote storage available in card detail sheets', (
    tester,
  ) async {
    final storage = FakeRemoteStorage();
    final image = CardImageRef.remote(
      path: 'cards/front.png',
      provider: CardImageProvider.syncthing,
      displayName: 'front.png',
      mimeType: 'image/png',
    );
    final template = const CardTemplate(
      type: WalletCardType.creditCard,
      label: 'Credit card',
      fields: [],
    );
    final card = WalletCard(
      id: 'remote-card',
      type: WalletCardType.creditCard,
      title: 'Remote card',
      subtitle: 'Credit card',
      image: image,
      images: [image],
      accent: '#3370E4',
      fields: const {},
      assetSource: const {},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RemoteStorageScope(
          storage: storage,
          child: Scaffold(
            body: CardDetailSheet(
              card: card,
              template: template,
              onSetMainImage: (card, _) => card,
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsWidgets);
    expect(storage.readPaths, isNotEmpty);
    expect(
      storage.readPaths.every((path) => path == 'cards/front.png'),
      isTrue,
    );
  });
}

class FakeRemoteStorage implements RemoteStorage {
  FakeRemoteStorage({this.failLists = false});

  final bool failLists;
  final List<String> listedPaths = [];
  final List<String> readPaths = [];

  @override
  Future<RemoteStorageHealth> health() async {
    return const RemoteStorageHealth(
      apiVersion: 1,
      backends: {
        CardImageProvider.syncthing: true,
        CardImageProvider.protonDrive: true,
      },
      statuses: {
        CardImageProvider.syncthing: 'ok',
        CardImageProvider.protonDrive: 'ok',
      },
    );
  }

  @override
  Future<List<RemoteStorageEntry>> list(
    CardImageProvider provider, {
    String path = '',
  }) async {
    listedPaths.add(path);
    if (failLists) {
      throw const RemoteStorageException('backend_unavailable');
    }
    if (path.isEmpty) {
      return const [
        RemoteStorageEntry(
          path: 'cards',
          name: 'cards',
          kind: 'folder',
          mimeType: '',
          size: 0,
        ),
      ];
    }
    return const [
      RemoteStorageEntry(
        path: 'cards/front.png',
        name: 'front.png',
        kind: 'image',
        mimeType: 'image/png',
        size: 68,
      ),
    ];
  }

  @override
  Future<Uint8List> read(CardImageProvider provider, String path) async {
    readPaths.add(path);
    return Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0l'
        'EQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
      ),
    );
  }

  @override
  Future<RemoteStorageEntry> write(
    CardImageProvider provider,
    String path,
    Uint8List data,
  ) async {
    return RemoteStorageEntry(
      path: path,
      name: path.split('/').last,
      kind: 'image',
      mimeType: 'image/png',
      size: data.length,
    );
  }
}
