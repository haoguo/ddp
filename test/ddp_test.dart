import 'package:ddp/ddp.dart';
import 'package:test/test.dart';

void main() {
  test('IdManager', () {
    print(16.toRadixString(16));
  });

  test('DdpClientTest', () {
    DdpClient client = DdpClient(
        'DdpClientTest', 'ws://localhost:3000/websocket', 'http://localhost');
    client.connect();
  });
}
