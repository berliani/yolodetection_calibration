import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:ultralytics_yolo/yolo_task.dart';
import 'package:yolodetection/app/modules/calibration/controllers/calibration_controller.dart';
import 'package:yolodetection/app/modules/calibration/views/calibration_view.dart';
import 'package:yolodetection/app/utils/ObjectHeights.dart';
// import 'package:yolodetection/app/modules/home/views/home_view.dart';
import 'package:yolodetection/app/utils/indonesianLabels.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

enum DetectionMode { navigation, search }

class PositionHelper {
  static String getHorizontalCategory(double xCenter) {
    if (xCenter < 0.33) return "KIRI";
    if (xCenter > 0.66) return "KANAN";
    return "DEPAN";
  }

  static String getVerticalCategory(double yCenter) {
    if (yCenter < 0.33) return "ATAS";
    if (yCenter > 0.66) return "BAWAH";
    return "DEPAN";
  }

  static String getCombinedPosition(double xCenter, double yCenter) {
    final horizontal = getHorizontalCategory(xCenter);
    final vertical = getVerticalCategory(yCenter);

    if (horizontal == "DEPAN" && vertical == "DEPAN") return "DEPAN";
    if (horizontal == "DEPAN") return vertical;
    if (vertical == "DEPAN") return horizontal;
    return "$vertical-$horizontal"; // Lebih alami sebut atas/bawah dulu
  }

  static String formatForSpeech(String position) {
    return position.replaceAll('-', ' ').toLowerCase();
  }

  static String formatForDisplay(String position) {
    return position.toLowerCase().replaceAll('DEPAN', 'depan');
  }
}

class YoloController extends GetxController {
  final YOLOViewController yoloViewController = YOLOViewController();
  final FlutterTts flutterTts = FlutterTts();
  final RxDouble confidenceThreshold = 0.5.obs;
  final RxDouble iouThreshold = 0.45.obs;
  final RxDouble zoomLevel = 1.0.obs;
  final RxString currentModel = 'yolo11n'.obs;
  final Rx<YOLOTask> currentTask = YOLOTask.detect.obs;
  final RxList<YOLOResult> lastResults = <YOLOResult>[].obs;
  final RxBool _isSpeaking = false.obs;
  final RxString selectedClass = ''.obs;
  final Rx<DetectionMode> currentMode = DetectionMode.navigation.obs;
  final Map<String, String> _lastSpokenPositions = {};

  // Rx Variables untuk lokasi
  final RxString currentAddress = 'Mencari lokasi...'.obs;
  final RxDouble latitude = 0.0.obs;
  final RxDouble longitude = 0.0.obs;

  // Variabel kontrol alur
  final RxBool _initialSetupCompleted = false.obs;
  Completer<void>? _speechCompleter;

  final CalibrationController calController = Get.put(CalibrationController());
  final RxBool showDistance = false.obs;

  // Metode untuk memulai kalibrasi
  void startCalibration() {
    Get.to(() => CalibrationPage());
  }

  // Hitung jarak berdasarkan hasil deteksi
  double? calculateDistance(YOLOResult result) {
    if (!calController.isCalibrated.value) return null;

    final className = result.className;
    final realHeight = KNOWN_OBJECT_HEIGHTS[className];

    if (realHeight == null) return null;

    final focalLength = calController.focalLength.value;

    // Langsung gunakan tinggi bounding box dalam piksel
    double heightPx = result.boundingBox.height;

    if (heightPx <= 0) return null;

    // Rumus estimasi jarak
    return (focalLength * realHeight) / heightPx;
  }

  // --- PERUBAHAN 1: Sederhanakan pengucapan jarak di bawah 1 meter ---
  String _formatDistanceForSpeech(double? distanceInCm) {
    if (distanceInCm == null) return "";

    if (distanceInCm < 100) {
      return "berjarak kurang dari 1 meter"; // Diubah dari cm spesifik
    } else {
      double distanceInMeters = distanceInCm / 100;
      return "berjarak sekitar ${distanceInMeters.toStringAsFixed(1)} meter";
    }
  }

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _detectionTimer;
  Timer? _noObjectFoundTimer;
  Timer? _navigationSummaryTimer;
  final RxMap<String, Map<String, List<double?>>> _objectSummary =
      <String, Map<String, List<double?>>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeTTS();

    // Konfigurasi YOLO
    yoloViewController.setThresholds(
      confidenceThreshold: confidenceThreshold.value,
      iouThreshold: iouThreshold.value,
    );
    yoloViewController.setZoomLevel(zoomLevel.value);
    yoloViewController.switchModel(currentModel.value, currentTask.value);

    // Memulai pembaruan lokasi
    _startLocationUpdates();
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    if (_isSpeaking.value) {
      await flutterTts.stop();
      _speechCompleter?.complete();
      _isSpeaking.value = false;
    }

    _speechCompleter = Completer<void>();
    _isSpeaking.value = true;
    await flutterTts.speak(text);
    Future.delayed(const Duration(seconds: 20), () {
      if (!_speechCompleter!.isCompleted) {
        _isSpeaking.value = false;
        _speechCompleter!.complete();
      }
    });
    return _speechCompleter!.future;
  }

  void _initializeTTS() async {
    await flutterTts.setLanguage("id-ID");
    await flutterTts.setSpeechRate(0.35);
    await flutterTts.setPitch(1.0);

    flutterTts.setCompletionHandler(() {
      _isSpeaking.value = false;
      _speechCompleter?.complete();
    });
  }

  Future<void> _performInitialAnnouncements() async {
    // 1. Umumkan lokasi
    final String initialText =
        "Sekarang Anda ada di ${currentAddress.value}. Anda berada di mode navigasi.";
    await speak(initialText);

    // Setelah pengumuman awal selesai, langsung coba umumkan objek yang sudah ada
    // tanpa menunggu timer 4 detik.
    if (!_isSpeaking.value && _objectSummary.isNotEmpty) {
      await _announceNavigationSummary();
    }

    // Baru mulai timer untuk ringkasan berikutnya
    _startNavigationSummaryTimer();
  }

  // --- PERUBAHAN 2: BUAT TIMER LEBIH RESPONSIF ---
  void _startNavigationSummaryTimer() {
    _navigationSummaryTimer?.cancel();
    // Periode timer bisa sedikit dikurangi agar lebih sering memberi update
    _navigationSummaryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isSpeaking.value && _objectSummary.isNotEmpty) {
        _announceNavigationSummary();
      }
    });
  }

  Future<void> _announceNavigationSummary() async {
    if (_objectSummary.isEmpty) return;

    final List<String> summaries = [];
    _objectSummary.forEach((className, positions) {
      final label = getIndonesianLabel(className);
      positions.forEach((position, distances) {
        final posText = PositionHelper.formatForSpeech(position);
        final count = distances.length;

        // Cari jarak terdekat (abaikan nilai null)
        final validDistances = distances.whereType<double>().toList();
        double? minDistance;
        if (validDistances.isNotEmpty) {
          minDistance = validDistances.reduce((a, b) => a < b ? a : b);
        }

        String summaryText = "$count $label di $posText";
        if (minDistance != null) {
          // Gunakan helper function yang baru dibuat
          summaryText += ", yang ${_formatDistanceForSpeech(minDistance)}";
        }
        summaries.add(summaryText);
      });
    });

    if (summaries.isNotEmpty) {
      final text = "Di sekitar Anda terdapat: ${summaries.join('. ')}";
      await speak(text);
      _objectSummary.clear();
    }
  }

  void startDetectionInterval() {
    if (_detectionTimer?.isActive ?? false) return;

    _detectionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      detectAndAnnounce();
    });
  }

  void stopDetectionInterval() {
    _detectionTimer?.cancel();
  }

  Future<void> detectAndAnnounce() async {
    if (_isSpeaking.value) return;

    if (currentMode.value == DetectionMode.search && selectedClass.isNotEmpty) {
      if (lastResults.isEmpty) {
        _startNoObjectFoundTimer();
        return;
      }
      final resultsToAnnounce = lastResults
          .where((r) => r.className == selectedClass.value)
          .toList();

      if (resultsToAnnounce.isEmpty) {
        _startNoObjectFoundTimer();
        return;
      } else {
        _cancelNoObjectFoundTimer();
      }
      resultsToAnnounce.sort(
        (a, b) => (a.distance ?? double.infinity).compareTo(
          b.distance ?? double.infinity,
        ),
      );
      final topResult = resultsToAnnounce.first;
      final label = getIndonesianLabel(topResult.className);
      final xCenter =
          topResult.normalizedBox.left + (topResult.normalizedBox.width / 2);
      final yCenter =
          topResult.normalizedBox.top + (topResult.normalizedBox.height / 2);
      final rawPosition = PositionHelper.getCombinedPosition(xCenter, yCenter);
      final formattedPosition = PositionHelper.formatForSpeech(rawPosition);

      // --- PERUBAHAN 2: Gunakan fungsi yang sudah diperbarui ---
      // Blok if/else yang panjang untuk jarak diganti dengan satu baris ini
      final String distanceText = _formatDistanceForSpeech(topResult.distance);

      final speechKey = "${topResult.className}-${formattedPosition}";
      if (_lastSpokenPositions.containsKey(speechKey) &&
          _lastSpokenPositions[speechKey] == distanceText) {
        return;
      }
      _lastSpokenPositions[speechKey] = distanceText;

      final text = "$label ada di $formattedPosition, $distanceText";
      await speak(text);
    }
  }

  void _startNoObjectFoundTimer() {
    if (_noObjectFoundTimer?.isActive ?? false) return;

    _noObjectFoundTimer = Timer(const Duration(seconds: 2), () async {
      final label = getIndonesianLabel(selectedClass.value);
      await speak("Tidak ada $label di sekitar Anda.");
    });
  }

  void _cancelNoObjectFoundTimer() {
    _noObjectFoundTimer?.cancel();
  }

  void setMode(DetectionMode mode) async {
    currentMode.value = mode;
    _lastSpokenPositions.clear();
    _objectSummary.clear();

    if (mode == DetectionMode.navigation) {
      resetSelection();
      _cancelNoObjectFoundTimer();
      _startNavigationSummaryTimer();
      await speak("Anda berada di mode navigasi");
    } else {
      _navigationSummaryTimer?.cancel();
      speak("Anda berada di mode cari");
    }
  }

  void setSelectedClass(String className) async {
    selectedClass.value = className;
    currentMode.value = DetectionMode.search;

    final indonesianLabel = getIndonesianLabel(className);
    await speak("Anda mencari $indonesianLabel");

    startDetectionInterval();
  }

  Future<void> _getAddressFromLatLng(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        currentAddress.value =
            "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}";
      } else {
        currentAddress.value = 'Tidak dapat menemukan nama lokasi.';
      }

      if (!_initialSetupCompleted.value &&
          !currentAddress.value.startsWith('Mencari')) {
        _initialSetupCompleted.value = true;
        _performInitialAnnouncements();
      }
    } catch (e) {
      currentAddress.value = 'Gagal mendapatkan nama lokasi.';
      print('Error geocoding: $e');
    }
  }

  @override
  void onClose() {
    stopDetectionInterval();
    _navigationSummaryTimer?.cancel();
    flutterTts.stop();
    _isSpeaking.value = false;
    _lastSpokenPositions.clear();
    _positionStreamSubscription?.cancel();
    _noObjectFoundTimer?.cancel();
    super.onClose();
  }

  String getIndonesianLabel(String className) {
    final lowerClassName = className.toLowerCase();
    for (var entry in indonesianLabels.entries) {
      if (entry.key.toLowerCase() == lowerClassName) {
        return entry.value;
      }
    }
    return className;
  }

  void updateConfidence(double value) {
    confidenceThreshold.value = value;
    yoloViewController.setConfidenceThreshold(value);
    update();
  }

  void flipCamera() {
    yoloViewController.switchCamera();
  }

  void resetSelection() {
    selectedClass.value = '';
  }

  void onResult(List<YOLOResult> results, double imagePixelHeight) {
    List<YOLOResult> filteredResults = results.where((r) {
      return r.confidence >= confidenceThreshold.value;
    }).toList();

    for (var result in filteredResults) {
      // Pemanggilan menjadi lebih sederhana
      result.distance = calculateDistance(result);
    }

    lastResults.value = filteredResults;

    if (currentMode.value == DetectionMode.navigation) {
      final Map<String, Map<String, List<double?>>> currentSummary = {};
      for (var result in filteredResults) {
        final className = result.className;
        final xCenter =
            result.normalizedBox.left + (result.normalizedBox.width / 2);
        final yCenter =
            result.normalizedBox.top + (result.normalizedBox.height / 2);
        final position = PositionHelper.getCombinedPosition(xCenter, yCenter);

        currentSummary[className] ??= {};
        currentSummary[className]![position] ??= [];
        currentSummary[className]![position]!.add(
          result.distance,
        ); // Simpan jaraknya
      }
      _objectSummary.value = currentSummary;
    }
  }

  void clearResult() {
    lastResults.clear();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      currentAddress.value = 'Layanan lokasi dinonaktifkan.';
      return Future.error('Layanan lokasi dinonaktifkan.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        currentAddress.value = 'Izin lokasi ditolak.';
        return Future.error('Izin lokasi ditolak');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      currentAddress.value = 'Izin lokasi ditolak secara permanen.';
      return Future.error(
        'Izin lokasi ditolak secara permanen, kami tidak dapat meminta izin.',
      );
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (Position position) {
            latitude.value = position.latitude;
            longitude.value = position.longitude;
            _getAddressFromLatLng(position.latitude, position.longitude);
          },
          onError: (e) {
            currentAddress.value = 'Gagal mendapatkan lokasi: $e';
          },
        );
  }
}
