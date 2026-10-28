# Wallet-scoped `Fill` queries are slow without a time bound, so perp trade history is capped at 7 days
Severity: normal
Area: API

## Steps to reproduce
1. Take an account that trades mostly spot (for example the maker of the latest fill in a SPOT pool).
2. Run the query shape `getPerpPortfolio` uses, scoped to perp pools, **without** a time bound:
   ```graphql
   query ($perpPools: [String!]!, $acct: String!) {
     Fill(where: { pool: { _in: $perpPools }, _or: [{ maker: { _eq: $acct } }, { taker: { _eq: $acct } }] },
          order_by: { timestamp: desc }, limit: 50) { id timestamp }
   }
   ```
3. Run it again with `timestamp: { _gte: <now − 7 days> }` added, and compare response times.

Or run `dart run feedback/repro/repro.dart`, which times both (3 runs each) and writes `feedback/evidence/03-fill-query-latency.json`.

## Expected
Reading a wallet's perp fills is fast regardless of how far back the history goes, so clients can show full trade history.

## Actual
The unbounded query is far slower than the bounded one. The SDK records the same measurement and works around it by silently windowing every portfolio read to the last 7 days (`@somnia-chain/markets-sdk@0.32.1`, `src/portfolioScope.ts` lines 13–21):

> a spot market-maker asking for its BINARY fills walks every fill it has, rejecting each, before it can return nothing. Measured on the development indexer: 24.8s unbounded, 208ms bounded to a week.

So `getPerpPortfolio().trades` shows only a week of history unless the caller knows to pass `since`, and passing an older `since` brings the slow path back. This looks like a missing composite index on `Fill` covering `(maker|taker, pool, timestamp)`.

Suggested fix: add indexes on `Fill(maker, timestamp)` and `Fill(taker, timestamp)`, or a per-account fills table, so wallet history doesn't need a time window.

## Evidence
- `feedback/evidence/03-fill-query-latency.json`: account used, perp pool set, and timings for bounded and unbounded queries (from `feedback/repro/repro.dart`).
- SDK source: `node_modules/@somnia-chain/markets-sdk/src/portfolioScope.ts` lines 10–21 (`DEFAULT_TRADES_SINCE_SEC = 7 * 86_400` and the measurement above) and line 60 (the `fillWhere` shape).

## Environment
SDK `@somnia-chain/markets-sdk@0.32.1`; network Somnia Tokyo testnet (Hideki, chain 50383); indexer `https://hideki-dev.smk.somnia.host/v1/graphql`. Read-only: no wallet needed. The public account used is recorded in the evidence file.
