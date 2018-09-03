import 'dart:convert';
import 'dart:io';

import 'package:ddp/ddp.dart';
import 'package:test/test.dart';

void main() {
  test('test message marshall', () {
    print(Message.connect().toJson());
  });

  test('adds one to input values', () {
    WebSocket.connect('ws://localhost:3000/websocket').then((ws) {
      ws.listen((event) {
        print(event);
        final e = json.decode(event);
        if (e['msg'] == "ping") {
          final pong = Message.pong(null).toJson();
          print(pong);
          ws.add(pong);
        }
      });
      final msg = '${Message.connect().toJson()}';
      ws.add(msg);
    });
//    DdpClient client = DdpClient('', '');
//    client.addStatusListener((s) => print(s));
//    client.connect();
  });
}
