package com.example.nova_wallet

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's biometric prompt is AndroidX Fragment-based and requires the
// host Activity to be a FragmentActivity — plain FlutterActivity throws
// before any dialog shows, which BiometricService.authenticate()'s catch-all
// silently turns into a false "Authentication cancelled" result.
class MainActivity : FlutterFragmentActivity()
