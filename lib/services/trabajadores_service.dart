import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/TrabajadorModel.dart';

class TrabajadoresService {
  static const String baseUrl = 'https://apialert.c-centralizador.com/api';
  static const String tokenKey = 'jwt_token';

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(tokenKey);
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

  void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<TrabajadorModel>> getTrabajadores() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No hay conexión a internet. Por favor verifica tu conexión.');
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No se encontró token de autenticación');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/trabajadores'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Tiempo de espera agotado. Intente nuevamente.'),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status']) {
          List<dynamic> trabajadoresJson = data['response'];
          return trabajadoresJson.map((json) => TrabajadorModel.fromJson(json)).toList();
        }
        throw Exception('Error al obtener trabajadores');
      } else if (response.statusCode == 401) {
        throw Exception('Token de autenticación inválido');
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

  Future<TrabajadorModel> createTrabajador(TrabajadorModel trabajador) async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No hay conexión a internet. Por favor verifica tu conexión.');
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No se encontró token de autenticación');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/trabajadores'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(trabajador.toJson()),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Tiempo de espera agotado. Intente nuevamente.'),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status']) {
          return TrabajadorModel.fromJson(data['response']);
        }
        throw Exception('Error al crear trabajador');
      } else if (response.statusCode == 401) {
        throw Exception('Token de autenticación inválido');
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

  Future<TrabajadorModel> updateTrabajador(int id, TrabajadorModel trabajador) async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No hay conexión a internet. Por favor verifica tu conexión.');
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No se encontró token de autenticación');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/trabajadores/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(trabajador.toJson()),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Tiempo de espera agotado. Intente nuevamente.'),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status']) {
          return TrabajadorModel.fromJson(data['response']);
        }
        throw Exception('Error al actualizar trabajador');
      } else if (response.statusCode == 401) {
        throw Exception('Token de autenticación inválido');
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

  Future<bool> deleteTrabajador(int id) async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No hay conexión a internet. Por favor verifica tu conexión.');
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No se encontró token de autenticación');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/trabajadores/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Tiempo de espera agotado. Intente nuevamente.'),
      );

      print('Status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] ?? false;
      } else if (response.statusCode == 401) {
        throw Exception('Token de autenticación inválido');
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
} 