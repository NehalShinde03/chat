import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

abstract class ChatLocalDataSource {
  Future<List<ChatModel>> getChats();
  Future<void> saveChats(List<ChatModel> chats);
  Future<List<MessageModel>> getMessages(String chatId);
  Future<void> saveMessages(String chatId, List<MessageModel> messages);
  Future<void> deleteMessage(String chatId, String messageId);
  Future<void> deleteConversation(String chatId);
  Future<void> clearAll();
}

class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  final SharedPreferences sharedPreferences;

  ChatLocalDataSourceImpl({required this.sharedPreferences});

  String _getChatsKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return 'CACHED_CHATS_$uid';
  }

  String _getMessagesKey(String chatId) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return 'CACHED_MESSAGES_${uid}_$chatId';
  }

  @override
  Future<List<ChatModel>> getChats() async {
    final jsonString = sharedPreferences.getString(_getChatsKey());
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List decoded = jsonDecode(jsonString) as List;
        return decoded
            .map((e) => ChatModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<void> saveChats(List<ChatModel> chats) async {
    try {
      final list = chats.map((c) => c.toJson()).toList();
      await sharedPreferences.setString(_getChatsKey(), jsonEncode(list));
    } catch (_) {}
  }

  @override
  Future<List<MessageModel>> getMessages(String chatId) async {
    final jsonString = sharedPreferences.getString(_getMessagesKey(chatId));
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List decoded = jsonDecode(jsonString) as List;
        return decoded
            .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return [];
  }

  @override
  Future<void> saveMessages(String chatId, List<MessageModel> messages) async {
    try {
      final list = messages.map((m) => m.toJson()).toList();
      await sharedPreferences.setString(
        _getMessagesKey(chatId),
        jsonEncode(list),
      );
    } catch (_) {}
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      final messages = await getMessages(chatId);
      final updated = messages.where((m) => m.id != messageId).toList();
      await saveMessages(chatId, updated);
    } catch (_) {}
  }

  @override
  Future<void> deleteConversation(String chatId) async {
    try {
      final chats = await getChats();
      final updated = chats.where((c) => c.id != chatId).toList();
      await saveChats(updated);
      await sharedPreferences.remove(_getMessagesKey(chatId));
    } catch (_) {}
  }

  @override
  Future<void> clearAll() async {
    final keys = sharedPreferences.getKeys();
    for (final key in keys) {
      if (key.startsWith('CACHED_CHATS_') ||
          key.startsWith('CACHED_MESSAGES_') ||
          key == 'CACHED_CHATS_LIST') {
        await sharedPreferences.remove(key);
      }
    }
  }
}
