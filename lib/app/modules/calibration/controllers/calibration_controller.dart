// app/modules/calibration/controllers/calibration_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:yolodetection/app/data/services/calibration_service.dart';
import 'package:yolodetection/app/modules/home/controllers/home_controller.dart'; // Import YoloController
import 'package:yolodetection/app/modules/home/views/home_view.dart';

class CalibrationController extends GetxController {
  final CalibrationService calibrationService = CalibrationService();
  final RxDouble focalLength = 0.0.obs;
  final RxBool isCalibrating = false.obs;
  final RxBool isCalibrated = false.obs;
  final RxString calibrationStatus = 'Belum dikalibrasi'.obs;

  @override
  void onInit() {
    super.onInit();
    checkCalibrationStatus();
  }

  Future<void> checkCalibrationStatus() async {
    final savedFocalLength = await calibrationService.getFocalLength();
    if (savedFocalLength != null) {
      focalLength.value = savedFocalLength;
      isCalibrated.value = true;
      calibrationStatus.value =
          'Terkalibrasi (f = ${focalLength.value.toStringAsFixed(2)} px)';
    }
  }

  Future<void> calibrateFromLiveDetection(
    YOLOResult result,
    double imagePixelHeight,
  ) async {
    if (isCalibrating.value) return;

    isCalibrating.value = true;
    calibrationStatus.value = 'Objek terdeteksi, memproses kalibrasi...';

    try {
      const double realHeightCm = 29.7; // Tinggi asli kertas A4
      const double distanceToObjectCm = 50.0; // Jarak yang ditentukan
      final double hPx = result.normalizedBox.height * imagePixelHeight;

      if (hPx > 0) {
        final double calculatedFocalLength =
            (hPx * distanceToObjectCm) / realHeightCm;

        focalLength.value = calculatedFocalLength;
        await calibrationService.saveFocalLength(calculatedFocalLength);
        isCalibrated.value = true;
        calibrationStatus.value = 'Kalibrasi Berhasil!';

        // Dapatkan instance YoloController untuk menggunakan TTS
        final yoloController = Get.find<YoloController>();

        Get.snackbar(
          'Sukses',
          'Focal Length: ${calculatedFocalLength.toStringAsFixed(2)} px. Kalibrasi berhasil disimpan.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Ucapkan pesan sukses dan tunggu hingga selesai
        await yoloController.speak("Anda sudah berhasil melakukan proses kalibrasi.");

        // Navigasi ke halaman utama SETELAH TTS selesai
        Get.offAll(() => const YoloPage());
        
      } else {
        throw Exception("Tinggi objek terdeteksi nol.");
      }
    } catch (e) {
      isCalibrating.value = false;
      final errorMessage = 'Gagal memproses kalibrasi: $e';
      calibrationStatus.value = errorMessage;
      Get.snackbar('Error', errorMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }
}