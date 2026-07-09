import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'wallet_card_store.dart';

void main() {
  runApp(const AkatorWalletApp());
}

typedef PickCardImage = Future<CardImageRef?> Function();

Future<CardImageRef?> pickCardImageFromCamera() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 92,
    maxWidth: 2400,
  );

  if (image == null) {
    return null;
  }

  final croppedImage = await cropCardImage(image.path);
  return CardImageRef.localFile(croppedImage?.path ?? image.path);
}

Future<CroppedFile?> cropCardImage(String sourcePath) {
  return ImageCropper().cropImage(
    sourcePath: sourcePath,
    maxWidth: 2400,
    maxHeight: 1519,
    aspectRatio: const CropAspectRatio(ratioX: 158, ratioY: 100),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop card image',
        toolbarColor: AkatorColors.primaryStrong,
        toolbarWidgetColor: AkatorColors.textInverted,
        activeControlsWidgetColor: AkatorColors.primaryStrong,
        cropFrameColor: AkatorColors.primaryStrong,
        cropGridColor: AkatorColors.primaryBorder,
        backgroundColor: AkatorColors.backgroundNorm,
        lockAspectRatio: true,
      ),
    ],
  );
}

Future<CardImageRef?> pickCardImageFromExternal({
  required AddCardSource source,
  required String? folderUri,
}) async {
  final provider = imageProviderForSource(source);
  final selection = await ExternalImageBridge.pickImage(initialUri: folderUri);
  if (selection == null) {
    return null;
  }

  final cachedPath = await ExternalImageBridge.cacheImage(
    selection.uri,
    selection.displayName,
  );
  if (cachedPath == null) {
    return CardImageRef.externalUri(
      uri: selection.uri,
      provider: provider,
      displayName: selection.displayName,
      mimeType: selection.mimeType,
    );
  }

  final croppedImage = await ImageCropper().cropImage(
    sourcePath: cachedPath,
    maxWidth: 2400,
    maxHeight: 1519,
    aspectRatio: const CropAspectRatio(ratioX: 158, ratioY: 100),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop card image',
        toolbarColor: AkatorColors.primaryStrong,
        toolbarWidgetColor: AkatorColors.textInverted,
        activeControlsWidgetColor: AkatorColors.primaryStrong,
        cropFrameColor: AkatorColors.primaryStrong,
        cropGridColor: AkatorColors.primaryBorder,
        backgroundColor: AkatorColors.backgroundNorm,
        lockAspectRatio: true,
      ),
    ],
  );

  if (croppedImage == null) {
    return CardImageRef.externalUri(
      uri: selection.uri,
      provider: provider,
      displayName: selection.displayName,
      mimeType: selection.mimeType,
    );
  }

  final saved = await ExternalImageBridge.saveCroppedImage(
    provider: provider,
    folderUri: folderUri,
    sourceUri: selection.uri,
    filePath: croppedImage.path,
    displayName: croppedDisplayName(selection.displayName),
    mimeType: selection.mimeType,
  );

  return CardImageRef.externalUri(
    uri: saved?.uri ?? selection.uri,
    provider: provider,
    displayName: saved?.displayName ?? selection.displayName,
    mimeType: saved?.mimeType ?? selection.mimeType,
  );
}

Widget walletImage(CardImageRef image, {Key? key, BoxFit fit = BoxFit.cover}) {
  if (image.kind == CardImageKind.asset) {
    return Image.asset(image.uri, key: key, fit: fit);
  }
  if (image.kind == CardImageKind.externalUri) {
    return ExternalWalletImage(image: image, key: key, fit: fit);
  }

  return Image.file(File(image.uri), key: key, fit: fit);
}

class ExternalImageSelection {
  const ExternalImageSelection({
    required this.uri,
    required this.displayName,
    required this.mimeType,
  });

  final String uri;
  final String displayName;
  final String mimeType;

  factory ExternalImageSelection.fromMap(Map<dynamic, dynamic> data) {
    return ExternalImageSelection(
      uri: data['uri'] as String,
      displayName:
          data['displayName'] as String? ??
          displayNameForUri(data['uri'] as String),
      mimeType: data['mimeType'] as String? ?? 'image/*',
    );
  }
}

class ExternalImageBridge {
  static const _channel = MethodChannel('com.akator.wallet/external_images');

  static Future<bool> isProviderAvailable(CardImageProvider provider) async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('isExternalProviderAvailable', {
          'provider': provider.storageKey,
        }) ??
        false;
  }

  static Future<String?> pickSyncthingFolder() async {
    if (!Platform.isAndroid) {
      return null;
    }
    return _channel.invokeMethod<String>('pickSyncthingFolder');
  }

  static Future<bool> openProviderFiles(
    CardImageProvider provider, {
    String? initialUri,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('openProviderFiles', {
          'provider': provider.storageKey,
          'initialUri': initialUri,
        }) ??
        false;
  }

  static Future<bool> openProviderApp(CardImageProvider provider) async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('openProviderApp', {
          'provider': provider.storageKey,
        }) ??
        false;
  }

  static Future<ExternalImageSelection?> pickImage({String? initialUri}) async {
    if (!Platform.isAndroid) {
      return null;
    }
    final data = await _channel.invokeMapMethod<String, Object?>(
      'pickExternalImage',
      {'initialUri': initialUri},
    );
    return data == null ? null : ExternalImageSelection.fromMap(data);
  }

  static Future<String?> cacheImage(String uri, String displayName) async {
    if (!Platform.isAndroid) {
      return null;
    }
    return _channel.invokeMethod<String>('cacheExternalImage', {
      'uri': uri,
      'displayName': displayName,
    });
  }

  static Future<ExternalImageSelection?> saveCroppedImage({
    required CardImageProvider provider,
    required String? folderUri,
    required String sourceUri,
    required String filePath,
    required String displayName,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }
    final data = await _channel
        .invokeMapMethod<String, Object?>('saveCroppedExternalImage', {
          'provider': provider.storageKey,
          'folderUri': folderUri,
          'sourceUri': sourceUri,
          'filePath': filePath,
          'displayName': displayName,
          'mimeType': mimeType,
        });
    return data == null ? null : ExternalImageSelection.fromMap(data);
  }

  static Future<Uint8List?> readImage(String uri) async {
    if (!Platform.isAndroid) {
      return null;
    }
    return _channel.invokeMethod<Uint8List>('readExternalImage', {'uri': uri});
  }
}

final _externalImageCache = <String, Future<Uint8List?>>{};

class ExternalWalletImage extends StatelessWidget {
  const ExternalWalletImage({
    required this.image,
    required this.fit,
    super.key,
  });

  final CardImageRef image;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bytes = _externalImageCache.putIfAbsent(
      image.uri,
      () => ExternalImageBridge.readImage(image.uri),
    );

    return FutureBuilder<Uint8List?>(
      future: bytes,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return Image.memory(data, fit: fit);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ColoredBox(color: AkatorColors.backgroundSecondary);
        }
        return const MissingCardImage();
      },
    );
  }
}

class MissingCardImage extends StatelessWidget {
  const MissingCardImage({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AkatorColors.backgroundSecondary),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AkatorColors.textHint,
          size: 28,
        ),
      ),
    );
  }
}

CardImageProvider imageProviderForSource(AddCardSource source) {
  return switch (source) {
    AddCardSource.image => CardImageProvider.internal,
    AddCardSource.syncthing => CardImageProvider.syncthing,
    AddCardSource.protonDrive => CardImageProvider.protonDrive,
  };
}

String croppedDisplayName(String displayName) {
  final dot = displayName.lastIndexOf('.');
  if (dot <= 0) {
    return '${displayName}_cropped.jpg';
  }
  return '${displayName.substring(0, dot)}_cropped${displayName.substring(dot)}';
}

class AkatorWalletApp extends StatelessWidget {
  const AkatorWalletApp({
    this.pickCardImage,
    this.cardStore,
    this.connectionStore,
    super.key,
  });

  final PickCardImage? pickCardImage;
  final WalletCardStore? cardStore;
  final WalletConnectionStore? connectionStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Akator Wallet',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AkatorColors.primary,
          brightness: Brightness.light,
        ).copyWith(surface: AkatorColors.backgroundSecondary),
        scaffoldBackgroundColor: AkatorColors.backgroundNorm,
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AkatorColors.textNorm,
          displayColor: AkatorColors.textNorm,
        ),
      ),
      home: WalletHomeScreen(
        pickCardImage: pickCardImage,
        cardStore: cardStore,
        connectionStore: connectionStore,
      ),
    );
  }
}

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({
    this.pickCardImage,
    this.cardStore,
    this.connectionStore,
    super.key,
  });

  final PickCardImage? pickCardImage;
  final WalletCardStore? cardStore;
  final WalletConnectionStore? connectionStore;

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final WalletConnectionStore _connectionStore;
  WalletConnections _connections = const WalletConnections();
  bool _syncthingAvailable = false;
  bool _protonDriveAvailable = false;
  bool _section1Open = true;
  bool _section2Open = true;
  bool _section3Open = true;

  @override
  void initState() {
    super.initState();
    _connectionStore = widget.connectionStore ?? const WalletConnectionStore();
    _refreshConnections();
  }

  Future<ConnectionSnapshot> _refreshConnections() async {
    final results = await Future.wait([
      _connectionStore.load(),
      ExternalImageBridge.isProviderAvailable(CardImageProvider.syncthing),
      ExternalImageBridge.isProviderAvailable(CardImageProvider.protonDrive),
    ]);
    final connections = results[0] as WalletConnections;
    final syncthingAvailable = results[1] as bool;
    final protonDriveAvailable = results[2] as bool;

    if (mounted) {
      setState(() {
        _connections = connections;
        _syncthingAvailable = syncthingAvailable;
        _protonDriveAvailable = protonDriveAvailable;
      });
    }

    return ConnectionSnapshot(
      connections: connections,
      syncthingAvailable: syncthingAvailable,
      protonDriveAvailable: protonDriveAvailable,
    );
  }

  Future<ConnectionSnapshot> _saveConnections(
    WalletConnections connections,
  ) async {
    await _connectionStore.save(connections);
    if (mounted) {
      setState(() => _connections = connections);
    }
    return _refreshConnections();
  }

  Future<ConnectionActionResult> _setupSyncthingConnection() async {
    final available = await ExternalImageBridge.isProviderAvailable(
      CardImageProvider.syncthing,
    );
    if (!available) {
      final snapshot = await _refreshConnections();
      return ConnectionActionResult(
        snapshot: snapshot,
        message: 'Syncthing is not installed on this device',
      );
    }

    final folderUri = await ExternalImageBridge.pickSyncthingFolder();
    if (folderUri == null) {
      final snapshot = await _refreshConnections();
      return ConnectionActionResult(snapshot: snapshot);
    }

    final snapshot = await _saveConnections(
      _connections.copyWith(syncthingFolderUri: folderUri),
    );
    return ConnectionActionResult(
      snapshot: snapshot,
      message: 'Syncthing folder connected',
    );
  }

  Future<ConnectionActionResult> _setupProtonDriveConnection() async {
    final available = await ExternalImageBridge.isProviderAvailable(
      CardImageProvider.protonDrive,
    );
    if (!available) {
      final snapshot = await _refreshConnections();
      return ConnectionActionResult(
        snapshot: snapshot,
        message: 'Proton Drive is not installed on this device',
      );
    }

    final snapshot = await _saveConnections(
      _connections.copyWith(protonDriveConnected: true),
    );
    return ConnectionActionResult(
      snapshot: snapshot,
      message: 'Proton Drive connected',
    );
  }

  Future<ConnectionActionResult> _deleteSyncthingConnection() async {
    final snapshot = await _saveConnections(
      _connections.copyWith(clearSyncthingFolderUri: true),
    );
    return ConnectionActionResult(
      snapshot: snapshot,
      message: 'Syncthing connection removed',
    );
  }

  Future<ConnectionActionResult> _deleteProtonDriveConnection() async {
    final snapshot = await _saveConnections(
      _connections.copyWith(protonDriveConnected: false),
    );
    return ConnectionActionResult(
      snapshot: snapshot,
      message: 'Proton Drive connection removed',
    );
  }

  Future<ConnectionActionResult> _showSyncthingFiles() {
    return _showProviderFiles(
      CardImageProvider.syncthing,
      folderUri: _connections.syncthingFolderUri,
      providerName: 'Syncthing',
    );
  }

  Future<ConnectionActionResult> _showProtonDriveFiles() {
    return _showProviderFiles(
      CardImageProvider.protonDrive,
      providerName: 'Proton Drive',
    );
  }

  Future<ConnectionActionResult> _showProviderFiles(
    CardImageProvider provider, {
    required String providerName,
    String? folderUri,
  }) async {
    final opened = await ExternalImageBridge.openProviderFiles(
      provider,
      initialUri: folderUri,
    );
    final snapshot = await _refreshConnections();
    return ConnectionActionResult(
      snapshot: snapshot,
      message: opened ? null : 'Could not open $providerName files',
    );
  }

  Future<ConnectionActionResult> _openSyncthingApp() {
    return _openProviderApp(
      CardImageProvider.syncthing,
      providerName: 'Syncthing',
    );
  }

  Future<ConnectionActionResult> _openProtonDriveApp() {
    return _openProviderApp(
      CardImageProvider.protonDrive,
      providerName: 'Proton Drive',
    );
  }

  Future<ConnectionActionResult> _openProviderApp(
    CardImageProvider provider, {
    required String providerName,
  }) async {
    final opened = await ExternalImageBridge.openProviderApp(provider);
    final snapshot = await _refreshConnections();
    return ConnectionActionResult(
      snapshot: snapshot,
      message: opened ? null : 'Could not open $providerName',
    );
  }

  void _updateSyncthingFolderUri(String folderUri) {
    unawaited(
      _saveConnections(_connections.copyWith(syncthingFolderUri: folderUri)),
    );
  }

  void _markProtonDriveUsed() {
    if (_connections.protonDriveConnected) {
      return;
    }
    unawaited(
      _saveConnections(_connections.copyWith(protonDriveConnected: true)),
    );
  }

  Future<void> _openConnectionsSheet() async {
    final snapshot = ConnectionSnapshot(
      connections: _connections,
      syncthingAvailable: _syncthingAvailable,
      protonDriveAvailable: _protonDriveAvailable,
    );
    unawaited(_refreshConnections());
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AkatorColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (context) => ConnectionsSheet(
            initialSnapshot: snapshot,
            onSetupSyncthing: _setupSyncthingConnection,
            onSetupProtonDrive: _setupProtonDriveConnection,
            onShowSyncthingFiles: _showSyncthingFiles,
            onShowProtonDriveFiles: _showProtonDriveFiles,
            onOpenSyncthingApp: _openSyncthingApp,
            onOpenProtonDriveApp: _openProtonDriveApp,
            onDeleteSyncthing: _deleteSyncthingConnection,
            onDeleteProtonDrive: _deleteProtonDriveConnection,
          ),
    );
    unawaited(_refreshConnections());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: WalletTopBar(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onSettingsPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
      ),
      drawer: WalletMenuDrawer(
        connections: _connections,
        syncthingAvailable: _syncthingAvailable,
        protonDriveAvailable: _protonDriveAvailable,
        onClose: () => Navigator.of(context).pop(),
        onConnectionsPressed: _openConnectionsSheet,
      ),
      endDrawer: WalletSettingsDrawer(
        connections: _connections,
        syncthingAvailable: _syncthingAvailable,
        protonDriveAvailable: _protonDriveAvailable,
        onClose: () => Navigator.of(context).pop(),
        onConnectionsPressed: _openConnectionsSheet,
      ),
      body: WalletDashboard(
        pickCardImage: widget.pickCardImage ?? pickCardImageFromCamera,
        cardStore: widget.cardStore ?? const WalletCardStore(),
        syncthingFolderUri: _connections.syncthingFolderUri,
        onSyncthingFolderPicked: _updateSyncthingFolderUri,
        onProtonDriveUsed: _markProtonDriveUsed,
        section1Open: _section1Open,
        section2Open: _section2Open,
        section3Open: _section3Open,
        onSection1Toggle:
            () => setState(() {
              _section1Open = !_section1Open;
            }),
        onSection2Toggle:
            () => setState(() {
              _section2Open = !_section2Open;
            }),
        onSection3Toggle:
            () => setState(() {
              _section3Open = !_section3Open;
            }),
      ),
    );
  }
}

class WalletTopBar extends StatelessWidget implements PreferredSizeWidget {
  const WalletTopBar({
    required this.onMenuPressed,
    required this.onSettingsPressed,
    super.key,
  });

  final VoidCallback onMenuPressed;
  final VoidCallback onSettingsPressed;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: AkatorColors.backgroundNorm,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 68,
      centerTitle: true,
      leading: Center(
        child: CircleIconButton(
          tooltip: 'Open wallet menu',
          icon: Icons.menu_rounded,
          onPressed: onMenuPressed,
        ),
      ),
      title: DecoratedBox(
        decoration: BoxDecoration(
          color: AkatorColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AkatorColors.appBarDividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Akator Wallet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: WalletStyles.headline(color: AkatorColors.textNorm),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: defaultPadding),
          child: CircleIconButton(
            tooltip: 'Open settings',
            icon: Icons.settings_rounded,
            onPressed: onSettingsPressed,
          ),
        ),
      ],
    );
  }
}

class WalletDashboard extends StatefulWidget {
  const WalletDashboard({
    required this.pickCardImage,
    required this.section1Open,
    required this.section2Open,
    required this.section3Open,
    required this.onSection1Toggle,
    required this.onSection2Toggle,
    required this.onSection3Toggle,
    required this.cardStore,
    required this.syncthingFolderUri,
    required this.onSyncthingFolderPicked,
    required this.onProtonDriveUsed,
    super.key,
  });

  final PickCardImage pickCardImage;
  final WalletCardStore cardStore;
  final String? syncthingFolderUri;
  final ValueChanged<String> onSyncthingFolderPicked;
  final VoidCallback onProtonDriveUsed;
  final bool section1Open;
  final bool section2Open;
  final bool section3Open;
  final VoidCallback onSection1Toggle;
  final VoidCallback onSection2Toggle;
  final VoidCallback onSection3Toggle;

  @override
  State<WalletDashboard> createState() => _WalletDashboardState();
}

class _WalletDashboardState extends State<WalletDashboard> {
  WalletCardBundle? _cardBundle;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final bundle = await widget.cardStore.load();
    if (!mounted) {
      return;
    }

    setState(() => _cardBundle = bundle);
  }

  Future<void> _editCard(WalletCard card, CardTemplate template) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AkatorColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (context) => EditCardSheet(
            card: card,
            template: template,
            onSave: (fields) => _saveCardFields(card, fields),
            onDelete: () {
              _deleteCard(card);
              Navigator.of(context).pop();
            },
          ),
    );
  }

  Future<void> _addCard() async {
    final bundle = _cardBundle;
    if (bundle == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AkatorColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (context) => AddCardSheet(
            bundle: bundle,
            pickCardImage: widget.pickCardImage,
            syncthingFolderUri: widget.syncthingFolderUri,
            onSyncthingFolderPicked: widget.onSyncthingFolderPicked,
            onProtonDriveUsed: widget.onProtonDriveUsed,
            onSave: _insertCard,
          ),
    );
  }

  void _insertCard(WalletCard card) {
    final bundle = _cardBundle;
    if (bundle == null) {
      return;
    }

    final cards = [...bundle.cards, card];
    setState(() {
      _cardBundle = WalletCardBundle(templates: bundle.templates, cards: cards);
    });
    unawaited(widget.cardStore.saveCards(cards));
  }

  void _saveCardFields(WalletCard card, Map<String, String> fields) {
    final bundle = _cardBundle;
    if (bundle == null) {
      return;
    }

    final cards = [...bundle.cards];
    final index = cards.indexWhere((item) => item.id == card.id);
    if (index == -1) {
      return;
    }

    cards[index] = cards[index].copyWith(fields: fields);
    setState(() {
      _cardBundle = WalletCardBundle(templates: bundle.templates, cards: cards);
    });
    unawaited(widget.cardStore.saveCards(cards));
  }

  void _deleteCard(WalletCard card) {
    final bundle = _cardBundle;
    if (bundle == null) {
      return;
    }

    final cards = [
      for (final item in bundle.cards)
        if (item.id != card.id) item,
    ];
    setState(() {
      _cardBundle = WalletCardBundle(templates: bundle.templates, cards: cards);
    });
    unawaited(widget.cardStore.saveCards(cards));
  }

  WalletCard _setMainImage(WalletCard card, CardImageRef image) {
    final updatedCard = card.withPrimaryImage(image);

    if (_cardBundle == null) {
      return updatedCard;
    }

    final cards = [..._cardBundle!.cards];
    final index = cards.indexWhere((item) => item.id == card.id);
    if (index == -1) {
      return updatedCard;
    }

    cards[index] = updatedCard;
    setState(() {
      _cardBundle = WalletCardBundle(
        templates: _cardBundle!.templates,
        cards: cards,
      );
    });
    unawaited(widget.cardStore.saveCards(cards));

    return updatedCard;
  }

  void _viewCard(WalletCard card, CardTemplate template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AkatorColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (context) => CardDetailSheet(
            card: card,
            template: template,
            onSetMainImage: _setMainImage,
            onEdit: (currentCard) {
              Navigator.of(context).pop();
              _editCard(currentCard, template);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FavoritesSection(
                    expanded: widget.section1Open,
                    bundle: _cardBundle,
                    onToggle: widget.onSection1Toggle,
                    onView: _viewCard,
                  ),
                  const SizedBox(height: 16),
                  OverviewSection(
                    expanded: widget.section2Open,
                    bundle: _cardBundle,
                    onToggle: widget.onSection2Toggle,
                    onView: _viewCard,
                    onAdd: _addCard,
                  ),
                  const SizedBox(height: 16),
                  ExploreSection(
                    expanded: widget.section3Open,
                    onToggle: widget.onSection3Toggle,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FavoritesSection extends StatefulWidget {
  const FavoritesSection({
    required this.expanded,
    required this.bundle,
    required this.onToggle,
    required this.onView,
    super.key,
  });

  final bool expanded;
  final WalletCardBundle? bundle;
  final VoidCallback onToggle;
  final void Function(WalletCard card, CardTemplate template) onView;

  @override
  State<FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends State<FavoritesSection> {
  late final PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WalletSection(
      sectionLabel: 'Section 1',
      title: 'My favorites',
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      child: buildCardsContent(),
    );
  }

  Widget buildCardsContent() {
    final bundle = widget.bundle;
    if (bundle == null || bundle.cards.isEmpty) {
      return const FavoriteCarouselSkeleton();
    }

    final selectedIndex =
        _selectedIndex.clamp(0, bundle.cards.length - 1).toInt();

    return FavoriteCardCarousel(
      bundle: bundle,
      selectedIndex: selectedIndex,
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _selectedIndex = index);
      },
      onView: widget.onView,
    );
  }
}

class FavoriteCardCarousel extends StatelessWidget {
  const FavoriteCardCarousel({
    required this.bundle,
    required this.selectedIndex,
    required this.controller,
    required this.onPageChanged,
    required this.onView,
    super.key,
  });

  final WalletCardBundle bundle;
  final int selectedIndex;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final void Function(WalletCard card, CardTemplate template) onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            key: const ValueKey('favorites-card-carousel'),
            controller: controller,
            itemCount: bundle.cards.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return FavoriteCardPage(
                card: bundle.cards[index],
                index: index,
                selectedIndex: selectedIndex,
                controller: controller,
                onView:
                    () => onView(
                      bundle.cards[index],
                      bundle.templateFor(bundle.cards[index].type),
                    ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: FavoriteCardDots(
            count: bundle.cards.length,
            selectedIndex: selectedIndex,
          ),
        ),
      ],
    );
  }
}

class FavoriteCardPage extends StatelessWidget {
  const FavoriteCardPage({
    required this.card,
    required this.index,
    required this.selectedIndex,
    required this.controller,
    required this.onView,
    this.viewKeyPrefix = 'view-card-image',
    super.key,
  });

  final WalletCard card;
  final int index;
  final int selectedIndex;
  final PageController controller;
  final VoidCallback onView;
  final String viewKeyPrefix;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final page = currentCarouselPage(controller, selectedIndex);
        final distance = (page - index).abs().clamp(0.0, 1.0);
        final scale = 1 - (distance * 0.08);
        final lift = distance * 10;

        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: FavoriteCardFace(
          card: card,
          onView: onView,
          viewKeyPrefix: viewKeyPrefix,
        ),
      ),
    );
  }
}

class FavoriteCardFace extends StatelessWidget {
  const FavoriteCardFace({
    required this.card,
    required this.onView,
    this.viewKeyPrefix = 'view-card-image',
    super.key,
  });

  final WalletCard card;
  final VoidCallback onView;
  final String viewKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final accent = colorFromHex(card.accent);

    return Tooltip(
      message: 'View ${card.title}',
      child: Semantics(
        label: 'View ${card.title}',
        button: true,
        child: GestureDetector(
          key: ValueKey('$viewKeyPrefix-${card.id}'),
          onTap: onView,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: AkatorColors.loadingShadow,
                  blurRadius: 22,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1.58,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    walletImage(card.primaryImage, fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accent.withAlpha(20),
                            Colors.transparent,
                            Colors.black.withAlpha(165),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WalletStyles.body1Medium(
                              color: AkatorColors.textInverted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: WalletStyles.captionRegular(
                              color: AkatorColors.textInverted.withAlpha(220),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardDetailSheet extends StatefulWidget {
  const CardDetailSheet({
    required this.card,
    required this.template,
    required this.onSetMainImage,
    required this.onEdit,
    super.key,
  });

  final WalletCard card;
  final CardTemplate template;
  final WalletCard Function(WalletCard card, CardImageRef image) onSetMainImage;
  final ValueChanged<WalletCard> onEdit;

  @override
  State<CardDetailSheet> createState() => _CardDetailSheetState();
}

class _CardDetailSheetState extends State<CardDetailSheet> {
  late WalletCard _card;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
  }

  @override
  void didUpdateWidget(CardDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _card = widget.card;
    }
  }

  void _previewImage(CardImageRef image) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AkatorColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder:
          (sheetContext) => CardImagePreviewSheet(
            card: _card,
            image: image,
            onSetMainImage: () {
              final updatedCard = widget.onSetMainImage(_card, image);
              if (mounted) {
                setState(() => _card = updatedCard);
              }
              return updatedCard;
            },
          ),
    );
  }

  void _zoomImage(CardImageRef image) {
    showCardImageZoom(context, image);
  }

  @override
  Widget build(BuildContext context) {
    final images = _card.images.take(4).toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WalletStyles.subheadline(
                          color: AkatorColors.textNorm,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.template.label,
                        style: WalletStyles.captionRegular(
                          color: AkatorColors.textWeak,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close card view',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Tooltip(
                          message: 'Zoom main image',
                          child: GestureDetector(
                            key: ValueKey('zoom-card-main-image-${_card.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _zoomImage(_card.primaryImage),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AspectRatio(
                                aspectRatio: 1.58,
                                child: walletImage(
                                  _card.primaryImage,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (images.isNotEmpty)
                      CardImageSelectorRow(
                        card: _card,
                        images: images,
                        onSelect: _previewImage,
                      ),
                    const SizedBox(height: 18),
                    for (final field in widget.template.fields) ...[
                      ReadOnlyFieldRow(
                        field: field,
                        value: _card.fields[field.key] ?? '',
                      ),
                      if (field != widget.template.fields.last)
                        const Divider(
                          height: 22,
                          color: AkatorColors.appBarDividerColor,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filled(
                tooltip: 'Edit ${_card.title}',
                style: IconButton.styleFrom(
                  fixedSize: const Size(52, 52),
                  backgroundColor: AkatorColors.primaryStrong,
                  foregroundColor: AkatorColors.textInverted,
                ),
                onPressed: () => widget.onEdit(_card),
                icon: const Icon(Icons.edit_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardImageSelectorRow extends StatelessWidget {
  const CardImageSelectorRow({
    required this.card,
    required this.images,
    required this.onSelect,
    super.key,
  });

  final WalletCard card;
  final List<CardImageRef> images;
  final ValueChanged<CardImageRef> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          for (var index = 0; index < images.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: CardImageThumbnail(
                cardId: card.id,
                image: images[index],
                index: index,
                selected: images[index] == card.primaryImage,
                onTap: () => onSelect(images[index]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CardImageThumbnail extends StatelessWidget {
  const CardImageThumbnail({
    required this.cardId,
    required this.image,
    required this.index,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String cardId;
  final CardImageRef image;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Preview image ${index + 1}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('card-image-thumb-$cardId-$index'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AkatorColors.backgroundNorm,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    selected
                        ? AkatorColors.primaryStrong
                        : AkatorColors.appBarDividerColor,
                width: selected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: walletImage(image, fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CardImagePreviewSheet extends StatefulWidget {
  const CardImagePreviewSheet({
    required this.card,
    required this.image,
    required this.onSetMainImage,
    super.key,
  });

  final WalletCard card;
  final CardImageRef image;
  final WalletCard Function() onSetMainImage;

  @override
  State<CardImagePreviewSheet> createState() => _CardImagePreviewSheetState();
}

class _CardImagePreviewSheetState extends State<CardImagePreviewSheet> {
  late bool _isMainImage;
  bool _showAlreadySetMessage = false;
  int _messageVersion = 0;

  @override
  void initState() {
    super.initState();
    _isMainImage = widget.card.primaryImage == widget.image;
  }

  @override
  void didUpdateWidget(CardImagePreviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.image != widget.image) {
      _isMainImage = widget.card.primaryImage == widget.image;
      _showAlreadySetMessage = false;
    }
  }

  void _handleSetMainImage() {
    if (_isMainImage) {
      _showAlreadySetNotice();
      return;
    }

    final updatedCard = widget.onSetMainImage();
    setState(() {
      _isMainImage = updatedCard.primaryImage == widget.image;
      _showAlreadySetMessage = false;
      _messageVersion++;
    });
  }

  void _showAlreadySetNotice() {
    final version = ++_messageVersion;
    setState(() => _showAlreadySetMessage = true);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || version != _messageVersion) {
        return;
      }
      setState(() => _showAlreadySetMessage = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageIndex = widget.card.images.indexOf(widget.image) + 1;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.card.title} image $imageIndex',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WalletStyles.subheadline(
                      color: AkatorColors.textNorm,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close image preview',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Tooltip(
                message: 'Zoom image',
                child: GestureDetector(
                  key: ValueKey('zoom-preview-image-${widget.card.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showCardImageZoom(context, widget.image),
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: walletImage(widget.image, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child:
                  _showAlreadySetMessage
                      ? Padding(
                        key: const ValueKey('already-set-message'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'already set as main image',
                            style: WalletStyles.captionRegular(
                              color: AkatorColors.success,
                            ),
                          ),
                        ),
                      )
                      : const SizedBox.shrink(
                        key: ValueKey('already-set-message-empty'),
                      ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: MainImageButton(
                key: ValueKey('set-main-image-${widget.card.id}'),
                isMainImage: _isMainImage,
                onPressed: _handleSetMainImage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCardImageZoom(BuildContext context, CardImageRef image) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => CardImageZoomView(image: image),
    ),
  );
}

class CardImageZoomView extends StatelessWidget {
  const CardImageZoomView({required this.image, super.key});

  final CardImageRef image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  key: const ValueKey('card-image-zoom-viewer'),
                  minScale: 1,
                  maxScale: 6,
                  boundaryMargin: const EdgeInsets.all(160),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Center(
                      child: walletImage(
                        image,
                        key: ValueKey('zoom-image-${image.uri}'),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton.filled(
                  tooltip: 'Close zoom',
                  style: IconButton.styleFrom(
                    backgroundColor: AkatorColors.backgroundNorm,
                    foregroundColor: AkatorColors.textNorm,
                    fixedSize: const Size(52, 52),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MainImageButton extends StatelessWidget {
  const MainImageButton({
    required this.isMainImage,
    required this.onPressed,
    super.key,
  });

  final bool isMainImage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor:
          isMainImage ? AkatorColors.success : AkatorColors.backgroundNorm,
      foregroundColor:
          isMainImage ? AkatorColors.textInverted : AkatorColors.textNorm,
      side: BorderSide(
        color:
            isMainImage
                ? AkatorColors.successBorder
                : AkatorColors.appBarDividerColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    if (isMainImage) {
      return FilledButton.icon(
        style: style,
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Main image'),
      );
    }

    return FilledButton(
      style: style,
      onPressed: onPressed,
      child: const Text('Set as main image'),
    );
  }
}

class ReadOnlyFieldRow extends StatelessWidget {
  const ReadOnlyFieldRow({required this.field, required this.value, super.key});

  final CardFieldTemplate field;
  final String value;

  @override
  Widget build(BuildContext context) {
    final sensitive = isSensitiveField(field);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(
            field.label,
            style: WalletStyles.body2Medium(color: AkatorColors.textHint),
          ),
        ),
        Expanded(
          child:
              sensitive
                  ? SensitiveReadOnlyValue(field: field, value: value)
                  : Text(
                    value,
                    style: WalletStyles.body1Medium(
                      color: AkatorColors.textNorm,
                    ),
                  ),
        ),
      ],
    );
  }
}

class SensitiveReadOnlyValue extends StatefulWidget {
  const SensitiveReadOnlyValue({
    required this.field,
    required this.value,
    super.key,
  });

  final CardFieldTemplate field;
  final String value;

  @override
  State<SensitiveReadOnlyValue> createState() => _SensitiveReadOnlyValueState();
}

class _SensitiveReadOnlyValueState extends State<SensitiveReadOnlyValue> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _visible ? widget.value : '***',
            style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
          ),
        ),
        HoldToRevealButton(
          revealKey: ValueKey('hold-view-${widget.field.key}'),
          label: widget.field.label,
          onChanged: (visible) => setState(() => _visible = visible),
        ),
      ],
    );
  }
}

class SensitiveFieldText extends StatefulWidget {
  const SensitiveFieldText({
    required this.field,
    required this.controller,
    this.errorText,
    this.warningText,
    super.key,
  });

  final CardFieldTemplate field;
  final TextEditingController controller;
  final String? errorText;
  final String? warningText;

  @override
  State<SensitiveFieldText> createState() => _SensitiveFieldTextState();
}

class _SensitiveFieldTextState extends State<SensitiveFieldText> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final sensitive = isSensitiveField(widget.field);
    final warningText = widget.errorText == null ? widget.warningText : null;

    return TextField(
      controller: widget.controller,
      keyboardType: keyboardForField(widget.field),
      inputFormatters: inputFormattersForField(widget.field),
      obscureText: sensitive && !_visible,
      decoration: InputDecoration(
        labelText: widget.field.label,
        hintText: hintForField(widget.field),
        errorText: widget.errorText,
        helperText: warningText,
        helperStyle: WalletStyles.captionRegular(color: AkatorColors.warning),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: AkatorColors.fieldValidBorder,
            width: 2,
          ),
        ),
        suffixIcon:
            sensitive
                ? HoldToRevealButton(
                  revealKey: ValueKey('hold-edit-${widget.field.key}'),
                  label: widget.field.label,
                  onChanged: (visible) => setState(() => _visible = visible),
                )
                : warningText != null
                ? IconButton(
                  key: ValueKey('field-warning-${widget.field.key}'),
                  tooltip: warningText,
                  onPressed: () => showLuhnWarningDialog(context),
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: AkatorColors.warning,
                  ),
                )
                : null,
      ),
    );
  }
}

Future<void> showLuhnWarningDialog(BuildContext context) {
  const infoUri = 'https://en.wikipedia.org/wiki/Luhn_algorithm';

  return showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Luhn check warning'),
          content: const Text(
            'This checksum is useful for catching typing mistakes, but the '
            'wallet does not enforce it. You can still save this card number.\n\n'
            'More information: $infoUri',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.maybeOf(context);

                navigator.pop();
                final opened = await launchUrl(
                  Uri.parse(infoUri),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened) {
                  messenger?.showSnackBar(
                    const SnackBar(content: Text('Could not open article')),
                  );
                }
              },
              child: const Text('Open article'),
            ),
          ],
        ),
  );
}

class HoldToRevealButton extends StatelessWidget {
  const HoldToRevealButton({
    required this.revealKey,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final Key revealKey;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Hold to show $label',
      child: Semantics(
        button: true,
        label: 'Hold to show $label',
        child: Listener(
          key: revealKey,
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => onChanged(true),
          onPointerUp: (_) => onChanged(false),
          onPointerCancel: (_) => onChanged(false),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.info_outline_rounded),
          ),
        ),
      ),
    );
  }
}

class FavoriteCardDots extends StatelessWidget {
  const FavoriteCardDots({
    required this.count,
    required this.selectedIndex,
    super.key,
  });

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: i == selectedIndex ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color:
                  i == selectedIndex
                      ? AkatorColors.primaryStrong
                      : AkatorColors.primaryBorder,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class EditCardSheet extends StatefulWidget {
  const EditCardSheet({
    required this.card,
    required this.template,
    required this.onSave,
    required this.onDelete,
    super.key,
  });

  final WalletCard card;
  final CardTemplate template;
  final ValueChanged<Map<String, String>> onSave;
  final VoidCallback onDelete;

  @override
  State<EditCardSheet> createState() => _EditCardSheetState();
}

class _EditCardSheetState extends State<EditCardSheet> {
  late final Map<String, TextEditingController> _controllers;
  late Map<String, String> _savedFields;
  bool _saved = false;
  bool _showAlreadySavedMessage = false;
  int _saveMessageVersion = 0;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.template.fields)
        field.key: TextEditingController(
          text: widget.card.fields[field.key] ?? '',
        ),
    };
    _savedFields = _currentFields();
    for (final controller in _controllers.values) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> _currentFields() {
    return {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
  }

  Map<String, String> _validationErrors() {
    return validationErrorsForTemplate(widget.template, _currentFields());
  }

  Map<String, String> _validationWarnings() {
    return validationWarningsForTemplate(widget.template, _currentFields());
  }

  void _markDirty() {
    final fields = _currentFields();
    setState(() {
      if (_saved && !mapsEqual(fields, _savedFields)) {
        _saved = false;
        _showAlreadySavedMessage = false;
        _saveMessageVersion++;
      }
    });
  }

  void _handleSave() {
    final fields = _currentFields();
    if (_validationErrors().isNotEmpty) {
      return;
    }

    if (_saved && mapsEqual(fields, _savedFields)) {
      _showAlreadySavedNotice();
      return;
    }

    widget.onSave(fields);
    setState(() {
      _savedFields = fields;
      _saved = true;
      _showAlreadySavedMessage = false;
      _saveMessageVersion++;
    });
  }

  void _showAlreadySavedNotice() {
    final version = ++_saveMessageVersion;
    setState(() => _showAlreadySavedMessage = true);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || version != _saveMessageVersion) {
        return;
      }
      setState(() => _showAlreadySavedMessage = false);
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete card'),
            content: const Text('Are you sure to delete the card?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AkatorColors.danger,
                  foregroundColor: AkatorColors.textInverted,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final validationErrors = _validationErrors();
    final validationWarnings = _validationWarnings();
    final canSave = validationErrors.isEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Edit ${widget.card.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: WalletStyles.subheadline(
                          color: AkatorColors.textNorm,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.template.label,
                        style: WalletStyles.captionRegular(
                          color: AkatorColors.textWeak,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close editor',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final field in widget.template.fields) ...[
              SensitiveFieldText(
                field: field,
                controller: _controllers[field.key]!,
                errorText: validationErrors[field.key],
                warningText: validationWarnings[field.key],
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child:
                  _showAlreadySavedMessage
                      ? Padding(
                        key: const ValueKey('already-saved-message'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Changes already saved',
                            style: WalletStyles.captionRegular(
                              color: AkatorColors.success,
                            ),
                          ),
                        ),
                      )
                      : const SizedBox.shrink(
                        key: ValueKey('already-saved-message-empty'),
                      ),
            ),
            SizedBox(
              width: double.infinity,
              child: SaveChangesButton(
                saved: _saved,
                onPressed: canSave ? _handleSave : null,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AkatorColors.danger,
                  foregroundColor: AkatorColors.textInverted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: _confirmDelete,
                child: const Text('Delete card'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SaveChangesButton extends StatelessWidget {
  const SaveChangesButton({
    required this.saved,
    required this.onPressed,
    super.key,
  });

  final bool saved;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            saved ? AkatorColors.success : AkatorColors.primaryStrong,
        foregroundColor: AkatorColors.textInverted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      onPressed: onPressed,
      child: const Text('Save changes'),
    );
  }
}

enum AddCardSource { image, syncthing, protonDrive }

String addCardSourceLabel(AddCardSource source) {
  return switch (source) {
    AddCardSource.image => 'Make an image',
    AddCardSource.syncthing => 'Syncthing',
    AddCardSource.protonDrive => 'Proton Drive',
  };
}

String unavailableExternalSourceMessage(AddCardSource source) {
  return switch (source) {
    AddCardSource.image => '',
    AddCardSource.syncthing =>
      'Syncthing is not installed on this device. Install Syncthing-Fork and sync a local folder first.',
    AddCardSource.protonDrive =>
      'Proton Drive is not installed on this device. Install Proton Drive and sign in, then try again.',
  };
}

IconData iconForAddSource(AddCardSource source) {
  return switch (source) {
    AddCardSource.image => Icons.photo_camera_rounded,
    AddCardSource.syncthing => Icons.sync_rounded,
    AddCardSource.protonDrive => Icons.cloud_outlined,
  };
}

class AddCardSheet extends StatefulWidget {
  const AddCardSheet({
    required this.bundle,
    required this.pickCardImage,
    required this.onSave,
    this.syncthingFolderUri,
    this.onSyncthingFolderPicked,
    this.onProtonDriveUsed,
    super.key,
  });

  final WalletCardBundle bundle;
  final PickCardImage pickCardImage;
  final ValueChanged<WalletCard> onSave;
  final String? syncthingFolderUri;
  final ValueChanged<String>? onSyncthingFolderPicked;
  final VoidCallback? onProtonDriveUsed;

  @override
  State<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<AddCardSheet> {
  AddCardSource? _source;
  late CardTemplate _template;
  late Map<String, TextEditingController> _controllers;
  final List<CardImageRef> _images = [];
  CardImageRef? _selectedImage;
  CardImageRef? _mainImage;
  String? _syncthingFolderUri;
  String? _sourceError;
  bool _pickingImage = false;

  @override
  void initState() {
    super.initState();
    _syncthingFolderUri = widget.syncthingFolderUri;
    _template = widget.bundle.templates.first;
    _controllers = controllersForTemplate(
      _template,
      onChanged: _handleFieldChanged,
    );
  }

  @override
  void dispose() {
    disposeControllers(_controllers, onChanged: _handleFieldChanged);
    super.dispose();
  }

  void _handleFieldChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _chooseSource(AddCardSource source) {
    setState(() {
      _source = source;
      _sourceError = null;
    });
  }

  void _changeTemplate(WalletCardType? type) {
    if (type == null || type == _template.type) {
      return;
    }

    final nextTemplate = widget.bundle.templateFor(type);
    disposeControllers(_controllers, onChanged: _handleFieldChanged);
    setState(() {
      _template = nextTemplate;
      _controllers = controllersForTemplate(
        nextTemplate,
        onChanged: _handleFieldChanged,
      );
    });
  }

  Future<void> _addImage() async {
    final source = _source;
    if (source == null || _images.length >= 4 || _pickingImage) {
      return;
    }

    setState(() {
      _pickingImage = true;
      _sourceError = null;
    });

    CardImageRef? image;
    try {
      if (source == AddCardSource.image) {
        image = await widget.pickCardImage();
      } else {
        final providerAvailable = await ExternalImageBridge.isProviderAvailable(
          imageProviderForSource(source),
        );
        if (!mounted) {
          return;
        }

        if (!providerAvailable) {
          _sourceError = unavailableExternalSourceMessage(source);
        } else {
          var folderUri = _syncthingFolderUri;
          if (source == AddCardSource.syncthing && folderUri == null) {
            folderUri = await ExternalImageBridge.pickSyncthingFolder();
            if (!mounted) {
              return;
            }
            _syncthingFolderUri = folderUri;
            if (folderUri != null) {
              widget.onSyncthingFolderPicked?.call(folderUri);
            }
          }

          if (source != AddCardSource.syncthing || folderUri != null) {
            image = await pickCardImageFromExternal(
              source: source,
              folderUri: folderUri,
            );
          }
        }
      }
    } on PlatformException catch (error) {
      _sourceError = error.message ?? 'Could not open external storage';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pickingImage = false;
      if (image == null || _images.length >= 4) {
        return;
      }
      if (source == AddCardSource.protonDrive) {
        widget.onProtonDriveUsed?.call();
      }
      _images.add(image);
      _selectedImage ??= image;
      _mainImage ??= image;
    });
  }

  void _selectImage(CardImageRef image) {
    setState(() => _selectedImage = image);
  }

  void _setSelectedAsMainImage() {
    final image = _selectedImage;
    if (image == null) {
      return;
    }

    setState(() => _mainImage = image);
  }

  void _deleteImage(CardImageRef image) {
    setState(() {
      _images.remove(image);
      if (_mainImage == image) {
        _mainImage = _images.isEmpty ? null : _images.first;
      }
      if (_selectedImage == image) {
        _selectedImage = _mainImage ?? (_images.isEmpty ? null : _images.first);
      }
    });
  }

  void _saveCard() {
    final source = _source;
    if (source == null || !canSave) {
      return;
    }

    final fields = currentFields(_controllers);
    final image =
        _mainImage ??
        _selectedImage ??
        fallbackImageForType(widget.bundle, _template.type);
    final images =
        [
          image,
          for (final item in _images)
            if (item != image) item,
        ].take(4).toList();

    widget.onSave(
      WalletCard(
        id: 'draft-${DateTime.now().microsecondsSinceEpoch}',
        type: _template.type,
        title: titleForDraftCard(_template, fields),
        subtitle: _template.label,
        image: image,
        images: images,
        accent: '#3370E4',
        fields: fields,
        assetSource: {
          'title': addCardSourceLabel(source),
          'url': '',
          'credit': 'in-memory draft',
        },
      ),
    );
    Navigator.of(context).pop();
  }

  bool get canSave {
    final source = _source;
    if (source == null) {
      return false;
    }
    if (_images.isEmpty) {
      return false;
    }

    return validationErrorsForTemplate(
      _template,
      currentFields(_controllers),
    ).isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add card',
                    style: WalletStyles.subheadline(
                      color: AkatorColors.textNorm,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close add card',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child:
                  source == null
                      ? AddCardSourcePicker(onSelected: _chooseSource)
                      : SingleChildScrollView(
                        child: AddCardDraftForm(
                          source: source,
                          templates: widget.bundle.templates,
                          template: _template,
                          controllers: _controllers,
                          fieldErrors: validationErrorsForTemplate(
                            _template,
                            currentFields(_controllers),
                          ),
                          fieldWarnings: validationWarningsForTemplate(
                            _template,
                            currentFields(_controllers),
                          ),
                          images: _images,
                          selectedImage: _selectedImage,
                          mainImage: _mainImage,
                          pickingImage: _pickingImage,
                          sourceError: _sourceError,
                          onSourceBack: () => setState(() => _source = null),
                          onTypeChanged: _changeTemplate,
                          onAddImage: _addImage,
                          onSelectImage: _selectImage,
                          onSetMainImage: _setSelectedAsMainImage,
                          onDeleteImage: _deleteImage,
                        ),
                      ),
            ),
            const SizedBox(height: 12),
            if (source != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save-new-card'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AkatorColors.primaryStrong,
                    foregroundColor: AkatorColors.textInverted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: canSave ? _saveCard : null,
                  child: const Text('Save card'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AddCardSourcePicker extends StatelessWidget {
  const AddCardSourcePicker({required this.onSelected, super.key});

  final ValueChanged<AddCardSource> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(
          'Internal storage',
          style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
        ),
        const SizedBox(height: 8),
        AddCardPathButton(
          key: const ValueKey('add-card-path-image'),
          icon: Icons.photo_camera_rounded,
          title: 'Make an image',
          detail: 'Take images and fill the card fields yourself',
          onPressed: () => onSelected(AddCardSource.image),
        ),
        const SizedBox(height: 12),
        Text(
          'External storage',
          style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
        ),
        const SizedBox(height: 8),
        AddCardPathButton(
          key: const ValueKey('add-card-path-syncthing'),
          icon: Icons.sync_rounded,
          title: 'Syncthing',
          detail: 'Choose a synced folder and link images from it',
          onPressed: () => onSelected(AddCardSource.syncthing),
        ),
        const SizedBox(height: 8),
        AddCardPathButton(
          key: const ValueKey('add-card-path-proton-drive'),
          icon: Icons.cloud_outlined,
          title: 'Proton Drive',
          detail: 'Browse images through the Android file picker',
          onPressed: () => onSelected(AddCardSource.protonDrive),
        ),
      ],
    );
  }
}

class AddCardPathButton extends StatelessWidget {
  const AddCardPathButton({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AkatorColors.backgroundNorm,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AkatorColors.appBarDividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AkatorColors.primaryStrong),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: WalletStyles.body1Medium(
                          color: AkatorColors.textNorm,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: WalletStyles.captionRegular(
                          color: AkatorColors.textWeak,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddCardDraftForm extends StatelessWidget {
  const AddCardDraftForm({
    required this.source,
    required this.templates,
    required this.template,
    required this.controllers,
    required this.fieldErrors,
    required this.fieldWarnings,
    required this.images,
    required this.selectedImage,
    required this.mainImage,
    required this.pickingImage,
    required this.sourceError,
    required this.onSourceBack,
    required this.onTypeChanged,
    required this.onAddImage,
    required this.onSelectImage,
    required this.onSetMainImage,
    required this.onDeleteImage,
    super.key,
  });

  final AddCardSource source;
  final List<CardTemplate> templates;
  final CardTemplate template;
  final Map<String, TextEditingController> controllers;
  final Map<String, String> fieldErrors;
  final Map<String, String> fieldWarnings;
  final List<CardImageRef> images;
  final CardImageRef? selectedImage;
  final CardImageRef? mainImage;
  final bool pickingImage;
  final String? sourceError;
  final VoidCallback onSourceBack;
  final ValueChanged<WalletCardType?> onTypeChanged;
  final VoidCallback onAddImage;
  final ValueChanged<CardImageRef> onSelectImage;
  final VoidCallback onSetMainImage;
  final ValueChanged<CardImageRef> onDeleteImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<WalletCardType>(
                key: const ValueKey('add-card-type-selector'),
                value: template.type,
                decoration: const InputDecoration(
                  labelText: 'Card type',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in templates)
                    DropdownMenuItem(value: item.type, child: Text(item.label)),
                ],
                onChanged: onTypeChanged,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Choose source',
              onPressed: onSourceBack,
              icon: const Icon(Icons.swap_horiz_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (source != AddCardSource.image) ExternalStorageHint(source: source),
        if (source != AddCardSource.image) const SizedBox(height: 12),
        DraftImageActionRow(
          source: source,
          images: images,
          pickingImage: pickingImage,
          onAddImage: onAddImage,
        ),
        if (sourceError != null) ...[
          const SizedBox(height: 8),
          Text(
            sourceError!,
            style: WalletStyles.captionRegular(color: AkatorColors.danger),
          ),
        ],
        const SizedBox(height: 14),
        DraftImageEditor(
          images: images,
          selectedImage: selectedImage,
          mainImage: mainImage,
          onSelectImage: onSelectImage,
          onSetMainImage: onSetMainImage,
          onDeleteImage: onDeleteImage,
        ),
        const SizedBox(height: 16),
        for (final field in template.fields) ...[
          SensitiveFieldText(
            field: field,
            controller: controllers[field.key]!,
            errorText: fieldErrors[field.key],
            warningText: fieldWarnings[field.key],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class DraftImageActionRow extends StatelessWidget {
  const DraftImageActionRow({
    required this.source,
    required this.images,
    required this.pickingImage,
    required this.onAddImage,
    super.key,
  });

  final AddCardSource source;
  final List<CardImageRef> images;
  final bool pickingImage;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('add-draft-image'),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: images.length < 4 && !pickingImage ? onAddImage : null,
          icon: Icon(iconForAddSource(source)),
          label: Text(pickingImage ? 'Opening picker' : 'Add image'),
        ),
        const Spacer(),
        ImageCountBadge(count: images.length),
      ],
    );
  }
}

class ImageCountBadge extends StatelessWidget {
  const ImageCountBadge({required this.count, super.key});

  final int count;

  Color get color {
    if (count >= 4) {
      return AkatorColors.danger;
    }
    if (count == 3) {
      return AkatorColors.warning;
    }
    if (count >= 1) {
      return AkatorColors.success;
    }
    return AkatorColors.textHint;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = color;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activeColor.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(
          'Images ($count/4)',
          style: WalletStyles.body2Medium(color: activeColor),
        ),
      ),
    );
  }
}

class DraftImageEditor extends StatefulWidget {
  const DraftImageEditor({
    required this.images,
    required this.selectedImage,
    required this.mainImage,
    required this.onSelectImage,
    required this.onSetMainImage,
    required this.onDeleteImage,
    super.key,
  });

  final List<CardImageRef> images;
  final CardImageRef? selectedImage;
  final CardImageRef? mainImage;
  final ValueChanged<CardImageRef> onSelectImage;
  final VoidCallback onSetMainImage;
  final ValueChanged<CardImageRef> onDeleteImage;

  @override
  State<DraftImageEditor> createState() => _DraftImageEditorState();
}

class _DraftImageEditorState extends State<DraftImageEditor> {
  bool _showAlreadySetMessage = false;
  int _messageVersion = 0;

  @override
  void didUpdateWidget(DraftImageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedImage != widget.selectedImage ||
        oldWidget.mainImage != widget.mainImage) {
      _showAlreadySetMessage = false;
      _messageVersion++;
    }
  }

  void _handleSetMainImage() {
    final image = widget.selectedImage;
    if (image == null) {
      return;
    }

    if (image == widget.mainImage) {
      _showAlreadySetNotice();
      return;
    }

    widget.onSetMainImage();
    setState(() {
      _showAlreadySetMessage = false;
      _messageVersion++;
    });
  }

  void _showAlreadySetNotice() {
    final version = ++_messageVersion;
    setState(() => _showAlreadySetMessage = true);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || version != _messageVersion) {
        return;
      }
      setState(() => _showAlreadySetMessage = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.selectedImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image == null)
          const EmptyDraftImagePanel()
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Tooltip(
                message: 'Zoom draft image',
                child: GestureDetector(
                  key: const ValueKey('zoom-draft-main-image'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showCardImageZoom(context, image),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 1.58,
                      child: walletImage(image, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (widget.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          DraftImageThumbnailRow(
            images: widget.images,
            selectedImage: image,
            onSelectImage: widget.onSelectImage,
            onDeleteImage: widget.onDeleteImage,
          ),
        ],
        const SizedBox(height: 12),
        if (image != null) ...[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child:
                _showAlreadySetMessage
                    ? Padding(
                      key: const ValueKey('draft-already-set-message'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'already set as main image',
                          style: WalletStyles.captionRegular(
                            color: AkatorColors.success,
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(
                      key: ValueKey('draft-already-set-message-empty'),
                    ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: MainImageButton(
              key: const ValueKey('set-draft-main-image'),
              isMainImage: image == widget.mainImage,
              onPressed: _handleSetMainImage,
            ),
          ),
        ],
      ],
    );
  }
}

class EmptyDraftImagePanel extends StatelessWidget {
  const EmptyDraftImagePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.backgroundNorm,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkatorColors.appBarDividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Row(
          children: [
            const Icon(
              Icons.photo_camera_rounded,
              color: AkatorColors.primaryStrong,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add up to four images',
                style: WalletStyles.body2Medium(color: AkatorColors.textWeak),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DraftImageThumbnailRow extends StatelessWidget {
  const DraftImageThumbnailRow({
    required this.images,
    required this.selectedImage,
    required this.onSelectImage,
    required this.onDeleteImage,
    super.key,
  });

  final List<CardImageRef> images;
  final CardImageRef? selectedImage;
  final ValueChanged<CardImageRef> onSelectImage;
  final ValueChanged<CardImageRef> onDeleteImage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          for (var index = 0; index < images.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CardImageThumbnail(
                      cardId: 'draft',
                      image: images[index],
                      index: index,
                      selected: images[index] == selectedImage,
                      onTap: () => onSelectImage(images[index]),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -8,
                    child: IconButton.filled(
                      key: ValueKey('delete-draft-image-$index'),
                      tooltip: 'Delete image ${index + 1}',
                      style: IconButton.styleFrom(
                        fixedSize: const Size(30, 30),
                        backgroundColor: AkatorColors.danger,
                        foregroundColor: AkatorColors.textInverted,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onDeleteImage(images[index]),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ExternalStorageHint extends StatelessWidget {
  const ExternalStorageHint({required this.source, super.key});

  final AddCardSource source;

  @override
  Widget build(BuildContext context) {
    final text =
        source == AddCardSource.syncthing
            ? 'Choose your Syncthing folder once, then pick images from Android storage.'
            : 'Pick images through Android storage. Proton Drive appears here when its app is installed and signed in.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.backgroundNorm,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkatorColors.appBarDividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(iconForAddSource(source), color: AkatorColors.primaryStrong),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: WalletStyles.body2Medium(color: AkatorColors.textWeak),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, TextEditingController> controllersForTemplate(
  CardTemplate template, {
  VoidCallback? onChanged,
}) {
  final controllers = <String, TextEditingController>{};

  for (final field in template.fields) {
    final controller = TextEditingController();
    if (onChanged != null) {
      controller.addListener(onChanged);
    }
    controllers[field.key] = controller;
  }

  return controllers;
}

void disposeControllers(
  Map<String, TextEditingController> controllers, {
  VoidCallback? onChanged,
}) {
  for (final controller in controllers.values) {
    if (onChanged != null) {
      controller.removeListener(onChanged);
    }
    controller.dispose();
  }
}

Map<String, String> currentFields(
  Map<String, TextEditingController> controllers,
) {
  return {for (final entry in controllers.entries) entry.key: entry.value.text};
}

String titleForDraftCard(CardTemplate template, Map<String, String> fields) {
  const preferredKeys = [
    'name',
    'full_name',
    'program',
    'provider',
    'license_number',
    'document_number',
    'student_number',
    'member_number',
  ];

  for (final key in preferredKeys) {
    final value = fields[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }

  return 'New ${template.label}';
}

CardImageRef fallbackImageForType(
  WalletCardBundle bundle,
  WalletCardType type,
) {
  for (final card in bundle.cards) {
    if (card.type == type) {
      return card.primaryImage;
    }
  }

  return bundle.cards.first.primaryImage;
}

class FavoriteCarouselSkeleton extends StatelessWidget {
  const FavoriteCarouselSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AkatorColors.primaryBorder),
      ),
      child: const SizedBox(height: 190),
    );
  }
}

class CardTypeBadge extends StatelessWidget {
  const CardTypeBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkatorColors.primaryBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: WalletStyles.captionRegular(color: AkatorColors.primaryStrong),
        ),
      ),
    );
  }
}

bool isSensitiveField(CardFieldTemplate field) {
  return field.key == 'cvc';
}

TextInputType keyboardForField(CardFieldTemplate field) {
  return switch (field.input) {
    'date' || 'month' => TextInputType.datetime,
    'number' => TextInputType.number,
    _ => TextInputType.text,
  };
}

List<TextInputFormatter> inputFormattersForField(CardFieldTemplate field) {
  return switch (field.key) {
    'card_number' => [const GroupedDigitsInputFormatter(maxDigits: 19)],
    'expiration_date' => [const ExpirationDateInputFormatter()],
    'cvc' => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ],
    _ => const [],
  };
}

String? hintForField(CardFieldTemplate field) {
  return switch (field.key) {
    'card_number' => '1234 1234 1234 1234',
    'expiration_date' => 'MM/YY',
    'cvc' => '123',
    _ => null,
  };
}

Map<String, String> validationErrorsForTemplate(
  CardTemplate template,
  Map<String, String> fields,
) {
  if (template.type != WalletCardType.creditCard) {
    return const {};
  }

  final errors = <String, String>{};

  void addError(String key, String? error) {
    if (template.fieldByKey(key) != null && error != null) {
      errors[key] = error;
    }
  }

  addError('expiration_date', expirationDateError(fields['expiration_date']));
  addError('card_number', cardNumberError(fields['card_number']));
  addError('cvc', cvcError(fields['cvc'], fields['card_number']));

  return errors;
}

String? expirationDateError(String? value) {
  final digits = paymentCardDigits(value ?? '');
  if (digits.isEmpty) {
    return 'Expiration date is required';
  }
  if (digits.length != 4) {
    return 'Use MM/YY';
  }

  final month = int.tryParse(digits.substring(0, 2));
  if (month == null || month < 1 || month > 12) {
    return 'Month must be 01-12';
  }

  return null;
}

String? cardNumberError(String? value) {
  final digits = paymentCardDigits(value ?? '');
  if (digits.isEmpty) {
    return 'Card number is required';
  }

  final issuer = paymentCardIssuerFor(digits);
  final lengths = allowedCardNumberLengths(issuer);
  final minLength = lengths.reduce(math.min);
  final maxLength = lengths.reduce(math.max);

  if (digits.length < minLength || digits.length > maxLength) {
    return issuer == PaymentCardIssuer.unknown
        ? 'Use 13-19 digits'
        : 'Use ${formatAllowedLengths(lengths)} digits for ${issuer.label}';
  }
  if (!lengths.contains(digits.length)) {
    return 'Use ${formatAllowedLengths(lengths)} digits for ${issuer.label}';
  }

  return null;
}

Map<String, String> validationWarningsForTemplate(
  CardTemplate template,
  Map<String, String> fields,
) {
  if (template.type != WalletCardType.creditCard) {
    return const {};
  }

  final warnings = <String, String>{};
  final cardNumberWarning = luhnWarning(fields['card_number']);
  if (template.fieldByKey('card_number') != null && cardNumberWarning != null) {
    warnings['card_number'] = cardNumberWarning;
  }

  return warnings;
}

String? luhnWarning(String? value) {
  if (cardNumberError(value) != null) {
    return null;
  }

  final digits = paymentCardDigits(value ?? '');
  if (!passesLuhnCheck(digits)) {
    return 'Luhn check not passed';
  }

  return null;
}

String? cvcError(String? value, String? cardNumber) {
  final digits = paymentCardDigits(value ?? '');
  if (digits.isEmpty) {
    return 'CVC code is required';
  }

  final cardDigits = paymentCardDigits(cardNumber ?? '');
  final issuer = paymentCardIssuerFor(cardDigits);
  final expectedLength = issuer == PaymentCardIssuer.amex ? 4 : 3;
  if (digits.length != expectedLength) {
    return 'Use $expectedLength digits';
  }

  return null;
}

String paymentCardDigits(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String formatPaymentCardNumber(String value) {
  final digits = paymentCardDigits(value);
  final trimmed = digits.substring(0, math.min(digits.length, 19));
  final groups = <String>[];

  for (var index = 0; index < trimmed.length; index += 4) {
    groups.add(trimmed.substring(index, math.min(index + 4, trimmed.length)));
  }

  return groups.join(' ');
}

String formatExpirationDate(String value) {
  final digits = paymentCardDigits(value);
  final trimmed = digits.substring(0, math.min(digits.length, 4));
  if (trimmed.length <= 2) {
    return trimmed;
  }

  return '${trimmed.substring(0, 2)}/${trimmed.substring(2)}';
}

bool passesLuhnCheck(String digits) {
  var sum = 0;
  var doubleDigit = false;

  for (var index = digits.length - 1; index >= 0; index--) {
    var value = int.parse(digits[index]);
    if (doubleDigit) {
      value *= 2;
      if (value > 9) {
        value -= 9;
      }
    }
    sum += value;
    doubleDigit = !doubleDigit;
  }

  return sum % 10 == 0;
}

enum PaymentCardIssuer {
  amex('American Express'),
  discover('Discover'),
  mastercard('Mastercard'),
  visa('Visa'),
  unknown('card');

  const PaymentCardIssuer(this.label);

  final String label;
}

PaymentCardIssuer paymentCardIssuerFor(String digits) {
  if (digits.startsWith('34') || digits.startsWith('37')) {
    return PaymentCardIssuer.amex;
  }
  if (digits.startsWith('4')) {
    return PaymentCardIssuer.visa;
  }
  if (digits.startsWith('6011') || digits.startsWith('65')) {
    return PaymentCardIssuer.discover;
  }

  final firstThree =
      digits.length >= 3 ? int.tryParse(digits.substring(0, 3)) : null;
  if (firstThree != null && firstThree >= 644 && firstThree <= 649) {
    return PaymentCardIssuer.discover;
  }

  final firstTwo =
      digits.length >= 2 ? int.tryParse(digits.substring(0, 2)) : null;
  if (firstTwo != null && firstTwo >= 51 && firstTwo <= 55) {
    return PaymentCardIssuer.mastercard;
  }

  final firstFour =
      digits.length >= 4 ? int.tryParse(digits.substring(0, 4)) : null;
  if (firstFour != null && firstFour >= 2221 && firstFour <= 2720) {
    return PaymentCardIssuer.mastercard;
  }

  final firstSix =
      digits.length >= 6 ? int.tryParse(digits.substring(0, 6)) : null;
  if (firstSix != null && firstSix >= 622126 && firstSix <= 622925) {
    return PaymentCardIssuer.discover;
  }

  return PaymentCardIssuer.unknown;
}

Set<int> allowedCardNumberLengths(PaymentCardIssuer issuer) {
  return switch (issuer) {
    PaymentCardIssuer.amex => const {15},
    PaymentCardIssuer.discover => const {16, 17, 18, 19},
    PaymentCardIssuer.mastercard => const {16},
    PaymentCardIssuer.visa => const {13, 16, 19},
    PaymentCardIssuer.unknown => const {13, 14, 15, 16, 17, 18, 19},
  };
}

String formatAllowedLengths(Set<int> lengths) {
  final sorted = lengths.toList()..sort();
  if (sorted.length == 1) {
    return sorted.single.toString();
  }

  final isContinuous =
      sorted.last - sorted.first + 1 == sorted.length &&
      sorted.toSet().length == sorted.length;
  if (isContinuous) {
    return '${sorted.first}-${sorted.last}';
  }

  return sorted.join(', ');
}

class GroupedDigitsInputFormatter extends TextInputFormatter {
  const GroupedDigitsInputFormatter({required this.maxDigits});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = paymentCardDigits(newValue.text);
    final trimmed = digits.substring(0, math.min(digits.length, maxDigits));
    final formatted = formatPaymentCardNumber(trimmed);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpirationDateInputFormatter extends TextInputFormatter {
  const ExpirationDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatExpirationDate(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

double currentCarouselPage(PageController controller, int selectedIndex) {
  if (!controller.hasClients) {
    return selectedIndex.toDouble();
  }

  try {
    return controller.page ?? selectedIndex.toDouble();
  } on AssertionError {
    return selectedIndex.toDouble();
  }
}

Color colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;

  return Color(int.parse(withAlpha, radix: 16));
}

bool mapsEqual(Map<String, String> first, Map<String, String> second) {
  if (first.length != second.length) {
    return false;
  }

  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) {
      return false;
    }
  }

  return true;
}

class OverviewFilter {
  const OverviewFilter({
    required this.id,
    required this.label,
    required this.matchedTypes,
  });

  final String id;
  final String label;
  final Set<WalletCardType> matchedTypes;
}

const overviewFilters = [
  OverviewFilter(
    id: 'passport_id',
    label: 'passport/IDs',
    matchedTypes: {WalletCardType.personalId},
  ),
  OverviewFilter(
    id: 'credit_debit_cards',
    label: 'credit/debit cards',
    matchedTypes: {WalletCardType.creditCard},
  ),
  OverviewFilter(
    id: 'student_ids',
    label: 'student IDs',
    matchedTypes: {WalletCardType.studentId},
  ),
  OverviewFilter(
    id: 'health_insurance',
    label: 'health insurance',
    matchedTypes: {WalletCardType.healthInsurance},
  ),
  OverviewFilter(
    id: 'loyalty_cards',
    label: 'loyalty cards',
    matchedTypes: {WalletCardType.loyaltyCard},
  ),
  OverviewFilter(
    id: 'driver_licenses',
    label: 'driver licenses',
    matchedTypes: {WalletCardType.drivingLicense},
  ),
];

class OverviewSection extends StatefulWidget {
  const OverviewSection({
    required this.expanded,
    required this.bundle,
    required this.onToggle,
    required this.onView,
    required this.onAdd,
    super.key,
  });

  final bool expanded;
  final WalletCardBundle? bundle;
  final VoidCallback onToggle;
  final void Function(WalletCard card, CardTemplate template) onView;
  final VoidCallback onAdd;

  @override
  State<OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<OverviewSection> {
  final Set<String> _selectedFilterIds = {};

  @override
  void didUpdateWidget(OverviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bundle = widget.bundle;
    if (bundle == null) {
      return;
    }

    final visibleIds =
        visibleOverviewFilters(bundle.cards).map((filter) => filter.id).toSet();
    _selectedFilterIds.removeWhere((id) => !visibleIds.contains(id));
  }

  void _toggleFilter(OverviewFilter filter) {
    setState(() {
      if (_selectedFilterIds.contains(filter.id)) {
        _selectedFilterIds.remove(filter.id);
      } else {
        _selectedFilterIds.add(filter.id);
      }
    });
  }

  List<WalletCard> _filteredCards(List<WalletCard> cards) {
    if (_selectedFilterIds.isEmpty) {
      return cards;
    }

    final selectedTypes = {
      for (final filter in overviewFilters)
        if (_selectedFilterIds.contains(filter.id)) ...filter.matchedTypes,
    };

    return cards.where((card) => selectedTypes.contains(card.type)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = widget.bundle;
    final cards =
        bundle == null ? <WalletCard>[] : _filteredCards(bundle.cards);
    final filters =
        bundle == null
            ? <OverviewFilter>[]
            : visibleOverviewFilters(bundle.cards);

    return WalletSection(
      sectionLabel: 'Section 2',
      title: 'Overview',
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in filters)
                OverviewFilterChip(
                  filter: filter,
                  selected: _selectedFilterIds.contains(filter.id),
                  onSelected: () => _toggleFilter(filter),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (bundle == null)
            const FavoriteCarouselSkeleton()
          else
            OverviewCardGrid(
              cards: cards,
              bundle: bundle,
              onView: widget.onView,
              onAdd: widget.onAdd,
            ),
        ],
      ),
    );
  }
}

List<OverviewFilter> visibleOverviewFilters(List<WalletCard> cards) {
  final availableTypes = cards.map((card) => card.type).toSet();

  return [
    for (final filter in overviewFilters)
      if (filter.matchedTypes.any(availableTypes.contains)) filter,
  ];
}

class OverviewCardGrid extends StatefulWidget {
  const OverviewCardGrid({
    required this.cards,
    required this.bundle,
    required this.onView,
    required this.onAdd,
    super.key,
  });

  final List<WalletCard> cards;
  final WalletCardBundle bundle;
  final void Function(WalletCard card, CardTemplate template) onView;
  final VoidCallback onAdd;

  @override
  State<OverviewCardGrid> createState() => _OverviewCardGridState();
}

class _OverviewCardGridState extends State<OverviewCardGrid> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return OverviewEmptyState(onAdd: widget.onAdd);
    }

    return LayoutBuilder(
      key: const ValueKey('overview-card-grid'),
      builder: (context, constraints) {
        const spacing = 12.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        final tileHeight = tileWidth / 1.85;
        final rowCount = (widget.cards.length / 2).ceil();
        final scrollable = widget.cards.length > 5;
        final visibleRows = scrollable ? 2.55 : rowCount.toDouble();
        final visibleGaps = scrollable ? 2 : math.max(0, rowCount - 1);
        final gridHeight = tileHeight * visibleRows + spacing * visibleGaps;

        final cardGrid = Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in widget.cards)
              SizedBox(
                width: tileWidth,
                height: tileHeight,
                child: OverviewCardTile(
                  card: card,
                  template: widget.bundle.templateFor(card.type),
                  onView:
                      () => widget.onView(
                        card,
                        widget.bundle.templateFor(card.type),
                      ),
                ),
              ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: gridHeight,
              child:
                  scrollable
                      ? Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          key: const ValueKey('overview-card-scroll'),
                          controller: _scrollController,
                          child: cardGrid,
                        ),
                      )
                      : cardGrid,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: AddCardButton(onPressed: widget.onAdd),
            ),
          ],
        );
      },
    );
  }
}

class OverviewCardTile extends StatelessWidget {
  const OverviewCardTile({
    required this.card,
    required this.template,
    required this.onView,
    super.key,
  });

  final WalletCard card;
  final CardTemplate template;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'View ${card.title}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('view-overview-card-${card.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onView,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AkatorColors.backgroundNorm,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AkatorColors.appBarDividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 50,
                      height: 32,
                      child: walletImage(card.primaryImage, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WalletStyles.body2Medium(
                            color: AkatorColors.textNorm,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          template.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: WalletStyles.captionRegular(
                            color: AkatorColors.textWeak,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OverviewEmptyState extends StatelessWidget {
  const OverviewEmptyState({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AkatorColors.backgroundNorm,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AkatorColors.appBarDividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Text(
              'No cards match these filters',
              textAlign: TextAlign.center,
              style: WalletStyles.body2Medium(color: AkatorColors.textWeak),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: AddCardButton(onPressed: onAdd),
        ),
      ],
    );
  }
}

class ExploreSection extends StatelessWidget {
  const ExploreSection({
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return WalletSection(
      sectionLabel: 'Section 3',
      title: 'Explore: Security & Data',
      expanded: expanded,
      onToggle: onToggle,
      child: Column(
        children: [
          const ArticleRow(
            title: 'Own cloud storage',
            detail: 'Some text and link to a website: own cloud storage',
          ),
          const SizedBox(height: 10),
          const ArticleRow(
            title: 'On-device storage',
            detail: 'Some text and link to a website: on device storage',
          ),
        ],
      ),
    );
  }
}

class WalletMenuDrawer extends StatelessWidget {
  const WalletMenuDrawer({
    required this.connections,
    required this.syncthingAvailable,
    required this.protonDriveAvailable,
    required this.onClose,
    required this.onConnectionsPressed,
    super.key,
  });

  final WalletConnections connections;
  final bool syncthingAvailable;
  final bool protonDriveAvailable;
  final VoidCallback onClose;
  final VoidCallback onConnectionsPressed;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: panelWidth(context),
      backgroundColor: AkatorColors.drawerBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            DrawerMenuHeader(onClose: onClose),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                children: [
                  const DrawerDivider(),
                  const DrawerSectionTitle('Connections'),
                  const SizedBox(height: 14),
                  DrawerConnectionItem(
                    key: const ValueKey('drawer-connection-syncthing'),
                    title: 'Syncthing',
                    state: connectionStateFor(
                      available: syncthingAvailable,
                      connected: connections.syncthingConnected,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(
                        Future<void>.delayed(
                          const Duration(milliseconds: 220),
                          onConnectionsPressed,
                        ),
                      );
                    },
                  ),
                  DrawerConnectionItem(
                    key: const ValueKey('drawer-connection-proton-drive'),
                    title: 'Proton Drive',
                    state: connectionStateFor(
                      available: protonDriveAvailable,
                      connected: connections.protonDriveConnected,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(
                        Future<void>.delayed(
                          const Duration(milliseconds: 220),
                          onConnectionsPressed,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  const DrawerDivider(),
                  const DrawerSectionTitle('More'),
                  const SizedBox(height: 14),
                  const DrawerPlainItem('Discover: why is my data safe?'),
                  const DrawerPlainItem('User Settings'),
                  const DrawerPlainItem('Security'),
                  const DrawerPlainItem('Recovery'),
                  const SizedBox(height: 28),
                  const DrawerDivider(),
                  const DrawerPlainItem('Logout', large: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WalletSettingsDrawer extends StatelessWidget {
  const WalletSettingsDrawer({
    required this.connections,
    required this.syncthingAvailable,
    required this.protonDriveAvailable,
    required this.onClose,
    required this.onConnectionsPressed,
    super.key,
  });

  final WalletConnections connections;
  final bool syncthingAvailable;
  final bool protonDriveAvailable;
  final VoidCallback onClose;
  final VoidCallback onConnectionsPressed;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: panelWidth(context),
      backgroundColor: AkatorColors.backgroundNorm,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SettingsHeader(onClose: onClose),
            const SizedBox(height: 18),
            const SettingsPanel(
              title: 'View',
              children: [
                SettingsTextTile(
                  title: 'My favorites',
                  lines: ['show / hide', 'add/remove items'],
                ),
                SettingsTextTile(
                  title: 'Overview',
                  lines: ['show / hide', 'sort according to'],
                ),
                SettingsTextTile(
                  title: 'Explore',
                  lines: ['show / hide', 'explore more articles'],
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsPanel(
              title: 'Connection status',
              children: [
                SettingsConnectionTile(
                  key: const ValueKey('settings-connection-syncthing'),
                  title: 'Syncthing',
                  state: connectionStateFor(
                    available: syncthingAvailable,
                    connected: connections.syncthingConnected,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(
                      Future<void>.delayed(
                        const Duration(milliseconds: 220),
                        onConnectionsPressed,
                      ),
                    );
                  },
                ),
                SettingsConnectionTile(
                  key: const ValueKey('settings-connection-proton-drive'),
                  title: 'Proton Drive',
                  state: connectionStateFor(
                    available: protonDriveAvailable,
                    connected: connections.protonDriveConnected,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(
                      Future<void>.delayed(
                        const Duration(milliseconds: 220),
                        onConnectionsPressed,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.connections,
    required this.syncthingAvailable,
    required this.protonDriveAvailable,
  });

  final WalletConnections connections;
  final bool syncthingAvailable;
  final bool protonDriveAvailable;
}

class ConnectionActionResult {
  const ConnectionActionResult({required this.snapshot, this.message});

  final ConnectionSnapshot snapshot;
  final String? message;
}

class WalletConnectionView {
  const WalletConnectionView({
    required this.label,
    required this.detail,
    required this.color,
    required this.connected,
  });

  final String label;
  final String detail;
  final Color color;
  final bool connected;
}

WalletConnectionView connectionStateFor({
  required bool available,
  required bool connected,
}) {
  if (!available) {
    return const WalletConnectionView(
      label: 'Not installed',
      detail: 'Set up connection',
      color: AkatorColors.danger,
      connected: false,
    );
  }
  if (!connected) {
    return const WalletConnectionView(
      label: 'Disconnected',
      detail: 'Set up connection',
      color: AkatorColors.textHint,
      connected: false,
    );
  }
  return const WalletConnectionView(
    label: 'Connected',
    detail: 'Show files or adjust settings',
    color: AkatorColors.success,
    connected: true,
  );
}

enum ConnectionSettingsTarget { syncthing, protonDrive }

class ConnectionsSheet extends StatefulWidget {
  const ConnectionsSheet({
    required this.initialSnapshot,
    required this.onSetupSyncthing,
    required this.onSetupProtonDrive,
    required this.onShowSyncthingFiles,
    required this.onShowProtonDriveFiles,
    required this.onOpenSyncthingApp,
    required this.onOpenProtonDriveApp,
    required this.onDeleteSyncthing,
    required this.onDeleteProtonDrive,
    super.key,
  });

  final ConnectionSnapshot initialSnapshot;
  final Future<ConnectionActionResult> Function() onSetupSyncthing;
  final Future<ConnectionActionResult> Function() onSetupProtonDrive;
  final Future<ConnectionActionResult> Function() onShowSyncthingFiles;
  final Future<ConnectionActionResult> Function() onShowProtonDriveFiles;
  final Future<ConnectionActionResult> Function() onOpenSyncthingApp;
  final Future<ConnectionActionResult> Function() onOpenProtonDriveApp;
  final Future<ConnectionActionResult> Function() onDeleteSyncthing;
  final Future<ConnectionActionResult> Function() onDeleteProtonDrive;

  @override
  State<ConnectionsSheet> createState() => _ConnectionsSheetState();
}

class _ConnectionsSheetState extends State<ConnectionsSheet> {
  late ConnectionSnapshot _snapshot = widget.initialSnapshot;
  bool _busy = false;
  String? _message;
  ConnectionSettingsTarget? _settingsTarget;

  Future<void> _run(Future<ConnectionActionResult> Function() action) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final result = await action();
    if (!mounted) {
      return;
    }

    setState(() {
      _snapshot = result.snapshot;
      _message = result.message;
      _busy = false;
    });

    final message = result.message;
    if (message != null) {
      unawaited(
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted && _message == message) {
            setState(() => _message = null);
          }
        }),
      );
    }
  }

  void _openSettings(ConnectionSettingsTarget target) {
    setState(() {
      _settingsTarget = target;
      _message = null;
    });
  }

  void _closeSettings() {
    setState(() {
      _settingsTarget = null;
      _message = null;
    });
  }

  WalletConnectionView _stateFor(ConnectionSettingsTarget target) {
    return switch (target) {
      ConnectionSettingsTarget.syncthing => connectionStateFor(
        available: _snapshot.syncthingAvailable,
        connected: _snapshot.connections.syncthingConnected,
      ),
      ConnectionSettingsTarget.protonDrive => connectionStateFor(
        available: _snapshot.protonDriveAvailable,
        connected: _snapshot.connections.protonDriveConnected,
      ),
    };
  }

  Future<ConnectionActionResult> Function() _setupAction(
    ConnectionSettingsTarget target,
  ) {
    return switch (target) {
      ConnectionSettingsTarget.syncthing => widget.onSetupSyncthing,
      ConnectionSettingsTarget.protonDrive => widget.onSetupProtonDrive,
    };
  }

  Future<ConnectionActionResult> Function() _showFilesAction(
    ConnectionSettingsTarget target,
  ) {
    return switch (target) {
      ConnectionSettingsTarget.syncthing => widget.onShowSyncthingFiles,
      ConnectionSettingsTarget.protonDrive => widget.onShowProtonDriveFiles,
    };
  }

  Future<ConnectionActionResult> Function() _openProviderAppAction(
    ConnectionSettingsTarget target,
  ) {
    return switch (target) {
      ConnectionSettingsTarget.syncthing => widget.onOpenSyncthingApp,
      ConnectionSettingsTarget.protonDrive => widget.onOpenProtonDriveApp,
    };
  }

  Future<ConnectionActionResult> Function() _deleteAction(
    ConnectionSettingsTarget target,
  ) {
    return switch (target) {
      ConnectionSettingsTarget.syncthing => widget.onDeleteSyncthing,
      ConnectionSettingsTarget.protonDrive => widget.onDeleteProtonDrive,
    };
  }

  Future<void> _confirmDisconnect(
    ConnectionSettingsTarget target,
    String providerName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Disconnect $providerName'),
            content: Text(
              'Remove Akator\'s saved $providerName connection. '
              'Wallet cards and provider files stay where they are.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AkatorColors.danger,
                  foregroundColor: AkatorColors.textInverted,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Disconnect'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _run(_deleteAction(target));
    }
  }

  Widget _buildSettingsView(
    BuildContext context,
    ConnectionSettingsTarget target,
  ) {
    final state = _stateFor(target);
    final isSyncthing = target == ConnectionSettingsTarget.syncthing;
    final title = isSyncthing ? 'Syncthing settings' : 'Proton Drive settings';
    final providerName = isSyncthing ? 'Syncthing' : 'Proton Drive';
    final providerText =
        isSyncthing
            ? 'Akator stores the selected Android folder permission. '
                'Device pairing, folder sync rules, versioning and network '
                'state stay in Syncthing-Fork.'
            : 'Akator stores only whether Proton Drive is enabled here. '
                'Sign-in, cloud folders, offline files and account settings '
                'stay in Proton Drive.';

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to connections',
                  onPressed: _closeSettings,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: WalletStyles.subheadline(
                      color: AkatorColors.textNorm,
                    ),
                  ),
                ),
                ConnectionStatusBadge(state: state),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Close connections',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              providerText,
              style: WalletStyles.captionRegular(color: AkatorColors.textWeak),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (state.connected) ...[
                          FilledButton.tonal(
                            onPressed:
                                _busy
                                    ? null
                                    : () => _run(_showFilesAction(target)),
                            child: const Text('Show files'),
                          ),
                          FilledButton.tonal(
                            onPressed:
                                _busy
                                    ? null
                                    : () =>
                                        _run(_openProviderAppAction(target)),
                            child: Text('Open $providerName'),
                          ),
                          if (isSyncthing)
                            OutlinedButton(
                              onPressed:
                                  _busy
                                      ? null
                                      : () => _run(_setupAction(target)),
                              child: const Text('Change folder'),
                            ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AkatorColors.danger,
                              side: const BorderSide(
                                color: AkatorColors.danger,
                              ),
                            ),
                            onPressed:
                                _busy
                                    ? null
                                    : () => _confirmDisconnect(
                                      target,
                                      providerName,
                                    ),
                            child: const Text('Disconnect'),
                          ),
                        ] else
                          FilledButton.tonal(
                            onPressed:
                                _busy ? null : () => _run(_setupAction(target)),
                            child: const Text('Set up connection'),
                          ),
                      ],
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: WalletStyles.captionRegular(
                          color: AkatorColors.primaryStrong,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsTarget = _settingsTarget;
    if (settingsTarget != null) {
      return _buildSettingsView(context, settingsTarget);
    }

    final syncthingState = connectionStateFor(
      available: _snapshot.syncthingAvailable,
      connected: _snapshot.connections.syncthingConnected,
    );
    final protonDriveState = connectionStateFor(
      available: _snapshot.protonDriveAvailable,
      connected: _snapshot.connections.protonDriveConnected,
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Connections',
                    style: WalletStyles.subheadline(
                      color: AkatorColors.textNorm,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close connections',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Akator stores provider status and folder permission only.',
              style: WalletStyles.captionRegular(color: AkatorColors.textWeak),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConnectionSetupTile(
                      title: 'Syncthing',
                      detail:
                          'Choose a synced Android folder. No login is stored.',
                      icon: Icons.cloud_outlined,
                      state: syncthingState,
                      busy: _busy,
                      onSetup: () => _run(widget.onSetupSyncthing),
                      onShowFiles: () => _run(widget.onShowSyncthingFiles),
                      onSettings:
                          () =>
                              _openSettings(ConnectionSettingsTarget.syncthing),
                    ),
                    const SizedBox(height: 10),
                    ConnectionSetupTile(
                      title: 'Proton Drive',
                      detail:
                          'Use the Proton Drive app. Credentials stay there.',
                      icon: Icons.cloud_outlined,
                      state: protonDriveState,
                      busy: _busy,
                      onSetup: () => _run(widget.onSetupProtonDrive),
                      onShowFiles: () => _run(widget.onShowProtonDriveFiles),
                      onSettings:
                          () => _openSettings(
                            ConnectionSettingsTarget.protonDrive,
                          ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        style: WalletStyles.captionRegular(
                          color: AkatorColors.primaryStrong,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectionSetupTile extends StatelessWidget {
  const ConnectionSetupTile({
    required this.title,
    required this.detail,
    required this.icon,
    required this.state,
    required this.busy,
    required this.onSetup,
    required this.onShowFiles,
    required this.onSettings,
    super.key,
  });

  final String title;
  final String detail;
  final IconData icon;
  final WalletConnectionView state;
  final bool busy;
  final VoidCallback onSetup;
  final VoidCallback onShowFiles;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AkatorColors.backgroundNorm,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: state.connected && !busy ? onShowFiles : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AkatorColors.appBarDividerColor),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AkatorColors.primaryStrong),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: WalletStyles.body1Medium(
                        color: AkatorColors.textNorm,
                      ),
                    ),
                  ),
                  ConnectionStatusBadge(state: state),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                style: WalletStyles.captionRegular(
                  color: AkatorColors.textWeak,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (state.connected) ...[
                    FilledButton.tonal(
                      onPressed: busy ? null : onShowFiles,
                      child: const Text('Show files'),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : onSettings,
                      child: const Text('Settings'),
                    ),
                  ] else
                    FilledButton.tonal(
                      onPressed: busy ? null : onSetup,
                      child: const Text('Set up connection'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({
    required this.state,
    this.onDark = false,
    super.key,
  });

  final WalletConnectionView state;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color =
        onDark && state.color == AkatorColors.textHint
            ? AkatorColors.textNeutralOnDark
            : state.color;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: onDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          state.label,
          style: WalletStyles.captionRegular(color: color),
        ),
      ),
    );
  }
}

class DrawerMenuHeader extends StatelessWidget {
  const DrawerMenuHeader({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Akator Wallet', style: WalletStyles.drawerTitle()),
                const SizedBox(height: 12),
                Text('johnDoe@gmail.com', style: WalletStyles.drawerBody()),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close menu',
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AkatorColors.textInverted,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsHeader extends StatelessWidget {
  const SettingsHeader({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Wallet Settings',
            style: WalletStyles.hero(color: AkatorColors.textNorm),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Close settings',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class WalletSection extends StatelessWidget {
  const WalletSection({
    required this.sectionLabel,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    super.key,
  });

  final String sectionLabel;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AkatorColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AkatorColors.appBarDividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: WalletStyles.subheadline(
                      color: AkatorColors.textNorm,
                    ),
                  ),
                ),
                SectionToggleButton(
                  sectionLabel: sectionLabel,
                  expanded: expanded,
                  onPressed: onToggle,
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child:
                  expanded
                      ? Padding(
                        key: ValueKey('$sectionLabel-open'),
                        padding: const EdgeInsets.only(top: 12),
                        child: child,
                      )
                      : const SizedBox.shrink(key: ValueKey('collapsed')),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionToggleButton extends StatelessWidget {
  const SectionToggleButton({
    required this.sectionLabel,
    required this.expanded,
    required this.onPressed,
    super.key,
  });

  final String sectionLabel;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: '${expanded ? 'Collapse' : 'Expand'} $sectionLabel',
      style: IconButton.styleFrom(
        fixedSize: const Size(40, 40),
        backgroundColor: AkatorColors.primarySoft,
        foregroundColor: AkatorColors.primaryStrong,
        side: const BorderSide(color: AkatorColors.primaryBorder),
      ),
      onPressed: onPressed,
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
      ),
    );
  }
}

class OverviewFilterChip extends StatelessWidget {
  const OverviewFilterChip({
    required this.filter,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final OverviewFilter filter;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: ValueKey('overview-filter-${filter.id}'),
      label: Text(filter.label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      labelStyle: WalletStyles.body2Medium(
        color: selected ? AkatorColors.primaryStrong : AkatorColors.textWeak,
      ),
      backgroundColor: AkatorColors.backgroundNorm,
      selectedColor: AkatorColors.primarySoft,
      side: BorderSide(
        color:
            selected
                ? AkatorColors.primaryStrong
                : AkatorColors.appBarDividerColor,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

class AddCardButton extends StatelessWidget {
  const AddCardButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const ValueKey('overview-add-card'),
      style: FilledButton.styleFrom(
        backgroundColor: AkatorColors.primarySoft,
        foregroundColor: AkatorColors.primaryStrong,
        side: const BorderSide(color: AkatorColors.primaryBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        minimumSize: const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Add card',
            style: WalletStyles.body2Medium(color: AkatorColors.primaryStrong),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.add_rounded, size: 20),
        ],
      ),
    );
  }
}

class ArticleRow extends StatelessWidget {
  const ArticleRow({required this.title, required this.detail, super.key});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AkatorColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 58,
            height: 58,
            child: Icon(Icons.image_outlined, color: AkatorColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: WalletStyles.captionRegular(
                  color: AkatorColors.textWeak,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DrawerSectionTitle extends StatelessWidget {
  const DrawerSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(text, style: WalletStyles.drawerSection()),
    );
  }
}

class DrawerPlainItem extends StatelessWidget {
  const DrawerPlainItem(this.text, {this.large = false, super.key});

  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: large ? 0 : 8),
      child: Text(
        text,
        style: large ? WalletStyles.drawerSection() : WalletStyles.drawerBody(),
      ),
    );
  }
}

class DrawerConnectionItem extends StatelessWidget {
  const DrawerConnectionItem({
    required this.title,
    required this.state,
    required this.onPressed,
    super.key,
  });

  final String title;
  final WalletConnectionView state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(title, style: WalletStyles.drawerBody())),
              const SizedBox(width: 8),
              ConnectionStatusBadge(state: state, onDark: true),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawerDivider extends StatelessWidget {
  const DrawerDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: AkatorColors.drawerTextWeak,
      thickness: 1,
      height: 1,
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: WalletStyles.subheadline(color: AkatorColors.textNorm),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AkatorColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsTextTile extends StatelessWidget {
  const SettingsTextTile({
    required this.title,
    required this.lines,
    this.showChevron = true,
    super.key,
  });

  final String title;
  final List<String> lines;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Text(
        title,
        style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Text(
                line,
                style: WalletStyles.captionRegular(
                  color: AkatorColors.textWeak,
                ),
              ),
          ],
        ),
      ),
      trailing:
          showChevron
              ? const Icon(
                Icons.chevron_right_rounded,
                color: AkatorColors.textHint,
              )
              : null,
    );
  }
}

class SettingsConnectionTile extends StatelessWidget {
  const SettingsConnectionTile({
    required this.title,
    required this.state,
    required this.onPressed,
    super.key,
  });

  final String title;
  final WalletConnectionView state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onPressed,
      title: Text(
        title,
        style: WalletStyles.body1Medium(color: AkatorColors.textNorm),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          state.detail,
          style: WalletStyles.captionRegular(color: AkatorColors.textWeak),
        ),
      ),
      trailing: ConnectionStatusBadge(state: state),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        backgroundColor: AkatorColors.backgroundSecondary,
        foregroundColor: AkatorColors.primaryStrong,
        side: const BorderSide(color: AkatorColors.appBarDividerColor),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
    );
  }
}

double panelWidth(BuildContext context) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final width = math.min(screenWidth - 44, 390.0);
  return width.clamp(292.0, 390.0).toDouble();
}

const double defaultPadding = 16;

class AkatorColors {
  static const backgroundNorm = Color(0xFFF9FAFB);
  static const backgroundSecondary = Color(0xFFFFFFFF);
  static const textNorm = Color(0xFF111827);
  static const textHint = Color(0xFF6B7280);
  static const textWeak = Color(0xFF4B5563);
  static const textInverted = Color(0xFFFFFFFF);
  static const textNeutralOnDark = Color(0xFFD1D5DB);
  static const appBarDividerColor = Color(0xFFE5E7EB);
  static const primary = Color(0xFF3370E4);
  static const primaryStrong = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFEFF6FF);
  static const primaryBorder = Color(0xFFBFDBFE);
  static const success = Color(0xFF16A34A);
  static const successBorder = Color(0xFF15803D);
  static const fieldValidBorder = Color(0xFF15803D);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const loadingShadow = Color(0x223370E4);
  static const drawerBackground = Color(0xFF1E3A8A);
  static const drawerTextWeak = Color(0xFFBFDBFE);
}

class WalletStyles {
  static TextStyle hero({Color? color}) {
    return TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 34 / 28,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle headline({Color? color}) {
    return TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 24 / 22,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle subheadline({Color? color}) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 24 / 20,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle body1Medium({Color? color}) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 24 / 16,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle body2Medium({Color? color}) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 20 / 14,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle captionRegular({Color? color}) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle drawerTitle() {
    return const TextStyle(
      color: AkatorColors.textInverted,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: 0,
    );
  }

  static TextStyle drawerSection() {
    return const TextStyle(
      color: AkatorColors.textInverted,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    );
  }

  static TextStyle drawerBody() {
    return const TextStyle(
      color: AkatorColors.textInverted,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0,
    );
  }
}
