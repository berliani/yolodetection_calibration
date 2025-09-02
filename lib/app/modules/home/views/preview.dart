// app/modules/home/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yolodetection/app/modules/calibration/controllers/calibration_controller.dart';
import 'package:yolodetection/app/modules/calibration/views/precalibration_view.dart';
import 'package:yolodetection/app/modules/home/controllers/home_controller.dart';
import 'package:yolodetection/app/modules/home/views/home_view.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Inisialisasi controller di sini agar bisa diakses di seluruh aplikasi
    final CalibrationController calController = Get.put(CalibrationController());
    Get.put(YoloController()); // Pastikan YoloController juga diinisialisasi untuk TTS

    return Scaffold(
      body: FutureBuilder(
        // Gunakan future dari checkCalibrationStatus untuk menunggu pengecekan selesai
        future: calController.checkCalibrationStatus(),
        builder: (context, snapshot) {
          // Tampilkan loading indicator selama proses pengecekan
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          // Setelah pengecekan selesai, navigasi berdasarkan hasilnya.
          // Menggunakan `addPostFrameCallback` untuk memastikan proses build selesai
          // sebelum melakukan navigasi untuk menghindari error.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (calController.isCalibrated.value) {
              // Jika sudah dikalibrasi, langsung ke halaman utama (YoloPage)
              Get.offAll(() => const YoloPage());
            } else {
              // Jika belum, arahkan ke halaman Pre-Kalibrasi
              Get.offAll(() => const PreCalibrationPage());
            }
          });

          // Tampilkan loading indicator selama proses navigasi dipersiapkan
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}