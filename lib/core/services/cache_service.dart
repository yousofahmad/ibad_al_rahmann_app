import 'package:shared_preferences/shared_preferences.dart';

/// A reusable cache service built on top of SharedPreferences.
class CacheService {
  CacheService();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Initialize the cache service (call this before using it).
  Future<void> init() async {
    if (!_isInitialized) {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
    }
  }

  /// Ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// Save a string value
  Future<void> setString(String key, String value) async {
    await _ensureInitialized();
    await _prefs!.setString(key, value);
  }

  /// Get a string value
  Future<String?> getString(String key) async {
    await _ensureInitialized();
    return _prefs!.getString(key);
  }

  /// Save an integer value
  Future<void> setInt(String key, int value) async {
    await _ensureInitialized();
    await _prefs!.setInt(key, value);
  }

  /// Get an integer value
  int? getInt(String key) {
    if (!_isInitialized) return null;
    return _prefs!.getInt(key);
  }

  /// Save a boolean value
  Future<void> setBool(String key, bool value) async {
    await _ensureInitialized();
    await _prefs!.setBool(key, value);
  }

  /// Get a boolean value
  bool? getBool(String key) {
    if (!_isInitialized) return null;
    return _prefs!.getBool(key);
  }

  /// Save a double value
  Future<void> setDouble(String key, double value) async {
    await _ensureInitialized();
    await _prefs!.setDouble(key, value);
  }

  /// Get a double value
  double? getDouble(String key) {
    if (!_isInitialized) return null;
    return _prefs!.getDouble(key);
  }

  /// Save a list of strings
  Future<void> setStringList(String key, List<String> value) async {
    await _ensureInitialized();
    await _prefs!.setStringList(key, value);
  }

  /// Get a list of strings
  List<String>? getStringList(String key) {
    if (!_isInitialized) return null;
    return _prefs!.getStringList(key);
  }

  /// Remove a specific key
  Future<void> remove(String key) async {
    await _ensureInitialized();
    await _prefs!.remove(key);
  }

  /// Clear all cache
  Future<void> clear() async {
    await _ensureInitialized();
    await _prefs!.clear();
  }

  /// Check if a key exists
  bool contains(String key) {
    if (!_isInitialized) return false;
    return _prefs!.containsKey(key);
  }
}
