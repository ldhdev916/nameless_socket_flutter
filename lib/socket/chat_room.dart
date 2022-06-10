import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:nameless_socket_flutter/socket/socket.dart';
import 'package:nameless_socket_flutter/socket/stomp_chat.dart';
import 'package:sizer/sizer.dart';

abstract class ChatUIProvider {
  const ChatUIProvider();

  MainAxisAlignment provideAlign();

  Color provideColor();

  List<Widget> provideWidget(Widget indicator, Widget chatBox);

  factory ChatUIProvider.create(StompChat chat) => chat is StompChatSending
      ? SendingChatUIProvider()
      : ReceivedChatUIProvider();
}

class SendingChatUIProvider extends ChatUIProvider {
  @override
  MainAxisAlignment provideAlign() => MainAxisAlignment.end;

  @override
  Color provideColor() => Colors.yellow;

  @override
  List<Widget> provideWidget(Widget indicator, Widget chatBox) =>
      [indicator, chatBox];
}

class ReceivedChatUIProvider extends ChatUIProvider {
  @override
  MainAxisAlignment provideAlign() => MainAxisAlignment.start;

  @override
  Color provideColor() => Colors.white;

  @override
  List<Widget> provideWidget(Widget indicator, Widget chatBox) =>
      [chatBox, indicator];
}

class ChatRoom extends GetResponsiveView<StompController> {
  ChatRoom({Key? key}) : super(key: key);

  final _content = "".obs;

  @override
  Widget? builder() {
    final player = Get.parameters["player"]!;
    final editController = TextEditingController();

    editController.addListener(() => _content(editController.text));

    final scrollController = ScrollController();
    return Scaffold(
        appBar: AppBar(title: Text(player), centerTitle: true),
        body: Padding(
            padding: EdgeInsets.only(bottom: screen.height * 0.01),
            child: Container(
                color: Colors.grey,
                child: Obx(() {
                  final chats = controller.getOrCreateChats(player: player);
                  if (scrollController.hasClients) {
                    Future.delayed(
                        const Duration(milliseconds: 100),
                        () => scrollController.animateTo(
                            scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.fastOutSlowIn));
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    for (var value in chats) {
                      if (value is StompChatReceived) {
                        controller.markChatAsRead(chat: value);
                      }
                    }
                  });
                  return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: screen.width * 0.02,
                          vertical: screen.height * 0.02),
                      child: ListView.separated(
                          controller: scrollController,
                          itemBuilder: (_, index) =>
                              ChatBox(chat: chats[index]),
                          separatorBuilder: (_, __) => SizedBox(height: 1.w),
                          itemCount: chats.length));
                }))),
        bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(screen.context).viewInsets.bottom),
            child: TextField(
                controller: editController,
                decoration: InputDecoration(
                    labelText: "Sending Chat",
                    border: const OutlineInputBorder(),
                    suffixIcon: Obx(() => IconButton(
                        onPressed: _content.isEmpty
                            ? null
                            : () {
                                controller.sendChat(
                                    receiver: player, content: _content.value);
                                editController.clear();
                              },
                        icon: const Icon(Icons.send),
                        color: Colors.yellow))),
                autofocus: true,
                minLines: 1,
                maxLines: 3)));
  }
}

class ChatBox extends GetResponsiveView {
  final StompChat chat;

  ChatBox({Key? key, required this.chat}) : super(key: key);

  @override
  Widget? builder() {
    final provider = ChatUIProvider.create(chat);
    final format = DateFormat.jm();

    return Row(mainAxisAlignment: provider.provideAlign(), children: [
      Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: screen.width * 0.01,
          children: provider.provideWidget(
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Visibility(
                    visible: chat is StompChatSending &&
                        !(chat as StompChatSending).read,
                    child: const Text("1",
                        style: TextStyle(color: Colors.yellow, fontSize: 14))),
                Text(format.format(chat.data.at),
                    style: const TextStyle(fontSize: 14))
              ]),
              Container(
                  padding: EdgeInsets.all(1.h),
                  decoration: BoxDecoration(
                      color: provider.provideColor(),
                      borderRadius: BorderRadius.circular(2.h)),
                  child: Text(chat.data.content))))
    ]);
  }
}
