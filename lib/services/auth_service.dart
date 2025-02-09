import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://apialert.c-centralizador.com/api';
  static const String tokenKey = 'jwt_token';
  static const String userIdKey = 'idUsuario';
  static const String businessIdKey = 'idNegocio';

  void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> login(String username, String password) async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No hay conexión a internet. Por favor verifica tu conexión.');
      }

      if (username.isEmpty || password.isEmpty) {
        throw Exception('Usuario y contraseña son requeridos.');
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/Usuario/LoginNegocio'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'Usuario': username, 'Password': password}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Tiempo de espera agotado. Intente nuevamente.'),
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
      await prefs.setString(tokenKey, userData['token']);
      await prefs.setInt(userIdKey, userData['usuario']['id']);
      await prefs.setInt(businessIdKey, userData['usuario']['idNegocio']);
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
    } catch (e) {
      print('Error limpiando datos: $e');
      // Incluso si hay error, continuamos sin lanzar excepción
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
}