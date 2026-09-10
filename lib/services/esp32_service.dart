import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/esp32_data.dart';

class Esp32Service {
  static const String _prefIpKey = 'esp32_ip_address';
  static const String defaultIp = '192.168.1.50';

  /// Obtiene la IP guardada o la predeterminada
  static Future<String> getSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefIpKey) ?? defaultIp;
  }

  /// Guarda una nueva dirección IP
  static Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefIpKey, ip.trim());
  }

  /// Normaliza la URL agregando http:// si no lo tiene
  static String formatBaseUrl(String ip) {
    String cleanIp = ip.trim();
    if (!cleanIp.startsWith('http://') && !cleanIp.startsWith('https://')) {
      cleanIp = 'http://$cleanIp';
    }
    // Quitar barra final si existe
    if (cleanIp.endsWith('/')) {
      cleanIp = cleanIp.substring(0, cleanIp.length - 1);
    }
    return cleanIp;
  }

  /// Prueba la conexión contra el ESP32 con timeout de 3 segundos
  static Future<bool> testConnection(String ip) async {
    try {
      final url = Uri.parse('${formatBaseUrl(ip)}/datos');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      try {
        final rootUrl = Uri.parse('${formatBaseUrl(ip)}/');
        final res = await http.get(rootUrl).timeout(const Duration(seconds: 3));
        return res.statusCode >= 200 && res.statusCode < 400;
      } catch (_) {
        return false;
      }
    }
  }

  /// GET /datos
  static Future<Esp32Data> fetchDatos(String ip) async {
    final url = Uri.parse('${formatBaseUrl(ip)}/datos');
    final response = await http.get(url).timeout(const Duration(seconds: 4));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return Esp32Data.fromJson(decoded, response.body);
    } else {
      throw Exception('Error del servidor ESP32: HTTP ${response.statusCode}');
    }
  }

  /// GET /girar?dir=X&vueltas=Y&accion=Z
  static Future<String> girarMotor({
    required String ip,
    required String dir,
    required num vueltas,
    required String accion,
  }) async {
    final uri = Uri.parse(
      '${formatBaseUrl(ip)}/girar?dir=$dir&vueltas=$vueltas&accion=$accion',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    return response.body;
  }

  /// GET /setBrillo?val=X
  static Future<String> setBrillo(String ip, int valor) async {
    final uri = Uri.parse('${formatBaseUrl(ip)}/setBrillo?val=$valor');
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    return response.body;
  }

  /// GET /setSetpoint?val=X
  static Future<String> setSetpoint(String ip, num valor) async {
    final uri = Uri.parse('${formatBaseUrl(ip)}/setSetpoint?val=$valor');
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    return response.body;
  }

  /// GET /toggleModo
  static Future<String> toggleModo(String ip) async {
    final uri = Uri.parse('${formatBaseUrl(ip)}/toggleModo');
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    return response.body;
  }

  /// GET /setLimite
  static Future<String> setLimite(String ip) async {
    final uri = Uri.parse('${formatBaseUrl(ip)}/setLimite');
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    return response.body;
  }

  /// GET /resetPos
  static Future<String> resetPos(String ip) async {
    final uri = Uri.parse('${formatBaseUrl(ip)}/resetPos');
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    return response.body;
  }

  /// GET /setPosMax
  static Future<String> setPosMax(String ip) async {
    final uri = Uri.parse('${formatBaseUrl(ip)}/setPosMax');
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    return response.body;
  }
}
