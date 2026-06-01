import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  String? _id;
  String get id {
    final v = _id;
    if (v == null) throw StateError('DeviceIdService.init() not called');
    return v;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'flutter.device_id'; // NOT db-prefixed — same device across all accounts
    var v = prefs.getString(key);
    if (v == null || v.isEmpty) {
      v = const Uuid().v4();
      await prefs.setString(key, v);
    }
    _id = v;
  }
}
