# NovaWallet — Design Notes

Source comments were stripped for a clean review. This captures the
non-obvious "why" behind the key decisions, for future reference.

## Idempotency key lifecycle
- Send Money: the key is generated ONCE, at amount-entry (`SendMoneyProvider.enterAmount`),
  not per submit. Every retry of the same attempt reuses it, so the backend
  and the local queue treat a retry as the same transfer, not a new one.
- NovaSave `contribute()` mints a fresh key per call (by design, since each
  contribution is a distinct action) — this is why it needed its own
  `_isSubmitting` guard even more urgently than Send Money did.

## Offline queue correctness (`core/queue/queue_sync_service.dart`)
- `sync()` order: refresh ledger balance → pre-flight validate the whole
  queue against that fresh balance (marks anything that would overdraw as
  `blockedInsufficientFunds` without wasting an API call) → dispatch FIFO →
  refresh balance again → prune old rows.
- On an insufficient-funds response mid-dispatch, it HALTS instead of
  skipping — every queued action draws from the same single wallet balance,
  so anything behind it would also fail.
- Exactly-once is guaranteed by three things together: the idempotency key,
  `processing` status being reset to `pending` on app restart
  (`AppDatabase.recoverOrphanedProcessing`), and `applySendOnce` /
  `applyContributionOnce` being idempotency-guarded at the DB layer.

## Startup sync bug (fixed this session)
- The reconnect-sync trigger only fired on a LIVE offline→online transition.
  A cold start where the device is already online never counted as a
  transition, so a queued offline transaction from a previous session never
  synced until the user manually tapped "Sync now". Fixed by adding a
  one-shot startup sync check in `main.dart`'s `_ConnectivitySyncBridgeState.initState()`.

## Double-tap / re-entrancy guards (fixed this session)
- Root cause: async `onPressed` handlers with no "already in flight" guard —
  N rapid taps fired N concurrent calls, each independently completing and
  navigating/mutating state.
- Fixed with the same pattern everywhere it occurred: a `_isSubmitting` flag
  checked-and-set before any `await`, reset in a `finally` block, and the
  triggering button disabled/spinner-ized while true.
  - `SendMoneyProvider.confirmSend()`
  - `NovaSaveProvider.createGoal()` and `.contribute()`
  - Plus a lighter page-local `_navigated` guard on the synchronous
    "Continue" buttons in `amount_page.dart` / `recipient_page.dart`, which
    were double-`Navigator.push`-able (not a data bug, just a stacked-route
    annoyance).
- `QueueSyncService.sync()` already had its own internal `_isSyncing` guard,
  so the two async buttons in `pending_queue_page.dart` didn't need one.

## Status bar fix (fixed this session)
- The app only ships a light theme, but the OS's default status-bar-icon
  brightness is inconsistent across devices — some rendered light icons on
  the light background, making the status bar unreadable. Fixed by forcing
  dark icons everywhere: `AppBarTheme.systemOverlayStyle` in `app_theme.dart`
  (covers all `AppBar` screens) plus one `SystemChrome.setSystemUIOverlayStyle`
  call in `main()` (covers the one `AppBar`-less screen, `result_page.dart`).
