import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:brisk_download_engine/brisk_download_engine.dart';
import 'package:brisk_download_engine/src/download_engine/client/http_client_builder.dart';
import 'package:brisk_download_engine/src/download_engine/util/constants.dart';
import 'package:path/path.dart';

import 'package:encrypt/encrypt.dart';
import 'package:rhttp/rhttp.dart';

/// Decrypts an AES-128 encrypted file.
/// If chunked mode is enabled, it decrypts the file in chunks to reduce memory usage.
Future<void> decryptAes128File(
  File file,
  Uint8List key,
  IV iv, {
  bool chunked = false,
}) async {
  final aesKey = Key(key);
  final encrypter = Encrypter(AES(aesKey, mode: AESMode.cbc));
  if (chunked) {
    const chunkSize = 5 * 1024 * 1024;
    final outputFile = File(join(file.parent.path, "Decrypted.ts"));
    final outputFileOpen = outputFile.openWrite();
    final inputStream = file.openSync();
    try {
      final buffer = Uint8List(chunkSize);
      int bytesRead;
      while ((bytesRead = inputStream.readIntoSync(buffer)) > 0) {
        final chunk = Uint8List.sublistView(buffer, 0, bytesRead);
        final decryptedBytes = encrypter.decryptBytes(Encrypted(chunk), iv: iv);
        outputFileOpen.add(decryptedBytes);
      }
    } finally {
      await outputFileOpen.close();
      inputStream.closeSync();
    }
    final filePath = file.path;
    file.deleteSync();
    outputFile.renameSync(filePath);
    return;
  }
  final decryptedBytes = encrypter.decryptBytes(
    Encrypted(file.readAsBytesSync()),
    iv: iv,
  );
  file.writeAsBytesSync(decryptedBytes, mode: FileMode.write);
}

/// Set decryption initialization vector based on the sequence number of the segment as a big-endian
/// This is only used when the m3u8 requires a decryption process and does not provide an IV itself.
/// Thus, based on the m3u8 specification, the IV should be derived from the sequence number.
IV deriveImplicitIV(int sequenceNumber) {
  final iv = Uint8List(16);
  iv.buffer.asByteData().setUint64(8, sequenceNumber);
  return IV(iv);
}

/// Set decryption initialization vector based on the IV value defined in the m3u8 file
IV deriveExplicitIV(String ivString) {
  if (ivString.startsWith("0x")) {
    ivString = ivString.substring(2);
  }
  final ivBytes = List.generate(
    ivString.length ~/ 2,
    (i) => int.parse(ivString.substring(i * 2, i * 2 + 2), radix: 16),
  );
  return IV(Uint8List.fromList(ivBytes));
}

Future<String> fetchBodyString(
  String url, {
  HttpClientSettings? clientSettings,
  Map<String, String> headers = const {},
}) async {
  final client = await HttpClientBuilder.buildClient(clientSettings);
  try {
    var requestHeaders = headers;
    requestHeaders.addAll(userAgentHeader);
    final response = await client.get(
      Uri.parse(url),
      headers: requestHeaders,
    );
    if (response.statusCode == 200) {
      return response.body;
    } else {
      print("Failed to fetch... status code ${response.statusCode}");
      throw Exception('Failed to fetch!');
    }
  } catch (e) {
    print(e);
    rethrow;
  }
}

/// Fetches the decryption key from the url specified in m3u8
Future<Uint8List> fetchDecryptionKey(
  String keyUrl, {
  HttpClientSettings? clientSettings,
}) async {
  final client = await HttpClientBuilder.buildClient(clientSettings);
  try {
    final response = await client.get(
      Uri.parse(keyUrl),
      headers: {
        "User-Agent": userAgentHeader.values.first,
      },
    );
    if (response.statusCode == 200) {
      return utf8.encode(response.body.trim());
    } else {
      print("Failed to fetch key... status code ${response.statusCode}");
      throw Exception('Failed to fetch decryption key.');
    }
  } catch (e) {
    print(e);
    rethrow;
  }
}
