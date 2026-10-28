# Indexer column `PerpPosition.entryPriceX18` is not 1e18-scaled
Severity: normal
Area: API

## Steps to reproduce
1. Query the indexer for any open perp position and its market:
   ```graphql
   query {
     PerpPosition(where: { size: { _neq: "0" } }, order_by: { updatedAt: desc }, limit: 1) {
       pool account size isLong entryPriceX18
     }
   }
   ```
   then `Market(where: { poolAddress: { _eq: "<pool>" } }) { baseSymbol quoteDecimals markPrice }`.
2. Divide `entryPriceX18` by 1e18, as the `X18` suffix says.
3. Divide it by `10^quoteDecimals` instead.

Or run `dart run feedback/repro/repro.dart`, which does all three and writes `feedback/evidence/01-entry-price-scale.json`.

## Expected
A column named `...X18` holds a 1e18 fixed-point value, so `entryPriceX18 / 1e18` is the entry price, close to the market's mark price.

## Actual
`entryPriceX18 / 1e18` is a tiny number many orders of magnitude off. The value is raw quote units per whole base, the same scale as `Market.markPrice`, so `entryPriceX18 / 10^quoteDecimals` is the real entry price.

The SDK knows this and silently renames the field (`@somnia-chain/markets-sdk@0.32.1`, `src/perp/state.ts` lines 542–543):

> The underlying entity column is named `entryPriceX18`, which is a misnomer — the value is NOT 1e18-scaled. Renamed at this boundary so the name cannot imply a rescale that never happened.

That fix only helps TypeScript users. Anyone reading the indexer directly (mobile apps, Python bots, Dart/Kotlin/Swift clients with no SDK) gets the misleading name with no warning anywhere in the docs. We hit this building a Flutter client: following the column name puts every entry price, and so every unrealized P&L, off by 10^12 for a 6-decimal quote.

Suggested fix: add a correctly named alias column (e.g. `avgEntryPrice`) and deprecate `entryPriceX18`, or document the scale in the indexer/API docs.

## Evidence
- `feedback/evidence/01-entry-price-scale.json`: request, response, and both conversions next to the mark price (from `feedback/repro/repro.dart`).
- SDK source: `node_modules/@somnia-chain/markets-sdk/src/perp/state.ts` lines 538–546 (comment above), 577 (selects `entryPriceX18`), 633 (`avgEntryPrice: p.entryPriceX18`).

## Environment
SDK `@somnia-chain/markets-sdk@0.32.1`; network Somnia Tokyo testnet (Hideki, chain 50383); indexer `https://hideki-dev.smk.somnia.host/v1/graphql`. Read-only: no wallet needed. The public account used is recorded in the evidence file.
