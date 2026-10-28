# `PerpPosition.size` is unsigned but `PerpPositionChange.sizeAfter` is signed
Severity: normal
Area: API

## Steps to reproduce
1. Find an open short:
   ```graphql
   query {
     PerpPosition(where: { size: { _neq: "0" }, isLong: { _eq: false } }, order_by: { updatedAt: desc }, limit: 1) {
       pool account size isLong updatedAt
     }
   }
   ```
2. Read the latest change for the same account and pool:
   ```graphql
   query {
     PerpPositionChange(where: { account: { _eq: "<account>" }, pool: { _eq: "<pool>" } },
                        order_by: [{ blockNumber: desc }, { logIndex: desc }], limit: 1) {
       kind sizeBefore sizeAfter
     }
   }
   ```
3. Compare `PerpPosition.size` with `PerpPositionChange.sizeAfter`.

Or run `dart run feedback/repro/repro.dart`, which writes `feedback/evidence/02-size-sign.json`.

## Expected
Two indexer entities describing the same position use the same sign convention for size.

## Actual
For the same short position:
- `PerpPosition.size` is a positive number, with the direction in a separate `isLong: false` flag.
- `PerpPositionChange.sizeAfter` is negative (signed: positive long, negative short).

A client that treats `PerpPosition.size` as signed, which the sibling entity and the on-chain `MarginBank.getPosition` both teach, reads every short as a long. That inverts unrealized P&L and liquidation direction for shorts while looking correct for longs, so it's easy to miss in testing.

The SDK hides this by re-signing the value (`@somnia-chain/markets-sdk@0.32.1`, `src/perp/state.ts` lines 530–536 and 631–632):

> The entity itself stores an absolute `size` plus a separate `isLong` flag; carrying that second field here would mean two exported position types whose `size` means different things, which reads correctly for longs and silently inverts every short.

As with the entry-price column, only TypeScript SDK users get the fix; direct indexer consumers don't.

Suggested fix: expose a signed size column on `PerpPosition` (e.g. `signedSize`), or document the convention on both entities.

## Evidence
- `feedback/evidence/02-size-sign.json`: both requests and responses for the same account and pool (from `feedback/repro/repro.dart`).
- SDK source: `node_modules/@somnia-chain/markets-sdk/src/perp/state.ts` lines 528–537 (comment above), 631–632 (`size: p.isLong ? p.size : (-BigInt(p.size)).toString()`); `src/perp/history.ts` line 1306 (`sizeBefore` documented as signed).

## Environment
SDK `@somnia-chain/markets-sdk@0.32.1`; network Somnia Tokyo testnet (Hideki, chain 50383); indexer `https://hideki-dev.smk.somnia.host/v1/graphql`. Read-only: no wallet needed. The public account used is recorded in the evidence file.
