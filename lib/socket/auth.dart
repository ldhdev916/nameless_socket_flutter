import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:nameless_socket_flutter/socket/auth_service.dart';
import 'package:nameless_socket_flutter/socket/loading.dart';
import 'package:sizer/sizer.dart';

import 'socket.dart';

class AuthHome extends GetResponsiveView<StompController> {
  AuthHome({Key? key}) : super(key: key);

  final _storage = Get.find<FlutterSecureStorage>();
  final _providerKey = "auth_provider";
  final _provider = Rxn<AuthServiceProvider>();

  @override
  Widget? builder() {
    Get.put(AuthenticationController());
    _storage.read(key: _providerKey).then((value) => _provider(
        AuthServiceProvider.valueOf(
            value ?? AuthServiceProvider.hypixel.name)));

    return Obx(() {
      final provider = _provider.value;
      if (provider == null) {
        return LoadingCircle();
      } else {
        return Scaffold(
            appBar: AppBar(
                title: const Text("Nameless Authentication"),
                centerTitle: true),
            body: Center(
                child: SingleChildScrollView(
                    child: Padding(
                        padding: EdgeInsets.all(4.h),
                        child: Column(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: AuthServiceProvider.values
                                .map((e) => SizedBox.fromSize(
                                    size: Size.square(12.h),
                                    child: ProviderSelectButton(
                                        provider: e,
                                        onSelect: (element) {
                                          _provider(element);
                                          _storage.write(
                                              key: _providerKey,
                                              value: element.name);
                                        })))
                                .toList(),
                          ),
                          SizedBox(height: screen.height * 0.08),
                          AuthenticationWidget(
                              provider: provider,
                              onConnect: (element) async {
                                final connected =
                                    await controller.connect(service: element);
                                if (connected) {
                                  Get.offAllNamed("/");
                                } else {
                                  Get.snackbar("Authentication Failed",
                                      "Please check your auth information again");
                                }
                              })
                        ])))));
      }
    });
  }
}
