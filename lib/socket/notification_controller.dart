import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:nameless_socket_flutter/socket/stomp_chat.dart';

class NotificationController extends GetxController {
  final _plugin = FlutterLocalNotificationsPlugin()
    ..initialize(const InitializationSettings(
        android: AndroidInitializationSettings("chat")));
  String? currentOnGoingChat;

  void pushNotification({required StompChatReceived chat}) {
    if (chat.sender == currentOnGoingChat) return;
    try {
      _plugin.show(
          chat.sender.hashCode,
          chat.sender,
          chat.data.content,
          const NotificationDetails(
              android: AndroidNotificationDetails(
                  "CHAT_NOTIFICATION", "Nameless Socket Chatting",
                  importance: Importance.high)));
    } catch (e) {
      e.printError();
    }
  }
}

class OnGoingChatController extends GetxController {
  final String player;

  OnGoingChatController({required this.player});

  @override
  void onInit() {
    super.onInit();
    Get.find<NotificationController>().currentOnGoingChat = player;
  }

  @override
  void onClose() {
    super.onClose();
    Get.find<NotificationController>().currentOnGoingChat = null;
  }
}
