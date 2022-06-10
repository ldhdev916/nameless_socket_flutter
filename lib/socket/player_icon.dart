import 'package:flutter/material.dart';

Image getPlayerIcon({required String name}) =>
    Image.network("https://mc-heads.net/avatar/$name");
