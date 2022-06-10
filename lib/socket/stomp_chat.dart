class StompChatData {
  final String content;
  final String id;
  final DateTime at;

  const StompChatData(
      {required this.content, required this.id, required this.at});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StompChatData &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'StompChatData{content: $content, id: $id, at: $at}';
  }
}

abstract class StompChat {
  final StompChatData data;

  const StompChat({required this.data});
}

class StompChatSending extends StompChat {
  final String receiver;
  var read = false;

  StompChatSending({required super.data, required this.receiver});
}

class StompChatReceived extends StompChat {
  final String sender;
  bool markedAsRead = false;

  StompChatReceived({required super.data, required this.sender});
}
