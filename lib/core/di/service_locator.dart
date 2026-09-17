import 'package:get_it/get_it.dart';

import '../biometrics/biometric_service.dart';
import '../connectivity/connectivity_service.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../network/mock_interceptor.dart';
import '../notifications/notification_service.dart';
import '../queue/queue_sync_service.dart';
import '../storage/secure_storage_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final db = AppDatabase();
  await db.recoverOrphanedProcessing();
  await db.seedIfEmpty();
  getIt.registerSingleton<AppDatabase>(db);

  final wallet = await db.getWallet();
  if (wallet != null) {
    MockInterceptor.seedBalance(wallet.ledgerBalanceKobo);
  }

  getIt.registerSingleton<DioClient>(DioClient());

  getIt.registerSingleton<ConnectivityService>(ConnectivityService());

  final notifications = NotificationService();
  await notifications.init();
  getIt.registerSingleton<NotificationService>(notifications);

  getIt.registerSingleton<BiometricService>(BiometricService());

  getIt.registerSingleton<SecureStorageService>(SecureStorageService());
  await getIt<SecureStorageService>().saveMockAuthToken();

  getIt.registerSingleton<QueueSyncService>(
    QueueSyncService(
      db: getIt<AppDatabase>(),
      dio: getIt<DioClient>(),
      notifications: getIt<NotificationService>(),
    ),
  );
}

Future<void> resetServiceLocator() async {
  await getIt.reset();
}
