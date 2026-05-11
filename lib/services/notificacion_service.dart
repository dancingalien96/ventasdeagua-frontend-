import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // FCM maneja automáticamente las notificaciones en background/terminated
  // Este handler es para procesamiento adicional si se necesita
}

class NotificacionService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> inicializar() async {
    // Solicitar permisos (necesario en iOS)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurar canal Android para notificaciones en primer plano
    const androidChannel = AndroidNotificationChannel(
      'control_ventas_channel',
      'Control de Ventas',
      description: 'Notificaciones del sistema de ventas',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Manejar notificaciones cuando la app está en primer plano
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            androidChannel.id,
            androidChannel.name,
            channelDescription: androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });

    // Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  }

  static Future<void> guardarToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await ApiService.post('/auth/fcm-token', {'token': token});
    }

    // Actualizar token si cambia (p.ej. al reinstalar la app)
    _messaging.onTokenRefresh.listen((nuevoToken) {
      ApiService.post('/auth/fcm-token', {'token': nuevoToken});
    });
  }
}
