# NovaWallet Mobile — Send & Save

A Flutter wallet app with offline-first Send Money and NovaSave (savings
goals) flows.

Targeted versions: **Flutter 3.24.x / Dart 3.5.x minimum** (see `pubspec.yaml`
for the exact constraint — anything satisfying `sdk: '>=3.5.0 <4.0.0'` and
`flutter: '>=3.24.0'` will build). Developed and tested against **Flutter
3.47.4**.

---

## How to run (single command)

This repo ships only Dart source (no `android/`/`ios/` platform folders,
to keep the diff reviewable). **First time only:**

```bash
flutter create .          # generates android/ ios/ etc. without touching lib/ or pubspec.yaml
```

Then, every time:

```bash
make run
```

which runs `flutter pub get`, generates the Drift database code
(`build_runner`), generates localizations (`flutter gen-l10n`), and launches
the app. Equivalent manual sequence:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter run
```

Run the tests with `make test` or `flutter test`.

---

## Architecture

Three-layer separation, though lighter-weight than a full Clean
Architecture split given the time box — see "Trade-offs" below for why.

```
lib/
  core/            infrastructure: database, networking, money, DI, queue
  features/
    wallet/        balance + transaction history
    send_money/    recipient -> amount -> confirm -> result
    nova_save/     goals list -> create -> contribute
    queue/         the Pending screen (the offline-sync centrepiece)
```

**State management: Provider (`ChangeNotifier`).** The complexity in this
brief lives in the offline queue and the money/balance model, not in
branching UI state. Provider keeps the state layer thin and readable so
that complexity stays visible where it actually is. For a flow with many
more branching states — full loan origination, say — I'd reach for BLoC
specifically for its sealed-state exhaustiveness at compile time.

**Dependency injection: GetIt + Provider, split by lifetime.**
`GetIt` (`core/di/service_locator.dart`) owns infrastructure singletons
that must exist *before* the widget tree — the database, the Dio client,
connectivity, notifications, biometrics, secure storage, and the
`QueueSyncService` that composes them. `Provider`/`MultiProvider` owns
screen-facing `ChangeNotifier`s that widgets subscribe to and rebuild
from, each constructed in `main.dart` with its GetIt-resolved
dependencies injected in. This split is also what makes the services
independently mockable in tests without touching widget code.

**Persistence: Drift (SQLite).** The offline queue needs atomic status
transitions — marking an action `processing` and reading it back must be
a real transaction, not a best-effort key-value write. Drift gives real
SQL transactions, typed schema, and indexed queries. The cost is
`build_runner` codegen; I accepted that because the atomicity guarantee
is load-bearing for correctness here, not a nice-to-have.

**Networking: Dio + a `MockInterceptor`.** No backend was provided, so
the fake lives at the interceptor layer, not inside repositories/
providers. That means the actual request/response shapes, headers,
timeouts, and error handling are the same code paths a real API would
exercise — going live is deleting one line (`dio.interceptors.add(...)`)
and pointing `baseUrl` at the real host.

**Errors:** providers distinguish *expected* business outcomes (insufficient
funds, a 402 from the mock API) from *unexpected* failures (a parse error, a
bug) via `try`/`catch` on `DioException`, setting a status enum and a
user-facing message rather than throwing past the provider boundary. The
queue has a stricter version of the same idea — `FailurePolicy` in
`core/queue/failure_policy.dart` classifies every error into `retryable`,
`insufficientFunds`, or `permanent`, because each demands a different sync
response (see below). No `Either`/functional-error abstraction: with no
repository layer and only a handful of call sites, it would add ceremony
without adding safety here.

---

## Money handling

Every amount in this app is an **integer number of kobo**, end to end —
entities, Drift columns, provider state, queue payloads, API request/
response bodies. The only place a `double` appears is a display-only
progress ratio (`MoneyFormatter.progressRatio`), which is never stored or
summed — only fed to a `LinearProgressIndicator`. Naira strings only
exist at the two boundaries: `MoneyFormatter.formatKobo` (kobo → display)
and `MoneyFormatter.parseToKobo` (user input → kobo). See
`test/core/money_formatter_test.dart` for a test that demonstrates the
exact floating-point drift this design avoids.

---

## Offline & sync design

This is the part of the brief the assessment is really about, so this
section is intentionally detailed.

### The problem, concretely

> Wallet balance ₦400. User goes offline. Sends ₦200, then ₦300.
> Connectivity returns. What happens?

If the queue naively replayed both actions against the ledger balance,
the second (₦300) would fail with insufficient funds *after* the first
had already succeeded — a guaranteed, entirely avoidable failure, plus a
wasted request on expensive mobile data, plus a confusing user
experience (why did my second transfer fail when I definitely had ₦400?).

### The design: three layers

**1. Available balance, not ledger balance, gates every action.**

```
availableBalanceKobo = ledgerBalanceKobo − SUM(debitAmountKobo
                          for every queued action not yet in a
                          terminal-success state)
```

(`AppDatabase.getAvailableBalanceKobo`). Every send and every
contribution — online or offline — is validated against this number, not
the raw ledger balance. In the scenario above: after the ₦200 send is
queued, available balance becomes ₦200. The ₦300 send is rejected
**at the moment the user tries to confirm it**, before it is ever
enqueued (`SendMoneyProvider.confirmSend`, `NovaSaveProvider.contribute`).
The problem never reaches the sync engine.

**2. The reconnect sequence refreshes the ledger *before* dispatching.**

`QueueSyncService.sync()` runs, strictly in this order: refresh the
authoritative ledger balance → pre-flight validate the whole queue
against that fresh balance in FIFO order (blocking, without a network
call, anything that would now overdraw — e.g. a standing debit landed
while the user was offline) → dispatch → refresh the balance again. This
ordering matters: dispatching against a stale client-side balance is how
you get avoidable failures that layer 1 alone can't catch, because the
server-side balance can move for reasons the client never sees.

**3. Halt-on-insufficient-funds, not skip-and-continue.**

If a dispatch still fails with a 402 (a race between pre-flight and
actual dispatch), the sync loop **halts** — it does not attempt anything
queued behind that action. Every queued action here debits the same
single wallet balance pool, so if action *N* can't afford it, actions
*N+1..M* behind it in FIFO order almost certainly can't either;
attempting them anyway would just generate guaranteed secondary
failures and burn more mobile data. The user sees one notification and a
"blocked" state on the Pending screen with **Retry** / **Cancel**
actions, rather than a cascade of failure toasts.

*(If NovaPay later supported multiple independent wallets, halt-all
would be too aggressive — the correct generalisation is to halt per
balance-pool, grouping queued actions by which account they debit. Noted
here rather than implemented, since this task has exactly one wallet.)*

### Exactly-once, across a restart

Three mechanisms together:

- **The idempotency key is the queue action's `id`.** Generated once, at
  the moment the user enters an amount — *before* confirmation, before
  any network call — and reused unchanged on every dispatch attempt
  including retries. The mock API's `/transfers` and `/contribute`
  endpoints accept it as `idempotencyKey` in the body and as an
  `Idempotency-Key` header.
- **The `processing` status closes the crash window.** An action is
  marked `processing` immediately before the network call. If the app
  dies between that write and the call completing, the action is *not*
  silently re-dispatched under a new attempt — `AppDatabase.
  recoverOrphanedProcessing()` runs on every app start, before anything
  else touches the queue, and resets any orphaned `processing` row back
  to `pending`. The retry carries the *same* idempotency key, so even if
  the server had actually received and processed the original request,
  it returns the original result rather than double-processing.
- **Local state application is itself idempotency-guarded.**
  `AppDatabase.applySendOnce` / `applyContributionOnce` check whether a
  `settled` transaction row already exists under that idempotency key
  before touching the ledger balance. Calling either twice for the same
  key is a safe no-op — this is the last line of defence even if the
  sync loop were somehow re-entered for an already-completed action.

### The queue state machine

```
PENDING → (dispatch) → PROCESSING → (2xx) → COMPLETED
   ▲                        │
   │ backoff elapses        ├─ retryable error → FAILED_RETRYABLE
   │ (jittered exponential) │      │ attempts >= 5 → FAILED_FINAL
   └────────────────────────┤
                             ├─ 402 → BLOCKED_INSUFFICIENT_FUNDS  ⚠ halts queue
                             │      (resumable: fund wallet, or tap Retry)
                             │
                             └─ 400/403/422 → REJECTED (never retried)

  app restart while PROCESSING → back to PENDING (same idempotency key)
```

See `core/queue/queue_status.dart` and `core/queue/failure_policy.dart`.

### Retry backoff and Nigerian networks specifically

Retryable failures back off exponentially **with jitter**
(`FailurePolicy.backoffFor`). Jitter matters specifically on Nigerian
mobile networks: when a cell tower recovers after an outage, a large
number of devices reconnect at effectively the same instant. Without
jitter, every client retries in lockstep and creates a thundering herd
against the API gateway right when it's already under load from the
same recovery event.

---

## Accessibility

- Every interactive control (send button, quick actions, transaction
  rows, goal cards, retry/cancel on the Pending screen) has an explicit
  `Semantics` label describing its full state — e.g. a pending
  transaction announces "…debit ₦200.00, pending, will send when back
  online" as one utterance, not three separate fragments a screen-reader
  user has to piece together.
- The balance headline is wrapped in `FittedBox` so a large system
  font-scale setting shrinks the text to fit rather than overflowing the
  header — the one place in the UI where a big number and a large scale
  factor could otherwise collide.
- No text is clamped to a fixed scale; the app respects
  `MediaQuery.textScaler` throughout (see the `builder:` in `main.dart`).

---

## Performance & Nigerian device constraints

- **`ListView.builder`** (and its sliver equivalent,
  `SliverChildBuilderDelegate`) for every list — transaction history, the
  goals list, the pending queue — so only visible rows are ever built.
  `itemExtent` is set wherever row height is fixed, giving O(1) scroll-
  offset calculation instead of per-item measurement.
- **Bounded local storage**: transaction history is capped at 200 rows
  (`AppDatabase.capTransactionHistory`); completed queue rows are pruned
  after 7 days (`pruneCompletedOlderThan`). Unbounded local tables are
  how apps get killed for storage pressure on constrained devices.
- **No polling.** Connectivity is event-driven
  (`Connectivity.onConnectivityChanged`), not a `Timer.periodic` — a
  periodic timer is a needless CPU wake-up for the app's entire
  lifetime on a battery-constrained device.
- **No background service / WorkManager job.** Deliberately scoped out —
  see Trade-offs below.
- **Timeouts sized for 3G, not Wi-Fi**: 15s connect / 30s receive in
  `DioClient`. NIBSS NIP settlement SLA is roughly 20s; a shorter timeout
  would fail transfers that would actually have succeeded.

---

## Security

- Auth token (mocked) is written to `flutter_secure_storage`
  (`core/storage/secure_storage_service.dart`) — Android Keystore /
  iOS Keychain, never `SharedPreferences`.
- Sends at or above ₦50,000 require a biometric (or device credential)
  check before proceeding, both for an online send and before it's
  queued offline (`core/biometrics/biometric_service.dart`,
  `kBiometricThresholdKobo`).

---

## Stretch goals implemented

All four:

1. **Local notification on sync** — a queued send/contribution shows a
   device notification once it settles after reconnect
   (`core/notifications/notification_service.dart`).
2. **Yoruba localization** — an in-app EN/YO toggle (not device-locale
   detection, which is unreliable to demo live) drives arb-based
   `AppLocalizations` across recipient/amount/confirm/result screens.
   Flutter's own `flutter_localizations` package ships no Yoruba data for
   its Material/Widgets/Cupertino delegates, so
   `core/locale/fallback_framework_delegates.dart` wraps them to report
   `yo` as supported and fall back to English framework chrome (OK/Cancel,
   date pickers) rather than crash — only our own screens' text actually
   switches language.
3. **Golden tests** — `test/golden/wallet_home_golden_test.dart` pins the
   Wallet home screen's rendered output.
4. **Biometric confirmation above ₦50,000** — `core/biometrics/
   biometric_service.dart`, gated by `kBiometricThresholdKobo`, for both
   an online send and before queueing offline.

---

## Trade-offs and known limitations

Given the 48–72 hour window, these were deliberately left out or
simplified, in priority order of what I'd add next:

1. **Background sync.** The queue currently syncs when the app is in the
   foreground and connectivity is restored. A production version would
   add a `WorkManager` (Android) / `BGTaskScheduler` (iOS) job to flush
   the queue while backgrounded. Left out because an always-on
   background worker is a real battery/OOM cost on a 2GB device, and the
   brief's stated requirement — "replayed when connectivity returns" —
   is satisfied on next foreground open.
2. **Certificate pinning** on the Dio client — not meaningful against a
   mock API, but would be table stakes before this touched a real
   backend.
3. **Encrypting the Drift database at rest** (e.g. via SQLCipher) —
   transaction history is sensitive; this repo stores it in a plain
   (if sandboxed) SQLite file for the sake of time.
4. **Real name-enquiry integration** — `RecipientPage` fakes account
   resolution rather than calling a real NIBSS name-enquiry endpoint.
5. **Halt-per-balance-pool** rather than halt-all in the sync engine —
   only matters once there's more than one wallet; noted above.

## AI usage

See `AI_USAGE.md` for tools used, example prompts, and — per the brief's
explicit ask — a specific case where AI output was wrong for this app
and how it was caught and corrected.
