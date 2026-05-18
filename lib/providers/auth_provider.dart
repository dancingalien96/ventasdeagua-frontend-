import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../services/notificacion_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  Usuario? _usuario;
  bool _cargando = false;

  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get autenticado => _usuario != null;

  Future<void> cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final nombre = prefs.getString('nombre');
    final rol = prefs.getString('rol');
    final id = prefs.getString('id');
    if (token != null && nombre != null && rol != null && id != null) {
      _usuario = Usuario(id: id, nombre: nombre, rol: rol);
      SocketService.conectar();
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    _cargando = true;
    notifyListeners();
    try {
      final res = await ApiService.post('/auth/login', {'email': email, 'password': password}, auth: false);
      if (res['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', res['token']);
        await prefs.setString('nombre', res['usuario']['nombre']);
        await prefs.setString('rol', res['usuario']['rol']);
        await prefs.setString('id', res['usuario']['id'].toString());
        _usuario = Usuario.fromJson(res['usuario']);
        await NotificacionService.guardarToken();
        SocketService.conectar();
        return null;
      }
      return res['mensaje'] ?? 'Error al iniciar sesión';
    } catch (e) {
      return 'Error de conexión';
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    SocketService.desconectar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _usuario = null;
    notifyListeners();
  }
}
