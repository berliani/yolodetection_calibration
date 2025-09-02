import 'package:get/get.dart';

import '../modules/calibration/bindings/calibration_binding.dart';
import '../modules/calibration/views/calibration_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(name: _Paths.HOME, page: () => YoloPage(), binding: HomeBinding()),
    GetPage(
      name: _Paths.CALIBRATION,
      page: () =>  CalibrationPage(),
      binding: CalibrationBinding(),
    ),
  ];
}
