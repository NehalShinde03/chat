import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../theme/theme_cubit.dart';

// Auth Feature
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_with_google_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Chat Feature
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/datasources/chat_remote_datasource.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/delete_conversation_usecase.dart';
import '../../features/chat/domain/usecases/delete_message_usecase.dart';
import '../../features/chat/domain/usecases/forward_message_usecase.dart';
import '../../features/chat/domain/usecases/get_chats_usecase.dart';
import '../../features/chat/domain/usecases/get_messages_usecase.dart';
import '../../features/chat/domain/usecases/get_or_create_conversation_usecase.dart';
import '../../features/chat/domain/usecases/get_registered_users_usecase.dart';
import '../../features/chat/domain/usecases/get_typing_stream_usecase.dart';
import '../../features/chat/domain/usecases/mark_as_read_usecase.dart';
import '../../features/chat/domain/usecases/search_chats_usecase.dart';
import '../../features/chat/domain/usecases/search_messages_usecase.dart';
import '../../features/chat/domain/usecases/send_message_usecase.dart';
import '../../features/chat/domain/usecases/set_typing_status_usecase.dart';
import '../../features/chat/domain/usecases/toggle_archive_chat_usecase.dart';
import '../../features/chat/domain/usecases/toggle_pin_chat_usecase.dart';
import '../../features/chat/domain/usecases/get_user_profile_stream_usecase.dart';
import '../../features/chat/presentation/bloc/chat_list/chat_list_bloc.dart';
import '../../features/chat/presentation/bloc/chat_room/chat_room_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ! External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => sharedPreferences);

  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn());

  // Core
  sl.registerFactory<ThemeCubit>(
    () => ThemeCubit(sharedPreferences: sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<PresenceService>(
    () => PresenceService(
      firestore: sl<FirebaseFirestore>(),
      firebaseAuth: sl<FirebaseAuth>(),
    ),
  );
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(),
  );

  // ! Features - Auth
  // Data Sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sharedPreferences: sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      firebaseAuth: sl<FirebaseAuth>(),
      googleSignIn: sl<GoogleSignIn>(),
      firestore: sl<FirebaseFirestore>(),
    ),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
      localDataSource: sl<AuthLocalDataSource>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignInWithGoogleUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignOutUseCase(sl<AuthRepository>()));

  // Presentation (Bloc)
  sl.registerFactory(
    () => AuthBloc(
      getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
      signInWithGoogleUseCase: sl<SignInWithGoogleUseCase>(),
      signOutUseCase: sl<SignOutUseCase>(),
    ),
  );

  // ! Features - Chat
  // Data Sources
  sl.registerLazySingleton<ChatLocalDataSource>(
    () => ChatLocalDataSourceImpl(sharedPreferences: sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(firestore: sl<FirebaseFirestore>()),
  );

  // Repository
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      localDataSource: sl<ChatLocalDataSource>(),
      remoteDataSource: sl<ChatRemoteDataSource>(),
      firebaseAuth: sl<FirebaseAuth>(),
    ),
  );

  // Use Cases
  sl.registerLazySingleton(() => GetChatsUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetMessagesUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SendMessageUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => TogglePinChatUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => ToggleArchiveChatUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => ForwardMessageUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => MarkAsReadUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SearchChatsUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SearchMessagesUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetRegisteredUsersUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetOrCreateConversationUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetUserProfileStreamUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => DeleteMessageUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => DeleteConversationUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => SetTypingStatusUseCase(sl<ChatRepository>()));
  sl.registerLazySingleton(() => GetTypingStreamUseCase(sl<ChatRepository>()));

  // Presentation (Blocs)
  sl.registerFactory(
    () => ChatListBloc(
      getChatsUseCase: sl<GetChatsUseCase>(),
      searchChatsUseCase: sl<SearchChatsUseCase>(),
      togglePinChatUseCase: sl<TogglePinChatUseCase>(),
      toggleArchiveChatUseCase: sl<ToggleArchiveChatUseCase>(),
      markAsReadUseCase: sl<MarkAsReadUseCase>(),
      deleteConversationUseCase: sl<DeleteConversationUseCase>(),
    ),
  );

  sl.registerFactory(
    () => ChatRoomBloc(
      getMessagesUseCase: sl<GetMessagesUseCase>(),
      sendMessageUseCase: sl<SendMessageUseCase>(),
      forwardMessageUseCase: sl<ForwardMessageUseCase>(),
      searchMessagesUseCase: sl<SearchMessagesUseCase>(),
      deleteMessageUseCase: sl<DeleteMessageUseCase>(),
    ),
  );
}
