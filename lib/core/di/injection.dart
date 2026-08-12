import 'package:get_it/get_it.dart';
import '../../features/auth/data/repositories/supabase_auth_repository.dart';
import '../../features/auth/domain/repositories/i_auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_viewmodel.dart';
import '../../features/communication/data/repositories/supabase_announcement_repository.dart';
import '../../features/communication/data/repositories/supabase_chat_attachment_repository.dart';
import '../../features/communication/data/repositories/supabase_conversation_repository.dart';
import '../../features/communication/data/repositories/supabase_message_repository.dart';
import '../../features/communication/data/repositories/supabase_notification_repository.dart';
import '../../features/communication/domain/repositories/i_announcement_repository.dart';
import '../../features/communication/domain/repositories/i_chat_attachment_repository.dart';
import '../../features/communication/domain/repositories/i_conversation_repository.dart';
import '../../features/communication/domain/repositories/i_message_repository.dart';
import '../../features/communication/domain/repositories/i_notification_repository.dart';
import '../../features/admin/domain/repositories/i_admin_repository.dart';
import '../../features/admin/data/repositories/supabase_admin_repository.dart';
import '../config/app_config.dart';
import '../localization/app_locale_controller.dart';
import '../network/supabase_client_wrapper.dart';
import '../notifications/push_notification_service.dart';
import '../services/settings_service.dart';
import '../services/report_generator_service.dart';

final getIt = GetIt.instance;

/// Setup dependency injection bindings for the application.
Future<void> setupDependencyInjection({
  SupabaseClientWrapper? supabaseClientWrapper,
  IAuthRepository? authRepository,
  IConversationRepository? conversationRepository,
  IMessageRepository? messageRepository,
  IChatAttachmentRepository? chatAttachmentRepository,
  INotificationRepository? notificationRepository,
  IAnnouncementRepository? announcementRepository,
  IAdminRepository? adminRepository,
}) async {
  if (supabaseClientWrapper != null) {
    if (getIt.isRegistered<SupabaseClientWrapper>()) {
      getIt.unregister<SupabaseClientWrapper>();
    }
    getIt.registerSingleton<SupabaseClientWrapper>(supabaseClientWrapper);
  } else if (!getIt.isRegistered<SupabaseClientWrapper>()) {
    AppConfig.printSafeDiagnostics();
    final wrapper = await SupabaseClientWrapper.initialize(
      url: AppConfig.effectiveSupabaseUrl,
      anonKey: AppConfig.effectiveSupabaseAnonKey,
    );
    getIt.registerSingleton<SupabaseClientWrapper>(wrapper);
  }

  if (!getIt.isRegistered<SettingsService>()) {
    final settingsService = SettingsService();
    await settingsService.init();
    getIt.registerSingleton<SettingsService>(settingsService);
  }

  if (!getIt.isRegistered<AppLocaleController>()) {
    final localeController = AppLocaleController();
    await localeController.load();
    getIt.registerSingleton<AppLocaleController>(localeController);
  }

  if (!getIt.isRegistered<ReportGeneratorService>()) {
    final reportGeneratorService = ReportGeneratorService();
    getIt.registerSingleton<ReportGeneratorService>(reportGeneratorService);
  }

  if (AppConfig.hasFirebaseConfig &&
      !getIt.isRegistered<PushNotificationService>() &&
      getIt.isRegistered<SupabaseClientWrapper>()) {
    final pushService = PushNotificationService(getIt<SupabaseClientWrapper>());
    await pushService.initialize();
    getIt.registerSingleton<PushNotificationService>(pushService);
  }

  if (authRepository != null) {
    if (getIt.isRegistered<IAuthRepository>()) {
      getIt.unregister<IAuthRepository>();
    }
    getIt.registerSingleton<IAuthRepository>(authRepository);
  } else if (!getIt.isRegistered<IAuthRepository>() &&
      getIt.isRegistered<SupabaseClientWrapper>()) {
    getIt.registerLazySingleton<IAuthRepository>(
      () => SupabaseAuthRepository(getIt<SupabaseClientWrapper>()),
    );
  }

  if (getIt.isRegistered<AuthViewModel>()) {
    getIt.unregister<AuthViewModel>();
  }
  if (getIt.isRegistered<IAuthRepository>()) {
    getIt.registerFactory<AuthViewModel>(
      () => AuthViewModel(
        getIt<IAuthRepository>(),
        pushNotificationService: getIt.isRegistered<PushNotificationService>()
            ? getIt<PushNotificationService>()
            : null,
      ),
    );
  }

  // Phase 9 Communication Repositories
  if (getIt.isRegistered<SupabaseClientWrapper>()) {
    if (!getIt.isRegistered<IConversationRepository>()) {
      getIt.registerLazySingleton<IConversationRepository>(
        () =>
            conversationRepository ??
            SupabaseConversationRepository(getIt<SupabaseClientWrapper>()),
      );
    }
    if (!getIt.isRegistered<IMessageRepository>()) {
      getIt.registerLazySingleton<IMessageRepository>(
        () =>
            messageRepository ??
            SupabaseMessageRepository(getIt<SupabaseClientWrapper>()),
      );
    }
    if (!getIt.isRegistered<IChatAttachmentRepository>()) {
      getIt.registerLazySingleton<IChatAttachmentRepository>(
        () =>
            chatAttachmentRepository ??
            SupabaseChatAttachmentRepository(getIt<SupabaseClientWrapper>()),
      );
    }
    if (!getIt.isRegistered<INotificationRepository>()) {
      getIt.registerLazySingleton<INotificationRepository>(
        () =>
            notificationRepository ??
            SupabaseNotificationRepository(getIt<SupabaseClientWrapper>()),
      );
    }
    if (!getIt.isRegistered<IAnnouncementRepository>()) {
      getIt.registerLazySingleton<IAnnouncementRepository>(
        () =>
            announcementRepository ??
            SupabaseAnnouncementRepository(getIt<SupabaseClientWrapper>()),
      );
    }

    if (!getIt.isRegistered<IAdminRepository>()) {
      getIt.registerLazySingleton<IAdminRepository>(
        () =>
            adminRepository ??
            SupabaseAdminRepository(getIt<SupabaseClientWrapper>()),
      );
    }
  }
}
