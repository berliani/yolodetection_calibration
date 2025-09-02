// app/modules/calibration/views/calibration_view.dart (Updated)

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:yolodetection/app/modules/calibration/controllers/calibration_controller.dart';
import 'package:yolodetection/app/modules/home/controllers/home_controller.dart';

// --- PERUBAHAN 1: Ubah menjadi StatefulWidget ---
class CalibrationPage extends StatefulWidget {
  const CalibrationPage({super.key});

  @override
  State<CalibrationPage> createState() => _CalibrationPageState();
}

class _CalibrationPageState extends State<CalibrationPage> {
  final CalibrationController calController = Get.find();
  final YoloController yoloController = Get.find();

  // --- PERUBAHAN 2: Tambahkan initState untuk memanggil TTS ---
  @override
  void initState() {
    super.initState();
    // Panggil TTS setelah frame pertama selesai di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      yoloController.speak(
          "Anda sedang melakukan proses kalibrasi. Arahkan kamera ke kertas A4 pada jarak 50 sentimeter.");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalibrasi Kamera')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Latar Belakang: Tampilkan kamera
          YOLOView(
            controller: yoloController.yoloViewController,
            modelPath: 'yolo11n',
            task: YOLOTask.detect,
            onResult: (results) {
              if (results.isEmpty || calController.isCalibrating.value) {
                return;
              }
              final YOLOResult firstResult = results.first;
              final double imageHeight = firstResult.boundingBox.height /
                  firstResult.normalizedBox.height;
              for (var result in results) {
                final String className = result.className.toLowerCase();
                if (className == 'book' || className == 'paper') {
                  calController.calibrateFromLiveDetection(result, imageHeight);
                  break;
                }
              }
            },
          ),
          // Lapisan Atas: Instruksi
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Obx(() => Text(
                    calController.isCalibrating.value
                        ? calController.calibrationStatus.value
                        : 'Arahkan kamera ke kertas A4 pada jarak 50 cm',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  )),
            ),
          ),
        ],
      ),
    );
  }
}