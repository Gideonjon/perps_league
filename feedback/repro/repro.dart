// Read-only reproduction for the three feedback items in feedback/.
// No wallet or keys needed. From the project root:
//
//   dart run feedback/repro/repro.dart
//
// Writes feedback/evidence/01-*.json, 02-*.json and 03-*.json with the exact
// requests, responses and timings, stamped with time and indexer head block.
import 'dart:convert';
import 'dart:io';

const indexer = 'https://hideki-dev.smk.somnia.host/v1/graphql';
const sdkVersion = '@somnia-chain/markets-sdk@0.32.1';
final outDir = Directory('feedback/evidence');

Future<void> main() async {
  outDir.createSync(recursive: true);
  final head = await _head();
  stdout.writeln('Indexer head: $head');

  await _entryPriceScale(head);
  await _sizeSign(head);
  await _fillLatency(head);

  stdout.writeln('\nDone. Review feedback/evidence/*.json before submitting.');
}

// ---------------------------------------------------------------- 01

Future<void> _entryPriceScale(Map<String, dynamic> head) async {
  stdout.writeln('\n01 entryPriceX18 scale');
  const q1 = r'''
query { PerpPosition(where: { size: { _neq: "0" } }, order_by: { updatedAt: desc }, limit: 1) {
  pool account size isLong entryPriceX18 updatedAt } }''';
  final r1 = await _gql(q1);
  final pos = (r1.data['PerpPosition'] as List).cast<Map<String, dynamic>>();
  if (pos.isEmpty) return _skip('01-entry-price-scale', 'No open positions found.', head);
  final p = pos.first;

  const q2 = r'''
query ($pool: String!) { Market(where: { poolAddress: { _eq: $pool } }, limit: 1) {
  baseSymbol quoteSymbol baseDecimals quoteDecimals markPrice lastPrice } }''';
  final r2 = await _gql(q2, variables: {'pool': p['pool']});
  final m = (r2.data['Market'] as List).first as Map<String, dynamic>;
  final qd = (m['quoteDecimals'] as num).toInt();
  final raw = BigInt.parse(p['entryPriceX18'].toString());

  final asX18 = raw / BigInt.from(10).pow(18);
  final asQuote = raw / BigInt.from(10).pow(qd);
  final mark = BigInt.parse((m['markPrice'] ?? m['lastPrice']).toString()) / BigInt.from(10).pow(qd);

  _write('01-entry-price-scale', head, {
    'requests': [r1.toJson(), r2.toJson()],
    'analysis': {
      'market': '${m['baseSymbol']}-PERP',
      'entryPriceX18_raw': raw.toString(),
      'entryPriceX18 / 1e18 (what the name implies)': asX18,
      'entryPriceX18 / 10^quoteDecimals': asQuote,
      'markPrice / 10^quoteDecimals': mark,
      'conclusion': 'The /10^quoteDecimals value is near the mark price; the /1e18 value is not.',
    },
  });
  stdout.writeln('  /1e18 = $asX18   /10^$qd = $asQuote   mark = $mark');
}

// ---------------------------------------------------------------- 02

Future<void> _sizeSign(Map<String, dynamic> head) async {
  stdout.writeln('\n02 size sign conventions');
  const q1 = r'''
query { PerpPosition(where: { size: { _neq: "0" }, isLong: { _eq: false } }, order_by: { updatedAt: desc }, limit: 1) {
  pool account size isLong updatedAt } }''';
  final r1 = await _gql(q1);
  final pos = (r1.data['PerpPosition'] as List).cast<Map<String, dynamic>>();
  if (pos.isEmpty) return _skip('02-size-sign', 'No open short positions found.', head);
  final p = pos.first;

  const q2 = r'''
query ($acct: String!, $pool: String!) { PerpPositionChange(
  where: { account: { _eq: $acct }, pool: { _eq: $pool } },
  order_by: [{ blockNumber: desc }, { logIndex: desc }], limit: 1) {
  kind sizeBefore sizeAfter timestamp txHash } }''';
  final r2 = await _gql(q2, variables: {'acct': p['account'], 'pool': p['pool']});
  final changes = (r2.data['PerpPositionChange'] as List).cast<Map<String, dynamic>>();
  final c = changes.isEmpty ? null : changes.first;

  _write('02-size-sign', head, {
    'requests': [r1.toJson(), r2.toJson()],
    'analysis': {
      'account': p['account'],
      'pool': p['pool'],
      'PerpPosition.size': p['size'],
      'PerpPosition.isLong': p['isLong'],
      'PerpPositionChange.sizeAfter (latest)': c?['sizeAfter'],
      'conclusion': 'Same short position: PerpPosition.size is unsigned (direction in isLong); '
          'PerpPositionChange.sizeAfter is signed negative.',
    },
  });
  stdout.writeln('  PerpPosition.size = ${p['size']} (isLong=${p['isLong']})   change.sizeAfter = ${c?['sizeAfter']}');
}

// ---------------------------------------------------------------- 03

Future<void> _fillLatency(Map<String, dynamic> head) async {
  stdout.writeln('\n03 wallet fill query latency');
  const pools = r'''
query ($t: String!) { Market(where: { marketType: { _eq: $t } }, limit: 500) { poolAddress } }''';
  final perp = await _gql(pools, variables: {'t': 'PERP'});
  final spot = await _gql(pools, variables: {'t': 'SPOT'});
  final perpPools = [for (final m in perp.data['Market'] as List) (m['poolAddress'] as String).toLowerCase()];
  final spotPools = [for (final m in spot.data['Market'] as List) (m['poolAddress'] as String).toLowerCase()];
  if (perpPools.isEmpty || spotPools.isEmpty) {
    return _skip('03-fill-query-latency', 'Could not list perp and spot pools.', head);
  }

  // A spot-heavy wallet: the maker of the most recent spot fill.
  const latestSpot = r'''
query ($pools: [String!]!) { Fill(where: { pool: { _in: $pools } }, order_by: { timestamp: desc }, limit: 1) { maker taker } }''';
  final ls = await _gql(latestSpot, variables: {'pools': spotPools});
  final fills = ls.data['Fill'] as List;
  if (fills.isEmpty) return _skip('03-fill-query-latency', 'No spot fills found.', head);
  final acct = ((fills.first as Map)['maker'] ?? (fills.first as Map)['taker']).toString().toLowerCase();

  const fillQuery = r'''
query ($where: Fill_bool_exp!) { Fill(where: $where, order_by: { timestamp: desc }, limit: 50) { id timestamp } }''';
  final since = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7 * 86400;
  final base = {
    'pool': {'_in': perpPools},
    '_or': [
      {'maker': {'_eq': acct}},
      {'taker': {'_eq': acct}},
    ],
  };
  final bounded = {
    ...base,
    'timestamp': {'_gte': since.toString()},
  };

  final unboundedRuns = <Map<String, dynamic>>[];
  final boundedRuns = <Map<String, dynamic>>[];
  for (var i = 0; i < 3; i++) {
    final u = await _gql(fillQuery, variables: {'where': base}, allowError: true);
    unboundedRuns.add({'ms': u.ms, 'rows': u.rows('Fill'), 'error': u.error});
    final b = await _gql(fillQuery, variables: {'where': bounded}, allowError: true);
    boundedRuns.add({'ms': b.ms, 'rows': b.rows('Fill'), 'error': b.error});
    stdout.writeln('  run ${i + 1}: unbounded ${u.ms} ms, 7-day bound ${b.ms} ms');
  }
  int median(List<Map<String, dynamic>> r) => ((r.map((e) => e['ms'] as int).toList()..sort())[1]);
  final mu = median(unboundedRuns), mb = median(boundedRuns);

  _write('03-fill-query-latency', head, {
    'account': acct,
    'perpPoolCount': perpPools.length,
    'query': fillQuery,
    'whereUnbounded': base,
    'whereBounded7d': bounded,
    'unboundedRuns': unboundedRuns,
    'boundedRuns': boundedRuns,
    'medianMs': {'unbounded': mu, 'bounded7d': mb},
    'note': mu < 2000
        ? 'Unbounded query was fast in this run. The issue may be fixed or depend on the account; '
            'consider NOT submitting item 03 unless you can reproduce a slow case.'
        : 'Unbounded query is ${(mu / (mb == 0 ? 1 : mb)).toStringAsFixed(0)}x slower than the 7-day bound.',
  });
  if (mu < 2000) {
    stdout.writeln('  ⚠ Unbounded was fast here (median $mu ms). Do not submit item 03 unless you can reproduce it.');
  }
}

// ---------------------------------------------------------------- helpers

class _Result {
  _Result(this.query, this.variables, this.status, this.body, this.ms, this.error);
  final String query;
  final Map<String, dynamic> variables;
  final int status;
  final Map<String, dynamic> body;
  final int ms;
  final String? error;

  Map<String, dynamic> get data => (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
  int? rows(String key) => (data[key] as List?)?.length;

  Map<String, dynamic> toJson() => {
        'request': {'url': indexer, 'query': query, 'variables': variables},
        'response': {'status': status, 'ms': ms, 'body': body},
      };
}

Future<_Result> _gql(String query, {Map<String, dynamic> variables = const {}, bool allowError = false}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final sw = Stopwatch()..start();
  try {
    final req = await client.postUrl(Uri.parse(indexer));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'query': query, 'variables': variables}));
    final res = await req.close().timeout(const Duration(seconds: 90));
    final text = await res.transform(utf8.decoder).join();
    sw.stop();
    final body = (jsonDecode(text) as Map).cast<String, dynamic>();
    final errors = body['errors'];
    final err = errors is List && errors.isNotEmpty ? errors.first.toString() : null;
    if (err != null && !allowError) throw StateError('Indexer error: $err');
    return _Result(query, variables, res.statusCode, body, sw.elapsedMilliseconds, err);
  } on Exception catch (e) {
    sw.stop();
    if (!allowError) rethrow;
    return _Result(query, variables, 0, const {}, sw.elapsedMilliseconds, e.toString());
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> _head() async {
  final r = await _gql('query { chain_metadata { chain_id latest_processed_block } }');
  return {
    'chain_metadata': r.data['chain_metadata'],
    'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'indexer': indexer,
    'sdk': sdkVersion,
    'network': 'Somnia Tokyo testnet (Hideki, chain 50383)',
  };
}

void _write(String name, Map<String, dynamic> head, Map<String, dynamic> payload) {
  final f = File('${outDir.path}/$name.json');
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({'environment': head, ...payload}));
  stdout.writeln('  → ${f.path}');
}

void _skip(String name, String why, Map<String, dynamic> head) {
  stdout.writeln('  ⚠ $why Could not reproduce right now; do not submit this item without evidence.');
  _write(name, head, {'skipped': why});
}
