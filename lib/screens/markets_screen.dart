import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/format.dart';
import '../data/dreamdex_models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  Future<List<PerpMarket>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= Services.of(context).dreamdex.markets();
  }

  Future<void> _reload() async {
    final f = Services.of(context).dreamdex.markets(refresh: true);
    setState(() => _future = f);
    await f.catchError((_) => <PerpMarket>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perp markets'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<List<PerpMarket>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorRetry(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final markets = snap.data!;
          if (markets.isEmpty) {
            return const EmptyState(
              icon: Icons.candlestick_chart_outlined,
              title: 'No perp markets found',
              message: 'The dreamDEX indexer returned no perp markets.',
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ResponsiveListView(
              physics: const AlwaysScrollableScrollPhysics(),
              bottom: 24,
              children: [
                for (final m in markets) ...[
                  _MarketRow(market: m),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({required this.market});

  final PerpMarket market;

  @override
  Widget build(BuildContext context) {
    final m = market;
    final funding = m.fundingPercentPerWindow;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MarketDetailScreen(market: m))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceHigh,
                child: Text(
                  m.baseSymbol.isEmpty ? '?' : m.baseSymbol.substring(0, m.baseSymbol.length < 3 ? m.baseSymbol.length : 3),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.symbol, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      'Funding ${formatPercent(funding, places: 4)} / ${m.fundingWindowHours.toStringAsFixed(0)}h',
                      style: TextStyle(color: AppColors.pnl(-funding), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(formatPrice(m.price), style: numStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketDetailScreen extends StatefulWidget {
  const MarketDetailScreen({super.key, required this.market});

  final PerpMarket market;

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  static const _intervals = <(String, int)>[('5m', 300), ('15m', 900), ('1h', 3600), ('4h', 14400), ('1d', 86400)];
  int _interval = 3600;
  Future<List<Candle>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Candle>> _load() => Services.of(context).dreamdex.candles(widget.market, _interval);

  @override
  Widget build(BuildContext context) {
    final m = widget.market;
    final funding = m.fundingPercentPerWindow;
    return Scaffold(
      appBar: AppBar(title: Text(m.symbol)),
      body: ResponsiveListView(
        maxWidth: 900,
        bottom: 32,
        children: [
          Text(formatPrice(m.price), style: numStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Mark price · ${m.quoteSymbol}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, secs) in _intervals)
                ChoiceChip(
                  label: Text(label),
                  selected: _interval == secs,
                  onSelected: (_) => setState(() {
                    _interval = secs;
                    _future = _load();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
              child: FutureBuilder<List<Candle>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return SizedBox(
                      height: 240,
                      child: Center(child: Text('${snap.error}', style: const TextStyle(color: AppColors.muted))),
                    );
                  }
                  if (!snap.hasData) {
                    return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
                  }
                  return CandleChart(candles: snap.data!);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          StatGrid(tiles: [
            StatTile(label: 'Index price', value: formatPrice(m.indexPrice)),
            StatTile(label: 'Last trade', value: formatPrice(m.lastPrice)),
            StatTile(
              label: 'Funding / ${m.fundingWindowHours.toStringAsFixed(0)}h',
              value: formatPercent(funding, places: 4),
              valueColor: AppColors.pnl(-funding),
            ),
            StatTile(label: 'Open interest', value: '${formatCompact(m.openInterest)} ${m.baseSymbol}'),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Positive funding: longs pay shorts. Negative: shorts pay longs.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse(AppConfig.dreamDexAppUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.bolt_rounded),
            label: Text('Trade ${m.symbol} on dreamDEX'),
          ),
        ],
      ),
    );
  }
}
