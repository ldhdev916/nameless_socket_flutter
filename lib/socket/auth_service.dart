import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
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

enum AuthServiceProvider {
  hypixel,
  mojang;

  Widget createSelectButton(Function(AuthServiceProvider) onSelect) {
    switch (this) {
      case hypixel:
        return ProviderIcon(
            icon: Image.asset("assets/hypixel.png"),
            text: "API Key",
            onTap: () => onSelect(this));
      case mojang:
        return ProviderIcon(
            icon: Image.asset("assets/minecraft.png"),
            text: "Mojang",
            onTap: () => onSelect(this));
      default:
        throw Error();
    }
  }

  Future<Widget> createWidget(
      ResponsiveScreen screen, Function(AuthService) onConnect) async {
    final storage = Get.find<FlutterSecureStorage>();
    switch (this) {
      case hypixel:
        final keyRegex = RegExp(
            "^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\$",
            caseSensitive: false);
        final editController =
            TextEditingController(text: await storage.read(key: _apiKey));

        return TextFormField(
            autovalidateMode: AutovalidateMode.always,
            validator: (s) => s != null && keyRegex.hasMatch(s)
                ? null
                : "Invalid API key format",
            controller: editController,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
                labelText: "Hypixel API Key",
                border: const OutlineInputBorder(),
                suffix: IconButton(
                    onPressed: () => onConnect(
                        HypixelAPIAuthService(key: editController.text)),
                    icon: const Icon(Icons.play_circle))));
      case mojang:
        final usernameController = TextEditingController(
            text: await storage.read(key: _mojangUsername));
        final passwordController = TextEditingController(
            text: await storage.read(key: _mojangPassword));
        final passwordVisible = false.obs;

        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: screen.height * 0.04,
          children: [
            TextField(
                keyboardType: TextInputType.emailAddress,
                controller: usernameController,
                style: const TextStyle(fontSize: 20),
                decoration: const InputDecoration(
                    labelText: "Mojang Username(Email)",
                    border: OutlineInputBorder())),
            Obx(() => TextField(
                obscureText: !passwordVisible.value,
                enableSuggestions: false,
                autocorrect: false,
                controller: passwordController,
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                    suffix: IconButton(
                        onPressed: () => passwordVisible.toggle(),
                        icon: Icon(passwordVisible.value
                            ? Icons.visibility
                            : Icons.visibility_off)),
                    labelText: "Mojang Password",
                    border: const OutlineInputBorder()))),
            TextButton(
                onPressed: () => onConnect(MojangAuthService(
                    username: usernameController.text,
                    password: passwordController.text)),
                child: const Text("Login", style: TextStyle(fontSize: 20)))
          ],
        );
      default:
        throw Error();
    }
  }

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
