import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:nameless_socket_flutter/socket/chat_room.dart';
import 'package:nameless_socket_flutter/socket/loading.dart';
import 'package:nameless_socket_flutter/socket/notification_controller.dart';
import 'package:nameless_socket_flutter/socket/player_icon.dart';
import 'package:nameless_socket_flutter/socket/socket.dart';
import 'package:nameless_socket_flutter/socket/stomp_chat.dart';
import 'package:sizer/sizer.dart';

import 'socket/auth.dart';

void main() {
  Get.put(StompController(), permanent: true);
  Get.put(NotificationController(), permanent: true);
  Get.put(
      const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true)),
      permanent: true);
  runApp(const NamelessApp());
}

class NamelessApp extends GetView<StompController> {
  const NamelessApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Sizer(
        builder: (_, __, ___) => GetMaterialApp(
                title: "Nameless Socket Chatting",
                initialRoute: "/auth",
                getPages: [
                  GetPage(
                      name: "/",
                      page: () => Obx(() => controller.connected
                          ? SocketHome()
                          : LoadingCircle())),
                  GetPage(
                      name: "/chat/:player",
                      page: () => ChatRoom(),
                      binding: BindingsBuilder(() {
                        Get.put(OnGoingChatController(
                            player: Get.parameters["player"]!));
                      })),
                  GetPage(name: "/auth", page: () => AuthHome())
                ]));
  }
}

class SocketHome extends GetResponsiveView<StompController> {
  SocketHome({Key? key}) : super(key: key);

  @override
  Widget? builder() {
    controller.updateOnlinePlayers();
    return Scaffold(
        appBar: AppBar(
            title: const Text("Nameless Socket Chatting"),
            centerTitle: true,
            actions: [
              IconButton(
                  onPressed: () {
                    controller.logout();
                    Get.offAllNamed("/auth");
                  },
                  icon: const Icon(Icons.logout)),
              getPlayerIcon(name: controller.uuid)
            ]),
        body: Center(
            child: Obx(() => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: controller.onlinePlayers.map((element) {
                  final unReadChatCount = controller
                      .getOrCreateChats(player: element)
                      .whereType<StompChatReceived>()
                      .where((chat) => !chat.markedAsRead)
                      .length;
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Visibility(
                            visible: unReadChatCount > 0,
                            child: Text(unReadChatCount.toString(),
                                style: const TextStyle(color: Colors.red))),
                        IconButton(
                            onPressed: () => Get.toNamed("/chat/$element"),
                            icon: getPlayerIcon(name: element),
                            iconSize: 5.h),
                        SizedBox(width: screen.width * 0.01),
                        Text(element, style: const TextStyle(fontSize: 20))
                      ]);
                }).toList()))));
  }
}
