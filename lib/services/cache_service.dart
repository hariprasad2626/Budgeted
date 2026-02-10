import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CacheService {
  static Future<void> saveList(String key, List<dynamic> list) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> data = list.map((item) {
      final map = item.toMap();
      try {
        map['id'] = item.id; // Inject ID into map for caching
      } catch (_) {}
      return _sanitizeMap(map);
    }).toList();
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<List<dynamic>?> loadList(String key, dynamic Function(String id, Map<String, dynamic> map) fromMap) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(key);
    if (jsonStr == null) return null;

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final id = map['id']?.toString() ?? '';
        return fromMap(id, map);
      }).toList();
    } catch (e) {
      print('Cache Load Error ($key): $e');
      return null;
    }
  }

  static Future<void> saveValue(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is double || value is int || value is String || value is bool) {
      await prefs.setString(key, value.toString());
    } else if (value == null) {
      await prefs.remove(key);
    }
  }

  static Future<String?> loadValue(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final newMap = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is Timestamp) {
        newMap[key] = value.toDate().toIso8601String();
      } else if (value is DateTime) {
        newMap[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        newMap[key] = _sanitizeMap(value);
      } else if (value is List) {
        newMap[key] = value.map((e) => e is Map<String, dynamic> ? _sanitizeMap(e) : e).toList();
      } else {
        newMap[key] = value;
      }
    });
    return newMap;
  }
}
