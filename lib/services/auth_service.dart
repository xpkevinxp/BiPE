import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/BipeModel.dart';

class AuthService {
  static const String baseUrl = 'https://apialert.c-centralizador.com/api';
  static const String tokenKey = 'jwt_token';
  static const String userIdKey = 'idUsuario';
  static const String businessIdKey = 'idNegocio';
  static const String nombreKey = 'nombre';
  static const String nombreNegocioKey = 'nombreNegocio';
  static const String nombrePlanKey = 'nombrePlan';
  static const String bipesKey = 'bipes';

  void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> login(String username, String password) async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception(
            'No hay conexión a internet. Por favor verifica tu conexión.');
      }

      if (username.isEmpty || password.isEmpty) {
        throw Exception('Usuario y contraseña son requeridos.');
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/Usuario/LoginNegocio'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'Usuario': username, 'Password': password}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
                'Tiempo de espera agotado. Intente nuevamente.'),
          );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status']) {
          await _saveUserData(data['response']);
          return true;
        }
        throw Exception('Credenciales inválidas');
      } else if (response.statusCode == 401) {
        throw Exception('Usuario o contraseña incorrectos');
      } else {
        throw Exception('Error en el servidor. Intente más tarde');
      }
    } catch (e) {
      if (e is SocketException || e is ClientException) {
        throw Exception('Error de conexión. Verifique su conexión a internet.');
      }
      rethrow;
    }
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar token
      await prefs.setString(tokenKey, userData['token']);

      // Guardar datos del usuario
      final usuario = userData['usuario'];
      await prefs.setInt(userIdKey, usuario['id']);
      await prefs.setInt(businessIdKey, usuario['idNegocio']);
      await prefs.setString(nombreKey, usuario['nombre']);
      await prefs.setString(nombreNegocioKey, usuario['nombreNegocio']);
      await prefs.setString(nombrePlanKey, usuario['nombrePlan']);

      // Guardar bipes
      final bipes = userData['bipes'];
      await prefs.setString(bipesKey, jsonEncode(bipes));
    } catch (e) {
      print('Error guardando datos de usuario: $e');
      await _clearAllData();
      throw Exception('Error al guardar datos de sesión');
    }
  }

  Future<void> _clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tokenKey);
      await prefs.remove(userIdKey);
      await prefs.remove(businessIdKey);
      await prefs.remove(nombreKey);
      await prefs.remove(nombreNegocioKey);
      await prefs.remove(nombrePlanKey);
      await prefs.remove(bipesKey);
    } catch (e) {
      print('Error limpiando datos: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tokenKey);
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final token = await getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('Error verificando autenticación: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _clearAllData();
    } catch (e) {
      print('Error durante logout: $e');
      // Intentar limpiar datos nuevamente en caso de error
      await _clearAllData();
    }
  }

  // Métodos de utilidad para obtener datos guardados
  Future<String?> getNombre() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(nombreKey);
  }

  Future<String?> getNombreNegocio() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(nombreNegocioKey);
  }

  Future<String?> getNombrePlan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(nombrePlanKey);
  }

  Future<List<Bipe>> getBipes() async {
    final prefs = await SharedPreferences.getInstance();
    final bipesString = prefs.getString(bipesKey);
    if (bipesString == null) return [];
    
    final List<dynamic> bipesJson = jsonDecode(bipesString);
    return bipesJson.map((json) => Bipe.fromJson(json)).toList();
  }
}
