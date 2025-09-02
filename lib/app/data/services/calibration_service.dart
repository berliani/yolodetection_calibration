import 'package:shared_preferences/shared_preferences.dart';

class CalibrationService {
  static const String _focalLengthKey = 'focalLength';
  
  Future<void> saveFocalLength(double focalLength) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_focalLengthKey, focalLength);
  }

  Future<double?> getFocalLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_focalLengthKey);
  }

  Future<bool> isCalibrated() async {
    return await getFocalLength() != null;
  }
}