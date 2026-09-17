import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/connectivity/connectivity_service.dart';
import 'core/di/service_locator.dart';
import 'core/locale/fallback_framework_delegates.dart';
import 'core/locale/locale_controller.dart';
import 'core/queue/queue_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'features/nova_save/providers/nova_save_provider.dart';
import 'features/send_money/providers/send_money_provider.dart';
import 'features/wallet/presentation/wallet_home_page.dart';
import 'features/wallet/providers/wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();

  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  runApp(const NovaWalletApp());
}

class NovaWalletApp extends StatelessWidget {
  const NovaWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleController()),
        ChangeNotifierProvider.value(value: getIt<ConnectivityService>()),
        ChangeNotifierProvider(
          create: (_) => WalletProvider(
            dio: getIt(),
            db: getIt(),
          )..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => SendMoneyProvider(
            dio: getIt(),
            db: getIt(),
            connectivity: getIt(),
            biometrics: getIt(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => NovaSaveProvider(
            dio: getIt(),
            db: getIt(),
            connectivity: getIt(),
          )..loadGoals(),
        ),
      ],
      child: Consumer<LocaleController>(
        builder: (context, localeController, _) => _ConnectivitySyncBridge(
          child: MaterialApp(
            title: 'NovaWallet',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            locale: localeController.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FallbackMaterialLocalizationsDelegate(),
              FallbackWidgetsLocalizationsDelegate(),
              FallbackCupertinoLocalizationsDelegate(),
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('yo'),
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context),
              child: child!,
            ),
            home: const WalletHomePage(),
          ),
        ),
      ),
    );
  }
}

class _ConnectivitySyncBridge extends StatefulWidget {
  final Widget child;
  const _ConnectivitySyncBridge({required this.child});

  @override
  State<_ConnectivitySyncBridge> createState() =>
      _ConnectivitySyncBridgeState();
}

class _ConnectivitySyncBridgeState extends State<_ConnectivitySyncBridge> {
  bool _wasOnline = true;
  bool _didStartupSync = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupSync());
  }

  Future<void> _runStartupSync() async {
    if (_didStartupSync || !mounted) return;
    _didStartupSync = true;

    final walletProvider = context.read<WalletProvider>();
    final novaSaveProvider = context.read<NovaSaveProvider>();
    final isOnline = await context.read<ConnectivityService>().checkOnline();
    if (!isOnline) return;

    await getIt<QueueSyncService>().sync();
    if (!mounted) return;
    await walletProvider.refreshLocalOnly();
    await novaSaveProvider.loadGoals();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, child) {
        if (!_wasOnline && connectivity.isOnline) {
          final walletProvider = context.read<WalletProvider>();
          final novaSaveProvider = context.read<NovaSaveProvider>();
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await getIt<QueueSyncService>().sync();
            await walletProvider.refreshLocalOnly();
            await novaSaveProvider.loadGoals();
          });
        }
        _wasOnline = connectivity.isOnline;
        return child!;
      },
      child: widget.child,
    );
  }
}
