import 'package:ddp/ddp.dart';
import 'package:sprintf/sprintf.dart';
import 'package:test/test.dart';

void main() {
  test('IdManager', () {
    print(sprintf('%x', [16]));
  });

  test('DdpClientTest', () {
    DdpClient client = DdpClient(
        'DdpClientTest', 'ws://localhost:3000/websocket', 'http://localhost');
    client.connect();
  });
}
