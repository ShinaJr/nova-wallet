// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Yoruba (`yo`).
class AppLocalizationsYo extends AppLocalizations {
  AppLocalizationsYo([String locale = 'yo']) : super(locale);

  @override
  String get sendMoney => 'Rán Owó';

  @override
  String get recipient => 'Olùgbà';

  @override
  String get amount => 'Iye Owó';

  @override
  String get confirm => 'Jẹrisi';

  @override
  String get confirmAndSend => 'Jẹrisi Kí O Sì Rán';

  @override
  String get cancel => 'Fagilé';

  @override
  String get continueLabel => 'Tẹ̀síwájú';

  @override
  String get accountNumber => 'Nọ́mbà Àkáǹtì';

  @override
  String get bankName => 'Ilé-Ifowópamọ́';

  @override
  String get narration => 'Àlàyé (kò pọn dandan)';

  @override
  String get pendingMessage =>
      'Ó ń dúró — a ó rán nígbà tí ẹ bá padà sí íntánẹ́ẹ̀tì';

  @override
  String get offlineBanner =>
      'Ẹ kò sí lórí íntánẹ́ẹ̀tì — a ó fi àwọn iṣe pamọ́ tí a ó sì rán wọn láifọwọ́yí';

  @override
  String get offlineConfirmNotice =>
      'Ẹ kò sí lórí íntánẹ́ẹ̀tì. A ó fi ìsanwó yìí pamọ́ tí a ó sì rán an láifọwọ́yí nígbà tí ẹ bá padà sí íntánẹ́ẹ̀tì.';

  @override
  String get biometricPrompt => 'Jẹrisi ìdánimọ̀ rẹ fún ìsanwó yìí';

  @override
  String get availableBalance => 'Owó tí ó wà fún lílò';

  @override
  String get insufficientFunds => 'Owó kò tó';

  @override
  String get lookingUpAccount => 'Ń wá àkáǹtì...';

  @override
  String get confirmTransfer => 'Jẹrisi Ìsanwó';

  @override
  String sendTo(String name) {
    return 'Rán owó sí $name';
  }

  @override
  String get recipientAccountHint => 'Nọ́mbà àkáǹtì olùgbà, oni-nọ́mbà mẹ́wàá';

  @override
  String recipientFound(String name) {
    return 'A rí olùgbà: $name';
  }

  @override
  String get amountToSendLabel => 'Iye owó tí a ó rán ní Náírà';

  @override
  String availableAmount(String amount) {
    return 'Tí ó wà: $amount';
  }

  @override
  String get exceedsAvailableBalance =>
      'Èyí ju owó tí ó wà lọ. Apá kan owó rẹ lè ti wà ní ìdúró fún ìsanwó mìíràn tí kò tíì rán.';

  @override
  String get to => 'Sí';

  @override
  String get account => 'Àkáǹtì';

  @override
  String get transferSuccessful => 'Ìsanwó Ti Yege';

  @override
  String get transferFailed => 'Ìsanwó Kùnà';

  @override
  String get pendingTitle => 'Ó ń dúró';

  @override
  String get pendingSubtitle => 'A ó rán nígbà tí ẹ bá padà sí íntánẹ́ẹ̀tì';

  @override
  String referenceLabel(String ref) {
    return 'Àmì ìdánimọ̀: $ref';
  }

  @override
  String get done => 'Ti Parí';
}
