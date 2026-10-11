import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_strings.dart';
import 'core/di/injection_container.dart' as di;
import 'core/services/notification_service.dart';
import 'core/services/presence_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/chat/domain/entities/chat_entity.dart';
import 'features/chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import 'features/chat/presentation/bloc/chat_list/chat_list_event.dart';
import 'features/chat/presentation/bloc/chat_room/chat_room_bloc.dart';
import 'features/chat/presentation/bloc/chat_room/chat_room_event.dart';
import 'features/chat/presentation/pages/chat_room_page.dart';
import 'features/chat/presentation/pages/home_page.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely
  try {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );

      // Register top-level background/terminated messaging handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize Service Locator (GetIt)
  await di.initDependencies();

  // Initialize online/offline presence tracking
  di.sl<PresenceService>().initialize();

  // Initialize Notification Service (Foreground, Background & Kill state handlers)
  await di.sl<NotificationService>().initialize(
    onNotificationTapped: (chatId) {
      if (chatId.isEmpty) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(
            chat: ChatEntity(
              id: chatId,
              name: 'Chat',
              lastMessage: '',
              lastMessageTime: DateTime.now(),
            ),
          ),
        ),
      );
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (_) => di.sl<ThemeCubit>(),
        ),
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatusEvent()),
        ),
        BlocProvider<ChatListBloc>(
          create: (_) => di.sl<ChatListBloc>(),
        ),
        BlocProvider<ChatRoomBloc>(
          create: (_) => di.sl<ChatRoomBloc>(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const RootGatePage(),
          );
        },
      ),
    );
  }
}

class RootGatePage extends StatelessWidget {
  const RootGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Unauthenticated) {
          context.read<ChatListBloc>().add(const ResetChatListEvent());
          context.read<ChatRoomBloc>().add(const ResetChatRoomEvent());
        }
      },
      builder: (context, state) {
        if (state is Authenticated) {
          return const HomePage();
        }
        if (state is Unauthenticated || state is AuthError) {
          return const LoginPage();
        }
        // Initial cold-start / auth status check splash before session state is confirmed
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
