// app/modules/home/views/pre_calibration_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yolodetection/app/modules/calibration/views/calibration_view.dart';
import 'package:yolodetection/app/modules/home/controllers/home_controller.dart';

class PreCalibrationPage extends StatefulWidget {
  const PreCalibrationPage({Key? key}) : super(key: key);

  @override
  State<PreCalibrationPage> createState() => _PreCalibrationPageState();
}

class _PreCalibrationPageState extends State<PreCalibrationPage> {
  @override
  void initState() {
    super.initState();
    // Panggil TTS setelah frame pertama selesai di-render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final yoloController = Get.find<YoloController>();
      yoloController.speak(
        "Anda belum melakukan kalibrasi. Silahkan lakukan proses kalibrasi dengan menekan tombol Mulai Kalibrasi di layar Anda.",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selamat Datang'),
        automaticallyImplyLeading: false, // Sembunyikan tombol kembali
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_enhance, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Kalibrasi Diperlukan',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sebelum menggunakan aplikasi, Anda perlu melakukan kalibrasi kamera untuk akurasi pengukuran jarak yang lebih baik.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.compass_calibration),
                label: const Text('Mulai Kalibrasi'),
                onPressed: () {
                  // Navigasi ke halaman kalibrasi
                  Get.to(() => CalibrationPage());
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}