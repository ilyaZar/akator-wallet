import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'wallet_card_store.dart';

const remoteStorageMaxImageBytes = 12 << 20;

class RemoteStorageEntry {
  const RemoteStorageEntry({
    required this.path,
    required this.name,
    required this.kind,
    required this.mimeType,
    required this.size,
  });

  final String path;
  final String name;
  final String kind;
  final String mimeType;
  final int size;

  bool get isFolder => kind == 'folder';
  bool get isImage => kind == 'image';

  factory RemoteStorageEntry.fromJson(Map<String, dynamic> json) {
    return RemoteStorageEntry(
      path: json['path'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String,
      mimeType: json['mimeType'] as String? ?? 'image/*',
      size: json['size'] as int? ?? 0,
    );
  }
}

class RemoteStorageHealth {
  const RemoteStorageHealth({
    required this.apiVersion,
    required this.backends,
    required this.statuses,
  });

  final int apiVersion;
  final Map<CardImageProvider, bool> backends;
  final Map<CardImageProvider, String> statuses;

  bool available(CardImageProvider provider) => backends[provider] ?? false;

  String status(CardImageProvider provider) =>
      statuses[provider] ?? 'not_configured';
}

class RemoteStorageException implements Exception {
  const RemoteStorageException(this.code);

  final String code;

  @override
  String toString() => 'Remote storage error: $code';
}

abstract class RemoteStorage {
  Future<RemoteStorageHealth> health();

  Future<List<RemoteStorageEntry>> list(
    CardImageProvider provider, {
    String path = '',
  });

  Future<Uint8List> read(CardImageProvider provider, String path);

  Future<RemoteStorageEntry> write(
    CardImageProvider provider,
    String path,
    Uint8List data,
  );
}

class CompanionStorageClient implements RemoteStorage {
  CompanionStorageClient({
    required String baseUrl,
    required String accessToken,
    bool allowInsecureHttp = false,
    HttpClient? httpClient,
  }) : _baseUri = validateCompanionBaseUrl(
         baseUrl,
         allowInsecureHttp: allowInsecureHttp,
       ),
       _accessToken =
           _validAccessToken.hasMatch(accessToken)
               ? accessToken
               : throw const FormatException('Invalid companion access token'),
       _httpClient = httpClient ?? HttpClient();

  final Uri _baseUri;
  final String _accessToken;
  final HttpClient _httpClient;

  void close() {
    _httpClient.close(force: true);
  }

  @override
  Future<RemoteStorageHealth> health() async {
    final response = await _request('GET', '/v1/health');
    return _parseResponse(() {
      final payload = jsonDecode(utf8.decode(response)) as Map<String, dynamic>;
      final apiVersion = payload['apiVersion'] as int? ?? 0;
      if (apiVersion != 1) {
        throw const RemoteStorageException('unsupported_api_version');
      }

      final availability = <CardImageProvider, bool>{};
      final statuses = <CardImageProvider, String>{};
      for (final item in payload['backends'] as List<dynamic>? ?? const []) {
        final backend = item as Map<String, dynamic>;
        final provider = _providerForBackend(backend['id'] as String?);
        if (provider != null) {
          availability[provider] = backend['available'] as bool? ?? false;
          statuses[provider] = backend['status'] as String? ?? 'unavailable';
        }
      }
      return RemoteStorageHealth(
        apiVersion: apiVersion,
        backends: availability,
        statuses: statuses,
      );
    });
  }

  @override
  Future<List<RemoteStorageEntry>> list(
    CardImageProvider provider, {
    String path = '',
  }) async {
    final response = await _request(
      'GET',
      '/v1/backends/${provider.storageKey}/entries',
      query: {'path': path},
    );
    return _parseResponse(() {
      final payload = jsonDecode(utf8.decode(response)) as Map<String, dynamic>;
      return (payload['entries'] as List<dynamic>? ?? const [])
          .map(
            (item) => RemoteStorageEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false);
    });
  }

  @override
  Future<Uint8List> read(CardImageProvider provider, String path) async {
    final response = await _request(
      'GET',
      '/v1/backends/${provider.storageKey}/file',
      query: {'path': path},
      maxResponseBytes: remoteStorageMaxImageBytes,
    );
    return Uint8List.fromList(response);
  }

  @override
  Future<RemoteStorageEntry> write(
    CardImageProvider provider,
    String path,
    Uint8List data,
  ) async {
    if (data.length > remoteStorageMaxImageBytes) {
      throw const RemoteStorageException('image_too_large');
    }
    final response = await _request(
      'PUT',
      '/v1/backends/${provider.storageKey}/file',
      query: {'path': path},
      body: data,
      maxResponseBytes: 64 << 10,
    );
    return _parseResponse(
      () => RemoteStorageEntry.fromJson(
        jsonDecode(utf8.decode(response)) as Map<String, dynamic>,
      ),
    );
  }

  Future<List<int>> _request(
    String method,
    String route, {
    Map<String, String>? query,
    Uint8List? body,
    int maxResponseBytes = 1 << 20,
  }) async {
    final uri = _baseUri.replace(
      path: '${_baseUri.path}$route',
      queryParameters: query,
    );

    try {
      final request = await _httpClient
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 10));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_accessToken',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.binary;
        request.contentLength = body.length;
        request.add(body);
      }

      final response = await request.close().timeout(
        const Duration(minutes: 2),
      );
      final bytes = await _readBounded(response, maxResponseBytes);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw RemoteStorageException(_errorCode(bytes));
      }
      return bytes;
    } on RemoteStorageException {
      rethrow;
    } on TimeoutException {
      throw const RemoteStorageException('timeout');
    } on HandshakeException {
      throw const RemoteStorageException('tls_failed');
    } on SocketException {
      throw const RemoteStorageException('unreachable');
    } on FormatException {
      throw const RemoteStorageException('invalid_response');
    } on TypeError {
      throw const RemoteStorageException('invalid_response');
    } on HttpException {
      throw const RemoteStorageException('request_failed');
    }
  }

  T _parseResponse<T>(T Function() parse) {
    try {
      return parse();
    } on RemoteStorageException {
      rethrow;
    } on FormatException {
      throw const RemoteStorageException('invalid_response');
    } on TypeError {
      throw const RemoteStorageException('invalid_response');
    }
  }

  Future<List<int>> _readBounded(HttpClientResponse response, int limit) async {
    if (response.contentLength > limit) {
      throw const RemoteStorageException('response_too_large');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > limit) {
        throw const RemoteStorageException('response_too_large');
      }
    }
    return builder.takeBytes();
  }

  String _errorCode(List<int> body) {
    try {
      final payload = jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
      return payload['error'] as String? ?? 'request_failed';
    } on Object {
      return 'request_failed';
    }
  }
}

final _validAccessToken = RegExp(r'^[A-Za-z0-9._~-]{32,256}$');

Uri validateCompanionBaseUrl(String value, {bool allowInsecureHttp = false}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid companion URL');
  }
  if (uri.scheme != 'https' && !(allowInsecureHttp && uri.scheme == 'http')) {
    throw const FormatException('Companion URL must use HTTPS');
  }
  final normalizedPath =
      uri.path == '/' || uri.path.isEmpty
          ? ''
          : uri.path.replaceFirst(RegExp(r'/$'), '');
  return uri.replace(path: normalizedPath);
}

CardImageProvider? _providerForBackend(String? backend) {
  return switch (backend) {
    'syncthing' => CardImageProvider.syncthing,
    'proton_drive' => CardImageProvider.protonDrive,
    _ => null,
  };
}
