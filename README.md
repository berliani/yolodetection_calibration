# ObjectDetectionYOLO

Aplikasi mobile ini merupakan tahap 2 dari [object detection](https://github.com/berliani/ObjectDetectionYOLO) berbasis **Flutter** yang terintegrasi dengan model **AI YOLOv11** dan ditambahkan implementasi triangle similarity distance theory untuk deteksi multi-objek dengan mengetahui jarak aktual secara real-time.  
Repository ini dikembangkan untuk mendukung penelitian pengukuran jarak aktual objek terhadap kamera, dengan studi kasus:  
**Pengembangan aplikasi pendukung mobilitas bagi penyandang tunanetra.**

## 🚀 Fitur Utama

- 🔍 **Deteksi Real-Time Multi-Objek**  
  Mendeteksi berbagai objek secara langsung melalui kamera perangkat.

- 🧭 **Mode Navigasi**  
  Membantu pengguna mengenali objek di sekitar untuk mendukung mobilitas.

- 📌 **Mode Cari Objek Sekitar**  
  Fitur untuk mencari objek tertentu di lingkungan sekitar secara cepat.

- 🔎 **Mode Kalibrasi**  
  Fitur untuk digunakan di awal sebelum aplikasi digunakan untuk konfigurasi kamera dengan mengarahkan kertas hvs A4 dengan jarak 50cm dari kamera handphone.

## 🛠 Teknologi dan Library

- **Flutter**
- **YOLOv11** (model deteksi objek)
- **ultralytics_yolo** (plugin Flutter untuk integrasi YOLO)
- **GetX** (state management dan arsitektur modular)

## ⚙️ Instalasi dan Cara Menjalankan

1️⃣ Clone repository ini:
```bash
git clone https://github.com/berliani/yolodetection_calibration.git
cd yolodetection_calibration
```
2️⃣ Pastikan Anda sudah menginstal Flutter SDK dan dependencies:
```bash
flutter pub get
```
3️⃣ Jalankan aplikasi di emulator atau perangkat fisik:
```bash
flutter run
```

Untuk menyimpan hasil history deteksi bisa digabungkan dengan backend flask pada repository
```bash
https://github.com/berliani/yolodetection-backend
```
