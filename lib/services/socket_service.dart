import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static IO.Socket? _socket;
  static final StreamController<String> _controller = StreamController<String>.broadcast();

  static Stream<String> get eventos => _controller.stream;

  static const String _url = 'https://ventasdeagua-backend.onrender.com';

  static void conectar() {
    if (_socket != null) return;

    _socket = IO.io(
      _url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(double.infinity.toInt())
          .build(),
    );

    _socket!.on('data_actualizada', (data) {
      if (data is Map && data['tipo'] is String) {
        _controller.add(data['tipo'] as String);
      }
    });

    _socket!.connect();
  }

  static void desconectar() {
    _socket?.dispose();
    _socket = null;
  }
}
