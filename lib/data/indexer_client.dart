import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class IndexerException implements Exception {
  IndexerException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Minimal GraphQL client for the dreamDEX indexer (Hasura).
///
/// Plain HTTP POST: no Dart SDK exists for dreamDEX, and every read this app
/// needs is a public indexer query, so no keys or signing are involved.
class IndexerClient {
  IndexerClient({http.Client? client, String? url})
      : _client = client ?? http.Client(),
        _url = Uri.parse(url ?? AppConfig.indexerUrl);

  final http.Client _client;
  final Uri _url;

  Future<Map<String, dynamic>> query(
    String document, [
    Map<String, dynamic> variables = const {},
  ]) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            _url,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'query': document, 'variables': variables}),
          )
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw IndexerException('dreamDEX indexer timed out. Pull to retry.');
    } catch (e) {
      throw IndexerException('Could not reach the dreamDEX indexer. Check your connection.');
    }

    if (res.statusCode != 200) {
      throw IndexerException('dreamDEX indexer returned HTTP ${res.statusCode}.');
    }
    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      throw IndexerException('Unexpected indexer response.');
    }
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final first = errors.first;
      final msg = first is Map ? first['message']?.toString() : null;
      throw IndexerException('Indexer error: ${msg ?? 'unknown'}');
    }
    final data = body['data'];
    if (data is! Map) throw IndexerException('Indexer returned no data.');
    return data.cast<String, dynamic>();
  }
}
