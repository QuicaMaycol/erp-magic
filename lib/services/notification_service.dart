import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();

  Future<void> initialize() async {
    // 1. Solicitar permisos (Vital para iOS y Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔔 Permisos de notificación concedidos');
      
      // 2. Obtener el token del dispositivo
      String? token = await _fcm.getToken();
      if (token != null) {
        print('🔑 FCM TOKEN: $token');
        await _saveTokenToUser(token);
      }

      // 3. Escuchar actualizaciones de token
      _fcm.onTokenRefresh.listen(_saveTokenToUser);
    } else {
      print('❌ Permisos de notificación denegados');
    }
  }

  Future<void> _saveTokenToUser(String token) async {
    try {
      final user = await _authService.getCurrentProfile();
      if (user != null && user.id.isNotEmpty) {
        await _authService.updateUser(user.id, {'fcm_token': token});
        print('✅ Token guardado en el perfil del usuario');
      }
    } catch (e) {
       print('⚠️ Error guardando fcm_token: $e');
    }
  }
}
