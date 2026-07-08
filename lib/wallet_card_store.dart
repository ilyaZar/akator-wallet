import 'dart:convert';

import 'package:flutter/services.dart';

enum WalletCardType {
  creditCard('credit_card'),
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
  final String image;
  final List<String> images;
  final String accent;
  final Map<String, String> fields;
  final Map<String, String> assetSource;

  String get primaryImage => images.isEmpty ? image : images.first;

  factory WalletCard.fromJson(Map<String, dynamic> json) {
    final image = json['image'] as String;
    final images =
        (json['images'] as List<dynamic>?)
            ?.map((item) => item as String)
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
    String? image,
    List<String>? images,
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

  WalletCard withPrimaryImage(String imagePath) {
    final orderedImages = [
      imagePath,
      for (final item in images)
        if (item != imagePath) item,
    ];

    return copyWith(image: imagePath, images: orderedImages.take(4).toList());
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.storageKey,
      'title': title,
      'subtitle': subtitle,
      'image': image,
      'images': images,
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

class WalletCardStore {
  const WalletCardStore();

  Future<WalletCardBundle> load() async {
    final payloads = await Future.wait([
      rootBundle.loadString('assets/data/card_templates.json'),
      rootBundle.loadString('assets/data/dummy_cards.json'),
    ]);

    final templatesJson = jsonDecode(payloads[0]) as Map<String, dynamic>;
    final cardsJson = jsonDecode(payloads[1]) as Map<String, dynamic>;

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
}
