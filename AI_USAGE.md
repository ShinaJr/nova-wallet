# AI Usage

## Tools used

- **Claude (Anthropic)** — architecture discussion, the offline-queue and
  insufficient-funds design specifically, and the initial project scaffold
  (directory structure, core service classes, providers, screens).
- **Claude Code** — implementation inside the scaffold: wiring screens
  together, fixing build errors, writing/refining tests, generating the
  Drift codegen output, iterating on the UI.

---

## How I used AI

### 1. Architecture and the offline-queue design

This was my actual opening prompt to Claude, laying out the full brief
before any code existed:

**Prompt (verbatim):**
> "I want to build the architecture of a financial app that involves
> payment like sending money and saving money... It requires an
> offline-first architecture for financial transactions — mock APIs for
> transfers and savings, functional error handling with dartz's Either
> (Left/Right), Dio for networking, secure storage, localization, local
> notifications, biometrics for payments.
>
> I'm considering Dart 3 with null safety and using the latest version
> 3.47, a strict Clean Architecture split (Presentation / Domain / Data),
> Provider or BLoC/Cubit for state management, intl for localization, and
> Drift, Hive, or SQLite for the offline-first local database. Since this
> is financial, I want to properly handle idempotency keys to prevent
> duplicate transactions, and Semantics for accessibility.
>
> I want to use a connectivity package to detect network changes and
> handle latency well, given how unstable Nigerian mobile networks can
> be. The main area I want to get right is offline transaction queuing —
> if a user initiates a transfer while offline, it should queue locally
> and retry on reconnect — but I need to think through stale local
> state, synchronization conflicts, and transaction validity carefully,
> since this is a financial system.
>
> Other things I want to properly consider: secure storage, biometrics
> for savings/payment authorization, transaction states and
> reconciliation, retry mechanisms, idempotency, offline/online sync,
> local data consistency, network failures and timeouts, error handling,
> security, accessibility, localization, and memory/CPU usage — I don't
> want the app consuming unnecessary memory or doing heavy background
> processing, given the RAM constraints on devices common in the
> Nigerian market.
>
> I want to approach this methodically, build something
> production-realistic rather than assessment-shaped, and draw on my
> years working with Flutter on financial transactions, API
> integrations, security, and production issues."

**What came back, and why the actual design diverges from the initial
ask:** I walked in assuming strict Clean Architecture (Presentation /
Domain / Data) with `dartz`'s `Either<Left, Right>` for error handling,
since that's the pattern most associated with "serious" banking
software. Talking it through, the case against it for *this specific
brief* was: a single mock data source per feature, a solo build under a
tight deadline, and no team boundary that needs the domain layer
insulated from Dio/Drift — repository interfaces with one implementation
each, plus `Either`-wrapped use cases that just forward to a provider,
would cost real time without buying safety here. What survived from the
original ask: idempotency keys, offline queuing with reconnect dispatch,
biometrics on payments, secure storage, accessibility, and RAM-conscious
behavior for the Nigerian device market — all implemented, none of it
diluted by simplifying the architecture. The `dartz`/`Either` scaffolding
was actually built at one point, then found to be completely unused once
the try/catch pattern was implemented everywhere in practice, and
removed for exactly the reason discussed here — see the package rundown
in the interview-prep notes for that as a worked example of catching
scope creep.

In a follow-up in the same session, I settled the state-management/
persistence stack and handed over a specific scenario to stress-test the
offline design against, rather than accepting "a queue that retries" as
good enough:

**Prompt (reconstructed from the session):**
> "I'll be using Provider for state management and Drift/SQLite for
> local persistence. There's no real API here; I'll be building mock
> APIs for transfers and savings — make sure Dio, notifications, and
> everything else the brief requires are properly covered.
>
> One scenario I want to stress-test the design against: if a user has a
> balance of ₦400 and sends ₦200 then ₦300 while offline, then
> reconnects — how should the queue handle it if the first transfer
> succeeds on retry but there isn't enough balance left for the second? I
> want a properly reasoned, defensible answer to that.
>
> Also factor in Nigerian network conditions — patchy connectivity — and
> low-RAM, low-storage devices into the design. Give the architecture a
> full, thorough review before I start building; I'll use Claude Code
> afterward to implement and test on a real device."

**What came back:** the three-layer guard design that's actually in this
repo, not a single "check the balance" step —
1. **At entry** (`SendMoneyProvider.confirmSend`): validate against
   *available* balance (ledger minus every queued debit not yet
   terminal-success), not the last-known ledger balance. This is what
   rejects the ₦300 send immediately, offline, before it's ever queued —
   because ₦400 − ₦200 pending = ₦200 available, which can't cover ₦300.
2. **Pre-flight, on reconnect, before any network call**
   (`QueueSyncService._preflightValidateQueue`): re-fetch the
   authoritative ledger balance first (it may have moved while offline),
   then simulate it running through the FIFO queue and block anything
   that would overdraw — a backstop for the case where Layer 1 was
   somehow bypassed.
3. **At dispatch** (`FailurePolicy` + `QueueSyncService._dispatchLoop`):
   if the server itself returns insufficient-funds (a genuine race), halt
   the queue entirely rather than skipping past it and trying the next
   action — because every action behind it in FIFO order shares the same
   balance pool, so if this one can't be afforded, the ones behind it
   almost certainly can't either.

This also produced the reconnect *ordering* requirement (refresh the
ledger balance before dispatching, not after), the jittered exponential
backoff (to avoid a thundering-herd retry storm when a Nigerian cell
tower recovers and many devices reconnect at once), and the Drift schema
this repo actually runs on. The exactly-once guarantee came out of the
same exchange: a `processing` status written *before* the network call
(not `pending` straight to done), with a recovery step on app start that
resets any row still stuck in `processing` back to `pending` — so a crash
mid-dispatch doesn't strand an action in limbo — plus idempotency-guarded
local state application (`applySendOnce` / `applyContributionOnce`), so
even if the same action is dispatched twice, applying its result a second
time is a safe no-op rather than a double credit/debit. See
`getAvailableBalanceKobo()`, `getDispatchableActions()`, and
`recoverOrphanedProcessing()` in `AppDatabase`.

### 2. Claude Code session — wiring localization into Send Money

I pointed Claude Code at item 3 of my own kickoff notes
(`CLAUDE_CODE_PROMPT.md`) to close out the stretch-goal localization work
that was scaffolded (arb files, generated `AppLocalizations` classes) but
never actually consumed by any screen:

**Prompt (verbatim, from `CLAUDE_CODE_PROMPT.md`):**
> "Wire `AppLocalizations` into the Send Money screens properly — the
> `.arb` files exist (`lib/l10n/app_en.arb`, `app_yo.arb`) but the
> screens currently use hardcoded English strings. Replace the literal
> strings in `recipient_page.dart`, `amount_page.dart`, and
> `confirm_page.dart` with `AppLocalizations.of(context)!.xyz` calls
> matching the keys already defined in the arb files. Add any missing
> keys to both arb files as you find hardcoded strings that should be
> localized."

**What came back:** 7 new keys added to both `app_en.arb` and
`app_yo.arb` (with real Yoruba translations, not machine-placeholder
text) for strings that had no existing key — the recipient hint,
"recipient found" message, amount label, available-balance line, and
the over-balance warning — followed by `flutter gen-l10n` and the
literal-string replacements across all three screens. Running the
screens afterward surfaced a real bug this refactor would otherwise have
shipped silently: see the second "where AI got it wrong" case below.

### 3. Claude Code session — proposing a debug demo toggle, then dropping it

My own kickoff notes (`CLAUDE_CODE_PROMPT.md`) listed a nice-to-have:
a debug toggle for `MockInterceptor.forceInsufficientFunds` /
`injectedFailureRate`, so the insufficient-funds-halt path could be
demoed live in the interview without manually draining the mock
balance first.

**Prompt (paraphrased):**
> "Add a kDebugMode-gated UI toggle for the MockInterceptor flags."

**What came back, and why I stopped it:** Claude Code drafted a bug-report
icon in the Pending Queue app bar opening a dialog with a switch and a
slider. Before it was written, I pushed back: the assessment brief asks
for a real-feeling payment flow using mock APIs underneath, not a
debug-tooling surface bolted onto the UI — and the offline/insufficient-
funds paths this toggle exists to shortcut are already fully
demonstrable the honest way (airplane mode for offline/reconnect, and
sending a transfer larger than the remaining mock balance for the
insufficient-funds halt). The feature was dropped entirely rather than
built and hidden — see "My role vs AI's role" below for why that
judgment call mattered more here than adding another interviewer-facing
affordance would have.

---

## Where AI got it wrong — and how I caught it

### Case: the naive "dispatch then remove" queue pattern

An early version of the sync loop (suggested before I pushed back with
the ₦400/₦200/₦300 scenario) looked like this:

```dart
// WRONG — an early AI suggestion
final pending = await queue.getPending();
for (final action in pending) {
  await dispatch(action);
  await queue.remove(action.id);
}
```

**Why this is wrong for a banking app:** if the app process dies between
`dispatch()` succeeding and `queue.remove()` running, the action is still
sitting in the queue as "pending" on the next launch. The naive loop
above would dispatch it *again* — a duplicate transfer, with real money
moved twice for a single user action.

**The fix**, drawing on production experience debugging offline sync in
a real banking codebase: introduce a `processing` status written *before*
the network call, and a recovery step on app start that resets any
orphaned `processing` row back to `pending` — rather than assuming a
`processing` row means "already handled." The idempotency key (not a new attempt ID)
is what makes the retry safe: if the server actually did process the
first attempt, the retry with the same key returns the original result
instead of creating a second transaction. See `AppDatabase.
recoverOrphanedProcessing()` and `QueueSyncService._dispatchLoop` in this
repo.

### Case: `main.dart` never registered its own `AppLocalizations` delegate

Before this session, `MaterialApp` in `lib/main.dart` set up
`localizationsDelegates` with `GlobalMaterialLocalizations`,
`GlobalWidgetsLocalizations`, and `GlobalCupertinoLocalizations` — the
three Flutter framework delegates most localization tutorials show —
but not `AppLocalizations.delegate` itself. `flutter analyze` passed
cleanly, because nothing in the app actually called
`AppLocalizations.of(context)` yet; the arb files and generated classes
existed but were unused.

**Why it was wrong:** the moment any screen was wired to call
`AppLocalizations.of(context)!`, it threw `Null check operator used on a
null value` and crashed, because `AppLocalizations.of()` returns `null`
when its own delegate isn't registered, no matter how correct the arb
files are. This is a class of bug that's invisible until the exact code
path that depends on it runs, which is exactly what happened here: it
only surfaced once I wired the Send Money screens to consume localized
strings and ran the app to check the result — something `flutter
analyze` never had a chance to catch.

**The fix:** add `AppLocalizations.delegate` to the `localizationsDelegates`
list in `lib/main.dart`. See `lib/main.dart`.

### Case: unstable mock ids defeated the local dedup on every launch

`MockInterceptor._mockTxns()` generated a fresh `_uuid.v4()` for each of
the five seed transactions on *every* call to `/wallet/transactions`.
`WalletProvider._refreshFromNetwork()` writes each one with
`insertOnConflictUpdate(TransactionsTableCompanion.insert(id: map['id']
as String, ...))` — which only dedups correctly if the same backend
record reuses the same `id` across calls. With a fresh UUID every time,
every refresh looked like five brand-new transactions to Drift, and they
piled up in the transaction history.

**Why AI produced it:** the mock interceptor was written to *feel* like a
real backend response shape, and real backends assign a UUID once,
server-side, at creation time — never regenerating it. But this mock
regenerates its response body from scratch on every call rather than
persisting state, so re-using `_uuid.v4()` per-call silently violated the
one invariant `insertOnConflictUpdate` actually depends on.

**How I caught it:** live-device testing surfaced duplicate transactions
in the Recent Transactions list after a couple of app relaunches — not
something a widget test or `flutter analyze` would catch, since nothing
about the code is statically wrong.

**The fix:** replaced all five ids with stable hardcoded strings
(`mock-txn-adaobi-transfer`, etc.), matching how a real backend would
behave. See `MockInterceptor._mockTxns()`.

### Case: the manual "Sync now" button skipped the connectivity check

The Pending Queue screen's "Sync now" icon button called
`QueueSyncService.sync()` unconditionally. Because `MockInterceptor` is a
local Dio interceptor rather than a real socket, it "succeeds" even in
airplane mode — so tapping this button while genuinely offline silently
completed queued sends instead of leaving them queued, which is the
opposite of the offline-first guarantee this app exists to demonstrate.

**Why AI produced it:** the auto-sync path
(`ConnectivitySyncBridge` in `main.dart`) is only ever invoked *after* a
reconnect event fires, so it never needed its own guard — that context
didn't transfer to the manually-triggered button, which has no such
precondition built in by construction.

**How I caught it:** toggling airplane mode and tapping "Sync now" during
a live dry run — a manual action a script wouldn't think to take, since
it looks like a convenience feature rather than a path that needs its
own correctness guard.

**The fix:** added an explicit `ConnectivityService.checkOnline()` check
before dispatching, with a SnackBar explaining the queued action will
sync automatically once back online instead of silently completing it.
See `PendingQueuePage`'s "Sync now" `IconButton`.

### Case: `context.read()` after an `await` that could unmount its own widget

Both the "Sync now" button and the "Retry now" button on a blocked queue
item called `context.read<WalletProvider>().refreshLocalOnly()` *after*
awaiting `QueueSyncService.sync()`, guarded by `if (context.mounted)`.
That guard looked like standard, correct Flutter practice — but
`sync()` can itself drive the very queue item this button lives on to
`'completed'`, which removes it from `watchVisibleQueue()`'s stream and
unmounts the tile's `BuildContext` *during* the await. The `mounted`
check then correctly evaluated `false`, so `refreshLocalOnly()` silently
never ran: the Pending Queue screen would correctly clear, but Wallet
Home kept showing the transaction as "Pending" with a stale pending
balance forever.

**Why AI produced it:** `if (context.mounted)` is the textbook fix for
"BuildContext used across an async gap," and satisfies the linter — but
it assumes the *reason* a context might unmount is the user navigating
away, not the very operation being awaited making the widget's own data
disappear from under it. That's a subtler failure mode than the lint
rule is designed to catch.

**How I caught it:** reproduced via the documented ₦400/₦200/₦300
insufficient-funds stress scenario on a physical device — queued a send
while offline, forced it to halt on reconnect with an insufficient-funds
response, then retried it once solvent again. The queue correctly
emptied; the wallet screen didn't update. Not reproducible without
actually watching both screens live through a full halt-then-retry
cycle.

**The fix:** capture `final walletProvider = context.read<WalletProvider>();`
*before* the first `await` in each handler — a `ChangeNotifier` reference
stays valid and callable even after the widget that fetched it unmounts,
so `refreshLocalOnly()` now always fires regardless of what the awaited
call does to this widget's place in the tree. See both handlers in
`PendingQueuePage`.

### Case: a wrong first diagnosis of the "Transfer Failed" flash on Done

Live-device testing turned up a real bug: tapping **Done** on the Send
Money result screen after a queued (airplane-mode) send briefly flashed
"Transfer Failed" with a red icon and ₦0.00 before landing back on wallet
history — even though the send itself had queued correctly.

**First diagnosis (wrong):** assumed `connectivity_plus`'s
`checkOnline()` had raced airplane mode actually taking effect, letting
`confirmSend()` attempt an online send that then failed with a real
`DioException`, mishandled as a hard failure instead of falling back to
queuing. Fixed `_sendOnline()` (and the equivalent path in
`NovaSaveProvider.contribute()`) to branch on `e.response != null` —
a real HTTP response is a genuine rejection, no response at all falls
back to the offline queue.

**Why this was wrong:** `MockInterceptor` fakes every response entirely
inside its `onRequest` callback via `handler.resolve(...)` — it never
lets Dio attempt a real socket call, so it is architecturally impossible
for it to throw a real connection-layer `DioException` in this build.
The fix was reasonable defensive code for a future real backend, but it
targeted a code path the bug couldn't have come from, and the flash kept
happening after it shipped.

**Second look, correct diagnosis:** the reported detail that mattered —
the flash showed ₦0.00, not the real transfer amount — pointed at a
reset-state rendering bug, not a networking one. `ResultPage`'s Done
button called `provider.reset()` (zeroing `amountKobo`, status back to
`initial`) while the page was still mounted. `ResultPage`'s status
`switch` had a wildcard `_ =>` case meant only for `failure`, which
silently also matched `initial` — so a late rebuild rendered "Transfer
Failed / ₦0.00" regardless of the real outcome.

**First fix attempt, also insufficient:** reordered the Done handler to
call `Navigator.popUntil(...)` before `provider.reset()`, assuming call
order was the race. It wasn't: `popUntil()` only animates the outgoing
route's exit transition, it doesn't synchronously unmount it, so a
`context.watch`-subscribed `ResultPage` could still rebuild mid-transition
no matter which call came first.

**The durable fix:** converted `ResultPage` from a `StatelessWidget` to a
`StatefulWidget` that captures `status`/`amountKobo`/`transactionRef`/
`errorMessage` once in `initState()` via `context.read`, and renders from
that local snapshot instead of watching the provider live — a result
screen should show what already happened, not keep reacting to provider
mutations that occur after the fact. See `ResultPage` in
`lib/features/send_money/presentation/result_page.dart`.

**How I caught both wrong turns:** the user's own repro details, taken
seriously instead of pattern-matched against the first plausible-sounding
cause — specifically insisting the flash persisted after fix one, then
volunteering the ₦0.00 detail that pointed at the real mechanism, then
reporting the reorder fix still didn't hold on a second live retest.

### Case: a mutable mock balance that didn't survive an app restart

`MockInterceptor`'s `/wallet/balance` GET started as a hardcoded
constant. `QueueSyncService.sync()` refreshes the ledger from that
endpoint both before *and* after dispatching queued actions, by design —
"the server is authoritative." Because the mock never remembered prior
debits, that post-dispatch refresh silently reverted any successful
send/contribution's local debit back to the fixed starting balance. The
first fix gave `MockInterceptor` a mutable running balance that
decrements on successful `/transfers` and `/savings/goals/*/contribute`
calls, so it would stay consistent across a single app session.

**Why AI produced it:** a static in-memory field is the obvious way to
make a mock endpoint "stateful" without standing up real persistence, and
it works for exactly as long as the process stays alive — which is all
that normal same-session testing exercises.

**How I caught it:** a deliberate "kill the app while offline, relaunch,
reconnect" durability test, one step past ordinary testing. The local
Drift/SQLite ledger correctly remembered the reduced balance across the
restart, but the mock "server" reset to its hardcoded ₦457,500.00
default on the new process, and `QueueSyncService`'s pre-dispatch
`_refreshLedgerBalance()` treated that stale reset value as
authoritative and overwrote the correct local balance with it — a bug
that only exists at the seam between a durable local store and a
non-durable mock standing in for a remote one.

**The fix:** added `MockInterceptor.seedBalance(int kobo)`, called from
`service_locator.dart` right after the local database opens, seeding the
mock's balance from `db.getWallet().ledgerBalanceKobo` at every app boot
— so the mock and the durable store agree on startup instead of the mock
silently winning with stale data. See `MockInterceptor.seedBalance()` and
its call site in `service_locator.dart`.

### Case: two providers reading the same sync event, one of them stale

`NovaSaveProvider.goals` is loaded once at app startup and was never
refreshed after a reconnect sync, so the NovaSave goal progress bar kept
showing pre-sync numbers even after `QueueSyncService` had correctly
updated the underlying Drift rows.

**Why AI produced it:** `WalletProvider.refreshLocalOnly()` was wired
into all three sync call sites (the reconnect bridge in `main.dart`, and
both buttons in `PendingQueuePage`) because the wallet balance is the
obviously-affected state after a sync. `NovaSaveProvider` depends on the
same underlying sync completing, but that dependency isn't visible from
any single call site — it only shows up if you check every provider that
reads data the queue can touch, not just the one the queue's own domain
suggests.

**How I caught it:** live-tested a NovaSave contribution queued offline,
then reconnected and watched the goal's own screen instead of only
checking Wallet Home — the balance updated correctly, the goal's
progress bar didn't move.

**The fix:** call `NovaSaveProvider.loadGoals()` alongside
`WalletProvider.refreshLocalOnly()` at all three sync call sites, not
just the wallet-focused ones.

### Case: one offline-queue path had a pending indicator, the other didn't

`SendMoneyProvider._queueOffline()` inserts an optimistic
`TransactionsTable` row with `settlementState: 'pending'` at queue time —
that's what drives the amber border and "Pending — will send when back
online" label on `TransactionTile`. `NovaSaveProvider.contribute()`'s
offline branch only enqueued the sync action itself and never wrote that
row, so a queued NovaSave contribution was invisible in Recent
Transactions until `applyContributionOnce()` inserted it as already-
settled on sync — silently different behavior from a queued send, for
what should be the same offline-first guarantee.

**Why AI produced it:** Send Money's offline queuing was built first and
established the pattern; NovaSave's `contribute()` was written against
the "queue an action for later dispatch" half of that pattern without
carrying over the "also show the user something happened right now" half
— the two concerns look like one feature but are actually two separate
writes that have to be kept in sync by hand.

**How I caught it:** queued a NovaSave contribution while offline and
checked Recent Transactions immediately, the same way a user testing
"did my save go through" would — Send Money showed a pending row, NovaSave
didn't, for what's supposed to be the identical guarantee.

**The fix:** mirrored Send Money's pattern in `NovaSaveProvider`'s
offline branch — insert a `pending`-state `TransactionsTable` row keyed
by the same idempotency key used for the queued action, which
`applyContributionOnce()`'s `insertOnConflictUpdate` already flips to
`settled` on sync instead of duplicating. See `NovaSaveProvider.
_queueOffline()`.

### Case: a shared status field that outlived the screen that set it

Tapping into a freshly-created NovaSave goal for the first time showed a
stale "Goal created!" snackbar and immediately bounced back to the goals
list instead of just displaying the goal.

**Why AI produced it:** `NovaSaveProvider` was written to track a single
`status`/`successMessage` pair shared across `createGoal()` and
`contribute()`, since both are "the same kind of operation" from the
provider's point of view. `create_goal_page.dart` set that status to
`success` on `createGoal()` completing, then popped — but never reset it
before doing so, because from that screen's own perspective its job was
finished. The field being shared with a *different* screen's read of it
was the part that didn't transfer.

**How I caught it:** created a goal live and tapped straight into it —
the ordinary next action a real user takes — instead of only exercising
goal creation in isolation. The goal detail screen read the still-`success`
status left over from creation, treated it as its own operation having
just succeeded, and bounced.

**The fix:** reset `NovaSaveProvider`'s status right after `createGoal()`
succeeds, so no leftover status survives to be misread by whatever screen
opens next. See `NovaSaveProvider.createGoal()`.

### Case: a local notification that silently never showed

The "notify on queued-send sync" stretch goal was implemented, wired
correctly into `QueueSyncService`, and never fired on-device — no crash,
no error, no notification, nothing in the logs pointing at why.

**Why AI produced it:** `NotificationService.init()` called
`FlutterLocalNotificationsPlugin.initialize()` and stopped there, which
is the complete setup on Android 12 and below. Android 13 (API 33)
introduced `POST_NOTIFICATIONS` as a runtime-requestable permission, on
top of still needing the manifest declaration — a newer platform
requirement than the training-data-era "standard" local-notifications
setup most examples show, so the generated code quietly matched an
outdated baseline instead of the OS version actually running on the test
device.

**How I caught it:** live-tested the full airplane-mode-send-then-
reconnect flow and watched for the system notification, which is the
only way this gap surfaces — `flutter analyze`/`flutter test` have no
way to assert a real OS permission prompt fired, and `show()` fails
silently rather than throwing when the permission is missing.

**The fix:** added `<uses-permission android:name=
"android.permission.POST_NOTIFICATIONS"/>` to `AndroidManifest.xml`,
plus an explicit `requestNotificationsPermission()` /
`requestPermissions()` call in `NotificationService.init()` for
Android/iOS respectively. Confirmed on-device afterward — required a
full uninstall/reinstall rather than a hot rebuild, since the
permission-prompt-on-first-launch behavior doesn't retrigger on an
already-installed app. See `NotificationService.init()` and
`AndroidManifest.xml`.

---

### Case: setting an explicit locale Flutter's own framework doesn't support

The Yoruba stretch goal originally relied on the device's system
language, but some Android builds never propagated a less-common
language (Yoruba) down into the app even after a full uninstall/
reinstall. The fix — an in-app EN/YO toggle setting `MaterialApp.locale`
directly — crashed instantly with "No MaterialLocalizations found" the
moment it was switched to Yoruba.

**Why AI produced it:** the suggestion treated "add `yo` to
`supportedLocales` and generate an `AppLocalizations` delegate for it"
as sufficient, the same pattern used for `en`. It didn't check whether
Flutter's own bundled `flutter_localizations` package — which supplies
`GlobalMaterialLocalizations`/`GlobalCupertinoLocalizations` (the
"OK"/"Cancel"/date-picker-style framework chrome, not our app's own
strings) — actually ships translation data for that locale. It doesn't:
a direct grep of the SDK's `generated_material_localizations.dart`
turned up zero `'yo'` entries out of 121 supported locale cases. A
correctly-generated custom `AppLocalizations` delegate is not the same
guarantee as the framework's own delegates supporting a locale, and
nothing about the setup would have surfaced that gap without running it.

**How I caught it:** live-tested the toggle on-device — the crash is a
hard `Localizations`-widget assertion failure that only fires at
runtime when a required delegate can't load the active locale;
`flutter analyze`/`flutter test` don't exercise real locale resolution
against the framework's actual bundled translation data.

**The fix:** added `fallback_framework_delegates.dart` — thin
`LocalizationsDelegate` wrappers around the three Global delegates that
report Yoruba as supported but silently load English underneath, so
only our own `AppLocalizations`-driven screens (Send Money, the result
screen) actually change language, while Flutter's own chrome falls back
to English instead of crashing. Also caught, same investigation: the
Send Money result screen (Transfer Successful/Failed/Pending, Done) had
never been wired to `AppLocalizations` at all and stayed hardcoded
English even after the crash was fixed — a plain omission, not a
framework limitation, closed by adding the missing arb keys and routing
`result_page.dart` through `AppLocalizations.of(context)!` like the
other three screens.

---

### Case: a swallowed exception disguised a plugin misconfiguration as a user action

Testing the ₦50,000 biometric-confirmation stretch goal: canceling the
prompt correctly showed "Authentication cancelled. Transfer not sent."
— but on the next attempt, no prompt ever appeared at all, and the
transfer failed with that exact same message anyway.

**Why AI produced it:** `BiometricService.authenticate()` wraps
`LocalAuthentication.authenticate()` in a blanket `catch (_) { return
false; }`, so a genuine plugin-level exception and a user tapping
Cancel are indistinguishable to the caller — both just come back as
`false`. The actual cause was `MainActivity.kt` extending plain
`FlutterActivity`; `local_auth`'s biometric dialog is AndroidX
Fragment-based and requires `FlutterFragmentActivity`, a Flutter-plugin
integration detail buried in `local_auth`'s own docs rather than
anything visible in this app's Dart code, so it was never flagged when
the biometric stub was first wired up.

**How I caught it:** the user reported "no prompt showed" on a retry —
a real cancel always shows the dialog first, so a failure with zero UI
meant the call was throwing before it could render, not being declined.

**The fix:** changed `MainActivity` to extend `FlutterFragmentActivity`
and added the `USE_BIOMETRIC` manifest permission. Native Android
change — required a full rebuild, not a hot reload, to take effect.
**Verified live** after rebuild. The masking `catch (_)` in `BiometricService` is
still worth flagging on its own: a caught-and-silenced exception is
exactly the class of bug this session kept finding (see the
notifications case above) — nothing here logs *why* authentication
failed, so a real misconfiguration reads identically to a deliberate
user cancel.

---

## My role vs AI's role

AI accelerated scaffolding and helped structure patterns I already
understood conceptually from production Flutter banking work. Every
suggestion was evaluated against:

- whether it actually satisfied the assessment's hard constraints
  (kobo-only math, exactly-once, restart survival);
- what a CBN-style regulator or a real bank's fraud/ops team would flag;
- Nigerian device and network realities (2GB RAM devices, patchy 3G,
  CGNAT-related connection drops, expensive mobile data);
- my own experience debugging offline-sync failures in a real banking
  codebase, which is what let me catch the double-dispatch bug above
  before it ever reached this repo's implementation.
