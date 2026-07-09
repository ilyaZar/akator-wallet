import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

enum WalletCardType {
  creditCard('credit_card'),
  healthInsurance('health_insurance'),
  loyaltyCard('loyalty_card'),
  personalId('personal_id'),
  drivingLicense('driving_license'),
  studentId('student_id');

  const WalletCardType(this.storageKey);

  final String storageKey;

  static WalletCardType fromStorageKey(String value) {
    return WalletCardType.values.firstWhere(
      (type) => type.storageKey == value,
      orElse: () => throw FormatException('Unknown card type: $value'),
    );
  }
}

enum CardImageKind {
  asset('asset'),
  localFile('local_file'),
  externalUri('external_uri');

  const CardImageKind(this.storageKey);

  final String storageKey;

  static CardImageKind fromStorageKey(String value) {
    return CardImageKind.values.firstWhere(
      (kind) => kind.storageKey == value,
      orElse: () => throw FormatException('Unknown image kind: $value'),
    );
  }
}

enum CardImageProvider {
  internal('internal'),
  syncthing('syncthing'),
  protonDrive('proton_drive');

  const CardImageProvider(this.storageKey);

  final String storageKey;

  static CardImageProvider fromStorageKey(String value) {
    return CardImageProvider.values.firstWhere(
      (provider) => provider.storageKey == value,
      orElse: () => throw FormatException('Unknown image provider: $value'),
    );
  }
}

class CardImageRef {
  const CardImageRef({
    required this.id,
    required this.uri,
    required this.kind,
    required this.provider,
    required this.displayName,
    required this.mimeType,
  });

  final String id;
  final String uri;
  final CardImageKind kind;
  final CardImageProvider provider;
  final String displayName;
  final String mimeType;

  factory CardImageRef.asset(String path) {
    return CardImageRef(
      id: imageIdForUri(path),
      uri: path,
      kind: CardImageKind.asset,
      provider: CardImageProvider.internal,
      displayName: displayNameForUri(path),
      mimeType: mimeTypeForPath(path),
    );
  }

  factory CardImageRef.localFile(String path) {
    return CardImageRef(
      id: imageIdForUri(path),
      uri: path,
      kind: CardImageKind.localFile,
      provider: CardImageProvider.internal,
      displayName: displayNameForUri(path),
      mimeType: mimeTypeForPath(path),
    );
  }

  factory CardImageRef.externalUri({
    required String uri,
    required CardImageProvider provider,
    String? displayName,
    String? mimeType,
  }) {
    return CardImageRef(
      id: imageIdForUri(uri),
      uri: uri,
      kind: CardImageKind.externalUri,
      provider: provider,
      displayName: displayName ?? displayNameForUri(uri),
      mimeType: mimeType ?? 'image/*',
    );
  }

  factory CardImageRef.fromJson(dynamic json) {
    if (json is String) {
      return json.startsWith('assets/')
          ? CardImageRef.asset(json)
          : CardImageRef.localFile(json);
    }

    final data = json as Map<String, dynamic>;
    return CardImageRef(
      id: data['id'] as String? ?? imageIdForUri(data['uri'] as String),
      uri: data['uri'] as String,
      kind: CardImageKind.fromStorageKey(data['kind'] as String),
      provider: CardImageProvider.fromStorageKey(data['provider'] as String),
      displayName:
          data['display_name'] as String? ??
          displayNameForUri(data['uri'] as String),
      mimeType: data['mime_type'] as String? ?? 'image/*',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uri': uri,
      'kind': kind.storageKey,
      'provider': provider.storageKey,
      'display_name': displayName,
      'mime_type': mimeType,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CardImageRef &&
        other.kind == kind &&
        other.provider == provider &&
        other.uri == uri;
  }

  @override
  int get hashCode => Object.hash(kind, provider, uri);
}

class CardFieldTemplate {
  const CardFieldTemplate({
    required this.key,
    required this.label,
    required this.input,
  });

  final String key;
  final String label;
  final String input;

  factory CardFieldTemplate.fromJson(Map<String, dynamic> json) {
    return CardFieldTemplate(
      key: json['key'] as String,
      label: json['label'] as String,
      input: json['input'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'key': key, 'label': label, 'input': input};
  }
}

class CardTemplate {
  const CardTemplate({
    required this.type,
    required this.label,
    required this.fields,
  });

  final WalletCardType type;
  final String label;
  final List<CardFieldTemplate> fields;

  factory CardTemplate.fromJson(Map<String, dynamic> json) {
    return CardTemplate(
      type: WalletCardType.fromStorageKey(json['type'] as String),
      label: json['label'] as String,
      fields:
          (json['fields'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(CardFieldTemplate.fromJson)
              .toList(),
    );
  }

  CardFieldTemplate? fieldByKey(String key) {
    for (final field in fields) {
      if (field.key == key) {
        return field;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.storageKey,
      'label': label,
      'fields': fields.map((field) => field.toJson()).toList(),
    };
  }
}

class WalletCard {
  const WalletCard({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.images,
    required this.accent,
    required this.fields,
    required this.assetSource,
  });

  final String id;
  final WalletCardType type;
  final String title;
  final String subtitle;
  final CardImageRef image;
  final List<CardImageRef> images;
  final String accent;
  final Map<String, String> fields;
  final Map<String, String> assetSource;

  CardImageRef get primaryImage => images.isEmpty ? image : images.first;

  factory WalletCard.fromJson(Map<String, dynamic> json) {
    final image = CardImageRef.fromJson(json['image']);
    final images =
        (json['images'] as List<dynamic>?)
            ?.map(CardImageRef.fromJson)
            .toList() ??
        [image];

    return WalletCard(
      id: json['id'] as String,
      type: WalletCardType.fromStorageKey(json['type'] as String),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      image: image,
      images: images,
      accent: json['accent'] as String,
      fields: (json['fields'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      assetSource: (json['asset_source'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  WalletCard copyWith({
    CardImageRef? image,
    List<CardImageRef>? images,
    Map<String, String>? fields,
  }) {
    return WalletCard(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      image: image ?? this.image,
      images: images ?? this.images,
      accent: accent,
      fields: fields ?? this.fields,
      assetSource: assetSource,
    );
  }

  WalletCard withPrimaryImage(CardImageRef imageRef) {
    final orderedImages = [
      imageRef,
      for (final item in images)
        if (item != imageRef) item,
    ];

    return copyWith(image: imageRef, images: orderedImages.take(4).toList());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.storageKey,
      'title': title,
      'subtitle': subtitle,
      'image': image.toJson(),
      'images': images.map((image) => image.toJson()).toList(),
      'accent': accent,
      'fields': fields,
      'asset_source': assetSource,
    };
  }
}

class WalletCardBundle {
  const WalletCardBundle({required this.templates, required this.cards});

  final List<CardTemplate> templates;
  final List<WalletCard> cards;

  CardTemplate templateFor(WalletCardType type) {
    return templates.firstWhere((template) => template.type == type);
  }
}

class WalletConnections {
  const WalletConnections({
    this.syncthingFolderUri,
    this.protonDriveConnected = false,
  });

  final String? syncthingFolderUri;
  final bool protonDriveConnected;

  bool get syncthingConnected =>
      syncthingFolderUri != null && syncthingFolderUri!.isNotEmpty;

  factory WalletConnections.fromJson(Map<String, dynamic> json) {
    return WalletConnections(
      syncthingFolderUri: json['syncthing_folder_uri'] as String?,
      protonDriveConnected: json['proton_drive_connected'] as bool? ?? false,
    );
  }

  WalletConnections copyWith({
    String? syncthingFolderUri,
    bool clearSyncthingFolderUri = false,
    bool? protonDriveConnected,
  }) {
    return WalletConnections(
      syncthingFolderUri:
          clearSyncthingFolderUri
              ? null
              : syncthingFolderUri ?? this.syncthingFolderUri,
      protonDriveConnected: protonDriveConnected ?? this.protonDriveConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'syncthing_folder_uri': syncthingFolderUri,
      'proton_drive_connected': protonDriveConnected,
    };
  }
}

class WalletConnectionStore {
  const WalletConnectionStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  static const _connectionsStorageKey = 'akator_wallet_connections_v1';

  final FlutterSecureStorage _secureStorage;

  Future<WalletConnections> load() async {
    try {
      final payload = await _secureStorage.read(key: _connectionsStorageKey);
      if (payload == null) {
        return const WalletConnections();
      }
      return WalletConnections.fromJson(
        jsonDecode(payload) as Map<String, dynamic>,
      );
    } on MissingPluginException {
      return const WalletConnections();
    }
  }

  Future<void> save(WalletConnections connections) async {
    try {
      await _secureStorage.write(
        key: _connectionsStorageKey,
        value: jsonEncode(connections.toJson()),
      );
    } on MissingPluginException {
      return;
    }
  }
}

class WalletCardStore {
  const WalletCardStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
    bool loadSavedCards = true,
  }) : _secureStorage = secureStorage,
       _loadSavedCards = loadSavedCards;

  static const _cardsStorageKey = 'akator_wallet_cards_v1';

  final FlutterSecureStorage _secureStorage;
  final bool _loadSavedCards;

  Future<WalletCardBundle> load() async {
    final payloads = await Future.wait([
      rootBundle.loadString('assets/data/card_templates.json'),
      rootBundle.loadString('assets/data/dummy_cards.json'),
    ]);

    final templatesJson = jsonDecode(payloads[0]) as Map<String, dynamic>;
    final cardsPayload =
        _loadSavedCards
            ? await _readSavedCardsPayload() ?? payloads[1]
            : payloads[1];
    final cardsJson = jsonDecode(cardsPayload) as Map<String, dynamic>;

    return WalletCardBundle(
      templates:
          (templatesJson['templates'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(CardTemplate.fromJson)
              .toList(),
      cards:
          (cardsJson['cards'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(WalletCard.fromJson)
              .toList(),
    );
  }

  Future<void> saveCards(List<WalletCard> cards) async {
    final payload = jsonEncode({
      'cards': cards.map((card) => card.toJson()).toList(),
    });

    try {
      await _secureStorage.write(key: _cardsStorageKey, value: payload);
    } on MissingPluginException {
      return;
    }
  }

  Future<String?> _readSavedCardsPayload() async {
    try {
      return _secureStorage.read(key: _cardsStorageKey);
    } on MissingPluginException {
      return null;
    }
  }
}

String imageIdForUri(String uri) {
  var hash = 0x811c9dc5;
  for (final unit in uri.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String displayNameForUri(String uri) {
  final parsed = Uri.tryParse(uri);
  final segments = parsed?.pathSegments;
  if (segments != null && segments.isNotEmpty) {
    return Uri.decodeComponent(segments.last);
  }

  final slash = uri.lastIndexOf('/');
  return slash == -1 ? uri : uri.substring(slash + 1);
}

String mimeTypeForPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
