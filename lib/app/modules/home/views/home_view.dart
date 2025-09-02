import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:yolodetection/app/modules/calibration/views/calibration_view.dart';
import 'package:yolodetection/app/modules/home/controllers/home_controller.dart';
import 'package:yolodetection/app/modules/home/views/object_selection_view.dart';

class PositionHelper {
  static String getHorizontalCategory(double xCenter) {
    if (xCenter < 0.33) return "KIRI";
    if (xCenter > 0.66) return "KANAN";
    return "TENGAH";
  }

  static String getVerticalCategory(double yCenter) {
    if (yCenter < 0.33) return "ATAS";
    if (yCenter > 0.66) return "BAWAH";
    return "TENGAH";
  }

  static String getCombinedPosition(double xCenter, double yCenter) {
    final horizontal = getHorizontalCategory(xCenter);
    final vertical = getVerticalCategory(yCenter);
    return "$horizontal-$vertical";
  }

  static String getFormattedPosition(String position) {
    final parts = position.split('-');
    return parts.length == 2 ? "${parts[0]} - ${parts[1]}" : position;
  }
}

class YoloPage extends StatefulWidget {
  const YoloPage({Key? key}) : super(key: key);

  @override
  State<YoloPage> createState() => _YoloPageState();
}

class _YoloPageState extends State<YoloPage> {
  final YoloController controller = Get.put(YoloController());
  final GlobalKey _previewContainerKey = GlobalKey();

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary? boundary =
          _previewContainerKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[CAPTURE ERROR] $e');
      return null;
    }
  }

  Future<void> _sendDetectionToServer(
    List<YOLOResult> results,
    Uint8List imageBytes,
  ) async {
    const String url = 'http://192.168.57.168:5000/upload_detection';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));

      final List<Map<String, dynamic>> jsonResults = results.map((r) {
        double xCenter = r.normalizedBox.left + (r.normalizedBox.width / 2);
        double yCenter = r.normalizedBox.top + (r.normalizedBox.height / 2);
        String position = PositionHelper.getCombinedPosition(xCenter, yCenter);

        return {
          'classIndex': r.classIndex,
          'className': r.className,
          'confidence': r.confidence,
          'boundingBox': {
            'x': r.boundingBox.left,
            'y': r.boundingBox.top,
            'width': r.boundingBox.width,
            'height': r.boundingBox.height,
          },
          'normalizedBox': {
            'x': r.normalizedBox.left,
            'y': r.normalizedBox.top,
            'width': r.normalizedBox.width,
            'height': r.normalizedBox.height,
            'centerX': xCenter,
            'centerY': yCenter,
          },
          'position': position,
        };
      }).toList();

      request.fields['detections'] = jsonEncode(jsonResults);
      request.fields['selected_class'] = controller.selectedClass.value;
      request.fields['latitude'] = controller.latitude.value.toString();
      request.fields['longitude'] = controller.longitude.value.toString();
      request.fields['location_address'] = controller.currentAddress.value;

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'capture_${DateTime.now().millisecondsSinceEpoch}.png',
          contentType: MediaType('image', 'png'),
        ),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        debugPrint('[UPLOAD] Sukses upload hasil deteksi');
      } else {
        debugPrint('[UPLOAD] Gagal: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[UPLOAD EXCEPTION] $e');
    }
  }

  Widget _buildPositionInfo() {
    return Obx(() {
      if (controller.currentMode.value == DetectionMode.search &&
          controller.selectedClass.value.isNotEmpty) {
        final targetObjects = controller.lastResults
            .where((r) => r.className == controller.selectedClass.value)
            .toList();

        if (targetObjects.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              "Objek tidak ditemukan",
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: controller.lastResults.length,
            itemBuilder: (context, index) {
              final result = controller.lastResults[index];
              double xCenter =
                  result.normalizedBox.left + (result.normalizedBox.width / 2);
              double yCenter =
                  result.normalizedBox.top + (result.normalizedBox.height / 2);
              String position = PositionHelper.getFormattedPosition(
                PositionHelper.getCombinedPosition(xCenter, yCenter),
              );
              String label = controller.getIndonesianLabel(result.className);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(position),
                      // TAMBAHKAN TAMPILAN JARAK DI SINI
                      if (result.distance != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            result.distance! < 100
                                ? '${result.distance!.toStringAsFixed(0)} cm'
                                : '${(result.distance! / 100).toStringAsFixed(1)} m',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      } else {
        if (controller.lastResults.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text("Memindai objek...", style: TextStyle(fontSize: 20)),
          );
        }

        // Kelompokkan hasil berdasarkan labelnya
        Map<String, List<YOLOResult>> groupedResults = {};
        for (var result in controller.lastResults) {
          String indonesianLabel = controller.getIndonesianLabel(
            result.className,
          );
          groupedResults.putIfAbsent(indonesianLabel, () => []).add(result);
        }

        return SizedBox(
          height: 120, // Tambah tinggi untuk menampung info jarak
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: groupedResults.length,
            itemBuilder: (context, index) {
              final entry = groupedResults.entries.elementAt(index);
              final String label = entry.key;
              final List<YOLOResult> resultsForLabel = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$label (${resultsForLabel.length})",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: resultsForLabel.map((result) {
                              double xCenter =
                                  result.normalizedBox.left +
                                  (result.normalizedBox.width / 2);
                              double yCenter =
                                  result.normalizedBox.top +
                                  (result.normalizedBox.height / 2);
                              String position =
                                  PositionHelper.getFormattedPosition(
                                    PositionHelper.getCombinedPosition(
                                      xCenter,
                                      yCenter,
                                    ),
                                  );

                              String distanceText = "N/A";
                              if (result.distance != null) {
                                distanceText = result.distance! < 100
                                    ? '${result.distance!.toStringAsFixed(0)} cm'
                                    : '${(result.distance! / 100).toStringAsFixed(1)} m';
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text("$position - $distanceText"),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.currentMode.value == DetectionMode.search
                ? 'Mencari: ${controller.getIndonesianLabel(controller.selectedClass.value)}'
                : 'Deteksi Kamera',
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Obx(
              () => Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lokasi Anda: ${controller.currentAddress.value}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RepaintBoundary(
              key: _previewContainerKey,
              child: YOLOView(
                controller: controller.yoloViewController,
                modelPath: 'yolo11n',
                task: YOLOTask.detect,
                onResult: (results) async {
                  try {
                    if (results.isEmpty) {
                      controller.clearResult();
                      return;
                    }

                    // AMBIL HASIL PERTAMA UNTUK MENGHITUNG TINGGI GAMBAR
                    final YOLOResult firstResult = results.first;
                    final double imageHeight =
                        firstResult.boundingBox.height /
                        firstResult.normalizedBox.height;

                    // Saring hasil berdasarkan confidence, dll.
                    final filteredResults = results.where((r) {
                      return r.confidence >=
                              controller.confidenceThreshold.value &&
                          (controller.currentMode.value ==
                                  DetectionMode.navigation ||
                              r.className == controller.selectedClass.value);
                    }).toList();

                    // Kirim hasil filter dan tinggi gambar yang sudah dihitung
                    controller.onResult(filteredResults, imageHeight);

                    if (filteredResults.isNotEmpty) {
                      final pngBytes = await _capturePng();
                      if (pngBytes != null) {
                        await _sendDetectionToServer(filteredResults, pngBytes);
                      }
                    }
                  } catch (e) {
                    debugPrint('[RESULT ERROR] $e');
                  }
                },
              ),
            ),
          ),
          _buildPositionInfo(),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                icon: Icons.navigation,
                label: 'Navigasi',
                isSelected:
                    controller.currentMode.value == DetectionMode.navigation,
                onTap: () => controller.setMode(DetectionMode.navigation),
              ),
              _buildNavItem(
                icon: Icons.search,
                label: 'Cari',
                isSelected:
                    controller.currentMode.value == DetectionMode.search,
                onTap: () {
                  controller.setMode(DetectionMode.search);
                  Get.to(() => ObjectSelectionPage());
                },
              ),
              _buildNavItem(
                icon: Icons.compass_calibration,
                label: 'Kalibrasi',
                isSelected: false,
                onTap: () => Get.to(() => CalibrationPage()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? Colors.blueAccent : Colors.black,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                color: isSelected ? Colors.blueAccent : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
