import 'package:device_info_plus/device_info_plus.dart';

class DeviceHelper {
  static Future<bool> isXiaomiDevice() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    
    // Verificar si es un dispositivo Xiaomi/Redmi/POCO
    String manufacturer = androidInfo.manufacturer.toLowerCase();
    return manufacturer.contains('xiaomi') || 
           manufacturer.contains('redmi') || 
           manufacturer.contains('poco');
  }
}