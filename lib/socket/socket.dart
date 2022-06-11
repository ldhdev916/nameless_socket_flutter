import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:nameless_socket_flutter/socket/auth_service.dart';
import 'package:nameless_socket_flutter/socket/notification_controller.dart';
import 'package:nameless_socket_flutter/socket/stomp_chat.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_handler.dart';
import 'package:uuid/uuid.dart';

class StompController extends GetxController {
  final _connected = false.obs;

  bool get connected => _connected.value;

  late StompClient _client;

  late String _uuid;

  String get uuid => _uuid;

  final onlinePlayers = <String>{}.obs;

  final _chats = <String, List<StompChat>>{};

  void logout() {
    _client.deactivate();
  }

  List<StompChat> getOrCreateChats({required String player}) =>
      _chats.putIfAbsent(player, () => <StompChat>[].obs);

  Future<bool> connect({required AuthService service}) async {
    final uuid = await service.authenticate();
    if (uuid == null) {
      return false;
    }
    _uuid = uuid;
    _client = StompClient(
        config: StompConfig(
            url: "ws://3.37.56.106/nameless/stomp",
            webSocketConnectHeaders: {"uuid": uuid, "mod-version": "Flutter"},
            onConnect: (_) {
              _connected.value = true;

              subscribe(
                  destination: "/user/join",
                  callback: (frame) => onlinePlayers.add(frame.body!));
              subscribe(
                  destination: "/user/disconnect",
                  callback: (frame) => onlinePlayers.remove(frame.body!));

              subscribeUser(
                  destination: "/position",
                  callback: (_) async {
                    final response =
                        await http.get(Uri.parse("https://api.ipify.org"));
                    send(destination: "/position", body: response.body);
                  });

              subscribeUser(
                  destination: "/chats/send",
                  callback: (frame) {
                    final sender = frame.headers["sender"]!;
                    final chatId = frame.headers["chat-id"]!;
                    final content = frame.body!;
                    final data = StompChatData(
                        content: content, id: chatId, at: DateTime.now());
                    final chat = StompChatReceived(data: data, sender: sender);
                    getOrCreateChats(player: sender).add(chat);
                    var controller = Get.find<NotificationController>();
                    log(controller.toString());
                    controller.pushNotification(chat: chat);
                  });

              subscribeUser(
                  destination: "/chats/read",
                  callback: (frame) {
                    final reader = frame.headers["reader"]!;
                    final chatId = frame.headers["chat-id"]!;
                    final chats = getOrCreateChats(player: reader);
                    final target = chats.firstWhere((element) =>
                        element is StompChatSending &&
                        element.data.id == chatId) as StompChatSending;
                    final copy = StompChatSending(
                        data: target.data, receiver: target.receiver)
                      ..read = true;
                    chats[chats.lastIndexOf(target)] = copy;
                  });
            },
            onDisconnect: (_) => _connected.value = false,
            onDebugMessage: (s) => log(s),
            onStompError: (e) => log("A stomp error occurred: $e"),
            onWebSocketError: (e) {
              log("A websocket error occurred: $e");
              _connected.value = false;
            }))
      ..activate();
    return true;
  }

  void updateOnlinePlayers() {
    StompUnsubscribe? unsubscribe;

    unsubscribe = subscribeUser(
        destination: "/onlines",
        callback: (frame) {
          onlinePlayers.clear();
          onlinePlayers.addAll(List<String>.from(jsonDecode(frame.body!)));

          unsubscribe!();
        });

    send(destination: "/onlines");
  }

  void sendChat({required String receiver, required String content}) {
    final data = StompChatData(
        content: content, id: const Uuid().v4(), at: DateTime.now());
    final chat = StompChatSending(data: data, receiver: receiver);
    getOrCreateChats(player: receiver).add(chat);
    send(
        destination: "/chats/send/$receiver",
        headers: {"chat-id": chat.data.id},
        body: content);
  }

  void markChatAsRead({required StompChatReceived chat}) {
    if (chat.markedAsRead) return;
    final chats = getOrCreateChats(player: chat.sender);
    final target = chats.firstWhere((element) =>
        element is StompChatReceived && element.data.id == chat.data.id);
    chats[chats.lastIndexOf(target)] =
        StompChatReceived(data: chat.data, sender: chat.sender)
          ..markedAsRead = true;
    send(
        destination: "/chats/read/${chat.sender}",
        headers: {"chat-id": chat.data.id});
  }

  // delegate

  StompUnsubscribe subscribeUser({
    required String destination,
    required StompFrameCallback callback,
    Map<String, String>? headers,
  }) =>
      _client.subscribe(
          destination: "/user/topic$destination",
          callback: callback,
          headers: headers);

  StompUnsubscribe subscribe({
    required String destination,
    required StompFrameCallback callback,
    Map<String, String>? headers,
  }) =>
      _client.subscribe(
          destination: "/topic$destination",
          callback: callback,
          headers: headers);

  void send({
    required String destination,
    Map<String, String>? headers,
    String? body,
    Uint8List? binaryBody,
  }) =>
      _client.send(
          destination: "/mod$destination",
          headers: headers,
          body: body,
          binaryBody: binaryBody);
}
