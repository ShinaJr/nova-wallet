// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get sendMoney => 'Send Money';

  @override
  String get recipient => 'Recipient';

  @override
  String get amount => 'Amount';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmAndSend => 'Confirm & Send';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get accountNumber => 'Account Number';

  @override
  String get bankName => 'Bank';

  @override
  String get narration => 'Narration (optional)';

  @override
  String get pendingMessage => 'Pending — will send when back online';

  @override
  String get offlineBanner =>
      'You\'re offline — actions will be queued and sent automatically';

  @override
  String get offlineConfirmNotice =>
      'You\'re offline. This will be queued and sent automatically when you reconnect.';

  @override
  String get biometricPrompt =>
      'Confirm your identity to proceed with this transfer';

  @override
  String get availableBalance => 'Available to spend';

  @override
  String get insufficientFunds => 'Insufficient balance';

  @override
  String get lookingUpAccount => 'Looking up account...';

  @override
  String get confirmTransfer => 'Confirm Transfer';

  @override
  String sendTo(String name) {
    return 'Send to $name';
  }

  @override
  String idempotencyKeyLabel(String key) {
    return 'Idempotency key: $key';
  }

  @override
  String get recipientAccountHint => 'Recipient account number, 10 digits';

  @override
  String recipientFound(String name) {
    return 'Recipient found: $name';
  }

  @override
  String get amountToSendLabel => 'Amount to send in Naira';

  @override
  String availableAmount(String amount) {
    return 'Available: $amount';
  }

  @override
  String get exceedsAvailableBalance =>
      'This exceeds your available balance. Some of your balance may already be committed to a pending offline transfer.';

  @override
  String get to => 'To';

  @override
  String get account => 'Account';

  @override
  String get transferSuccessful => 'Transfer Successful';

  @override
  String get transferFailed => 'Transfer Failed';

  @override
  String get pendingTitle => 'Pending';

  @override
  String get pendingSubtitle => 'Will send when back online';

  @override
  String referenceLabel(String ref) {
    return 'Ref: $ref';
  }

  @override
  String get done => 'Done';
}
