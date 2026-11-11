import 'dart:io';

import 'package:brisk_download_engine/src/download_engine/client/http_client_settings.dart';
import 'package:brisk_download_engine/src/download_engine/client/custom_base_client.dart';
import 'package:brisk_download_engine/src/download_engine/client/dart_http_client.dart';
import 'package:dartx/dartx.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

class HttpClientBuilder {
  static Future<CustomBaseClient> buildClient([
    HttpClientSettings? clientSettings,
  ]) async {
    final proxySetting = clientSettings?.proxySetting;
    if (proxySetting == null || !proxySetting.proxyEnabled) {
      return DartHttpClient(Client());
    }
    final proxyAddress =
        "${proxySetting.proxyAddress}:${proxySetting.proxyPort}";
    final httpClient = HttpClient()
      ..findProxy = (uri) {
        return "PROXY $proxyAddress";
      };
    if (proxySetting.username != null && proxySetting.username!.isNotBlank) {
      httpClient.addProxyCredentials(
        proxySetting.proxyAddress,
        int.parse(proxySetting.proxyPort),
        '',
        HttpClientBasicCredentials(
          proxySetting.username!,
          proxySetting.password ?? "",
        ),
      );
    }
    return DartHttpClient(IOClient(httpClient));
  }
}
