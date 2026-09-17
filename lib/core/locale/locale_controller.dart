import 'package:flutter/material.dart';

class LocaleController extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isYoruba => _locale.languageCode == 'yo';

  void toggle() {
    _locale = isYoruba ? const Locale('en') : const Locale('yo');
    notifyListeners();
  }
}
