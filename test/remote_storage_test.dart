import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:akator_wallet/remote_storage.dart';
import 'package:akator_wallet/wallet_card_store.dart';

void main() {
  test('validates secure companion URLs', () {
    expect(
      validateCompanionBaseUrl('https://wallet.example.test:8787').toString(),
      'https://wallet.example.test:8787',
    );
    expect(
      () => validateCompanionBaseUrl('http://127.0.0.1:8787'),
      throwsFormatException,
    );
    expect(
      validateCompanionBaseUrl(
        'http://127.0.0.1:8787',
        allowInsecureHttp: true,
      ).toString(),
      'http://127.0.0.1:8787',
    );
    expect(
      validateCompanionBaseUrl(
        'http://localhost:8787',
        allowInsecureHttp: true,
      ).toString(),
      'http://localhost:8787',
    );
    expect(
      validateCompanionBaseUrl(
        'http://[::1]:8787',
        allowInsecureHttp: true,
      ).toString(),
      'http://[::1]:8787',
    );
    for (final insecureUrl in [
      'http://192.168.1.10:8787',
      'http://wallet-host.local:8787',
      'http://127.0.0.1.example.test:8787',
    ]) {
      expect(
        () => validateCompanionBaseUrl(insecureUrl, allowInsecureHttp: true),
        throwsFormatException,
      );
    }
    expect(
      () => validateCompanionBaseUrl('https://token@example.test:8787'),
      throwsFormatException,
    );
    expect(
      () => CompanionStorageClient(
        baseUrl: 'https://wallet.example.test',
        accessToken: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\r\nInjected: value',
      ),
      throwsFormatException,
    );
  });

  test('performs authenticated health, list, read, and write calls', () async {
    const token = '0123456789abcdef0123456789abcdef';
    final requests = <HttpRequest>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      requests.add(request);
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer $token',
      );
      switch (request.uri.path) {
        case '/v1/health':
          _json(request.response, {
            'apiVersion': 1,
            'backends': [
              {'id': 'syncthing', 'available': true, 'status': 'ok'},
              {
                'id': 'proton_drive',
                'available': false,
                'status': 'unavailable',
              },
            ],
          });
        case '/v1/backends/syncthing/entries':
          _json(request.response, {
            'entries': [
              {
                'path': 'cards/front.png',
                'name': 'front.png',
                'kind': 'image',
                'mimeType': 'image/png',
                'size': 68,
              },
            ],
          });
        case '/v1/backends/syncthing/file':
          if (request.method == 'PUT') {
            final body = await request.fold<List<int>>(
              <int>[],
              (result, chunk) => result..addAll(chunk),
            );
            expect(body, [1, 2, 3]);
            request.response.statusCode = HttpStatus.created;
            _json(request.response, {
              'path': 'cards/front.png',
              'name': 'front.png',
              'kind': 'image',
              'mimeType': 'image/png',
              'size': 3,
            });
          } else {
            request.response.headers.contentType = ContentType('image', 'png');
            request.response.add([1, 2, 3]);
            await request.response.close();
          }
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    });

    final client = CompanionStorageClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      accessToken: token,
      allowInsecureHttp: true,
    );
    addTearDown(client.close);

    final health = await client.health();
    expect(health.available(CardImageProvider.syncthing), isTrue);
    expect(health.available(CardImageProvider.protonDrive), isFalse);
    expect(health.status(CardImageProvider.syncthing), 'ok');

    final entries = await client.list(CardImageProvider.syncthing);
    expect(entries.single.path, 'cards/front.png');

    expect(
      await client.read(CardImageProvider.syncthing, entries.single.path),
      [1, 2, 3],
    );
    final uploaded = await client.write(
      CardImageProvider.syncthing,
      entries.single.path,
      Uint8List.fromList([1, 2, 3]),
    );
    expect(uploaded.path, entries.single.path);
    expect(requests, hasLength(4));
  });

  test('redacts server failures behind stable error codes', () async {
    const token = '0123456789abcdef0123456789abcdef';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      _json(request.response, {'error': 'backend_unavailable'});
    });

    final client = CompanionStorageClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      accessToken: token,
      allowInsecureHttp: true,
    );
    addTearDown(client.close);

    await expectLater(
      client.health(),
      throwsA(
        isA<RemoteStorageException>().having(
          (error) => error.code,
          'code',
          'backend_unavailable',
        ),
      ),
    );
  });

  test('rejects malformed successful responses', () async {
    const token = '0123456789abcdef0123456789abcdef';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      _json(request.response, {
        'apiVersion': 'secret malformed value',
        'backends': [],
      });
    });

    final client = CompanionStorageClient(
      baseUrl: 'http://127.0.0.1:${server.port}',
      accessToken: token,
      allowInsecureHttp: true,
    );
    addTearDown(client.close);

    await expectLater(
      client.health(),
      throwsA(
        isA<RemoteStorageException>().having(
          (error) => error.code,
          'code',
          'invalid_response',
        ),
      ),
    );
  });
}

void _json(HttpResponse response, Object value) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
  response.close();
}
