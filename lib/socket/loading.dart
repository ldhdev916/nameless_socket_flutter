import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoadingCircle extends GetResponsiveView {
  final Size? size;

  LoadingCircle({Key? key, this.size}) : super(key: key);

  @override
  Widget? builder() {
    return Container(
        color: Colors.white,
        child: Center(
            child: SizedBox.fromSize(
                size: size ?? Size.square(screen.width * 0.3),
                child: const CircularProgressIndicator())));
  }
}
