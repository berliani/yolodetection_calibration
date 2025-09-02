// main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yolodetection/app/modules/home/views/preview.dart';
void main() {
  runApp(
    GetMaterialApp(
      title: "YOLO Detection",
      // Jadikan HomePage sebagai halaman awal
      home: HomePage(),
    ),
  );
}