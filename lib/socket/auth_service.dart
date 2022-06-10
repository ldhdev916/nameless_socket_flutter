import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:nameless_socket_flutter/socket/loading.dart';
import 'package:uuid/uuid.dart';

const _apiKey = "api_key";
const _mojangUsername = "mojang_username";
const _mojangPassword = "mojang_password";

class ProviderIcon extends StatelessWidget {
  final Widget icon;
  final String text;
  final GestureTapCallback onTap;

  const ProviderIcon(
      {Key? key, required this.icon, required this.text, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipOval(
        child: Material(
            child: InkWell(
                onTap: onTap,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(flex: 6, child: icon),
                      Flexible(flex: 3, child: Text(text))
                    ]))));
  }
}

class ProviderSelectButton extends StatelessWidget {
  final void Function(AuthServiceProvider) onSelect;
  final AuthServiceProvider provider;

  const ProviderSelectButton(
      {Key? key, required this.provider, required this.onSelect})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (provider) {
      case AuthServiceProvider.hypixel:
        return ProviderIcon(
            icon: Image.asset("assets/hypixel.png"),
            text: "API Key",
            onTap: () => onSelect(AuthServiceProvider.hypixel));
      case AuthServiceProvider.mojang:
        return ProviderIcon(
            icon: Image.asset("assets/minecraft.png"),
            text: "Mojang",
            onTap: () => onSelect(AuthServiceProvider.mojang));
    }
  }
}

class AuthenticationController extends GetxController {
  final storage = Get.find<FlutterSecureStorage>();
  final keyController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final keyRegex = RegExp(
      "^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\$",
      caseSensitive: false);
  final passwordVisible = false.obs;
}

class AuthenticationWidget extends GetResponsiveView<AuthenticationController> {
  final AuthServiceProvider provider;
  final void Function(AuthService) onConnect;

  AuthenticationWidget(
      {Key? key, required this.provider, required this.onConnect})
      : super(key: key);

  Widget _completedWidget() {
    switch (provider) {
      case AuthServiceProvider.hypixel:
        return TextFormField(
            autovalidateMode: AutovalidateMode.always,
            validator: (s) => s != null && controller.keyRegex.hasMatch(s)
                ? null
                : "Invalid API key format",
            controller: controller.keyController,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
                labelText: "Hypixel API Key",
                border: const OutlineInputBorder(),
                suffix: IconButton(
                    onPressed: () => onConnect(HypixelAPIAuthService(
                        key: controller.keyController.text)),
                    icon: const Icon(Icons.play_circle))));
      case AuthServiceProvider.mojang:
        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: screen.height * 0.04,
          children: [
            TextField(
                keyboardType: TextInputType.emailAddress,
                controller: controller.usernameController,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                    labelText: "Mojang Username(Email)",
                    border: OutlineInputBorder())),
            Obx(() => TextField(
                obscureText: !controller.passwordVisible.value,
                enableSuggestions: false,
                autocorrect: false,
                controller: controller.passwordController,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                    suffix: IconButton(
                        onPressed: () => controller.passwordVisible.toggle(),
                        icon: Icon(controller.passwordVisible.value
                            ? Icons.visibility
                            : Icons.visibility_off)),
                    labelText: "Mojang Password",
                    border: const OutlineInputBorder()))),
            TextButton(
                onPressed: () => onConnect(MojangAuthService(
                    username: controller.usernameController.text,
                    password: controller.passwordController.text)),
                child: const Text("Login", style: TextStyle(fontSize: 20)))
          ],
        );
    }
  }

  Future<void> _initController(
      TextEditingController editController, String key) async {
    final value = await controller.storage.read(key: key);
    if (value != null) editController.text = value;
  }

  @override
  Widget? builder() {
    return FutureBuilder(
        future: Future.wait([
          _initController(controller.keyController, _apiKey),
          _initController(controller.usernameController, _mojangUsername),
          _initController(controller.passwordController, _mojangPassword)
        ]),
        builder: (_, snapshot) =>
            snapshot.hasData ? _completedWidget() : LoadingCircle());
  }
}

enum AuthServiceProvider {
  hypixel,
  mojang;

  static AuthServiceProvider valueOf(String name) =>
      values.firstWhere((element) => element.name == name);
}

abstract class AuthService {
  const AuthService();

  Future<String?> authenticate();
}

class HypixelAPIAuthService extends AuthService {
  final String key;

  const HypixelAPIAuthService({required this.key});

  @override
  Future<String?> authenticate() async {
    final response =
        await http.get(Uri.parse("https://api.hypixel.net/key?key=$key"));
    if (response.statusCode != 200) return null;
    final Map<String, dynamic> body = jsonDecode(response.body);
    if (!body["success"]) return null;
    Get.find<FlutterSecureStorage>().write(key: _apiKey, value: key);
    return body["record"]["owner"];
  }
}

class MojangAuthService extends AuthService {
  final String username;
  final String password;

  const MojangAuthService({required this.username, required this.password});

  @override
  Future<String?> authenticate() async {
    final clientToken = const Uuid().v4();
    final body = {
      "agent": {"name": "Minecraft", "version": 1},
      "username": username,
      "password": password,
      "clientToken": clientToken
    };

    final response = await http.post(
        Uri.parse("https://authserver.mojang.com/authenticate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body));
    if (response.statusCode != 200) return null;
    final responseBody = jsonDecode(response.body);
    final uuid = responseBody["selectedProfile"]["id"];
    final accessToken = responseBody["accessToken"];
    // Don't worry I'm not stealing your access token this is just for invalidating after authentication

    await http.post(Uri.parse("https://authserver.mojang.com/invalidate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(
            {"accessToken": accessToken, "clientToken": clientToken}));
    final storage = Get.find<FlutterSecureStorage>();
    storage.write(key: _mojangUsername, value: username);
    storage.write(key: _mojangPassword, value: password);
    return uuid;
  }
}
