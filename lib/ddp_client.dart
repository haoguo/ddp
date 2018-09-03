part of ddp;

enum ConnectStatus {
  disconnected,
  dialing,
  connecting,
  connected,
}

typedef void ConnectionListener();
typedef void StatusListener(ConnectStatus status);

abstract class ConnectionNotifier {
  void addConnectionListener(ConnectionListener listener);
}

abstract class StatusNotifier {
  void addStatusListener(StatusListener listener);
}

class DdpClient implements ConnectionNotifier, StatusNotifier {
  Duration heartbeatInterval;
  Duration heartbeatTimeout;
  Duration reconnectInterval;

//  WriterStats _writeSocketStats;
//  WriterStats _writeStats;
//  WriterLogger _writeLog;
//  ReaderStats _readSocketStats;
//  ReaderStats _readStats;
//  ReaderLogger _readLog;
  int _reconnects;
  int _pingsIn;
  int _pingsOut;

  String _session;
  String _version;
  String _serverId;
  WebSocket _ws;
  String _url;
  String _origin;

//  Stream _inbox;
//  Stream _errors;
  Timer _pingTimer;

//  Map<String, List<pingTracker>> _pings;
  Map<String, Call> _calls;

  Map<String, Call> _subs;
  Map<String, Collection> _collections;
  ConnectStatus _connectionStatus;
  Timer _reconnectTimer;
  Mutex _reconnectLock;

  List<StatusListener> _statusListeners;
  List<ConnectionListener> _connectionListener;

  _IdManager _idManager;

  DdpClient(String url, String origin) {
    this.heartbeatInterval = const Duration(minutes: 1);
    this.heartbeatTimeout = const Duration(seconds: 15);
    this.reconnectInterval = const Duration(seconds: 5);
    this._collections = {};
    this._url = url;
    this._origin = origin;
//    this._inbox = Stream();
//    this.errors = Stream();

    this._connectionStatus = ConnectStatus.disconnected;
    this._statusListeners = [];
    this._connectionListener = [];
  }

  String get session => _session;

  String get version => _version;

  @override
  void addConnectionListener(ConnectionListener listener) {
    this._connectionListener.add(listener);
  }

  @override
  void addStatusListener(StatusListener listener) {
    this._statusListeners.add(listener);
  }

  void _status(ConnectStatus status) {
    if (this._connectionStatus == status) {
      return;
    }
    this._connectionStatus = status;
    this._statusListeners.forEach((l) => l(status));
  }

  void connect() {
    this._status(ConnectStatus.dialing);
    WebSocket.connect(this._url).then((connection) {
      final ws = connection;
      this._start(ws, Message.connect());
    }).catchError((error) {
      this.close();
      this._reconnectLater();
    });
  }

  void reconnect() {
    this._reconnectLock.acquire();
    if (this._reconnectTimer != null) {
      this._reconnectTimer.cancel();
      this._reconnectTimer = null;
    }
    this._reconnectLock.release();

    this.close();
    this._reconnects++;
    this._status(ConnectStatus.dialing);
    WebSocket.connect(this._url).then((connection) {
      this._start(connection, Message.reconnect(this._session));
      this._calls.values.forEach((call) =>
          this.send(Message.method(call.id, call.serviceMethod, call.args)));
      this._subs.values.forEach((call) =>
          this.send(Message.sub(call.id, call.serviceMethod, call.args)));
    }).catchError(() {
      this.close();
      this._reconnectLater();
    });
  }

  Call subscribe(String subName, OnCallDone done, List<dynamic> args) {
    if (args == null) {
      args = [];
    }

    final call = Call()
      ..id = _idManager.next()
      ..serviceMethod = subName
      ..args = args
      ..owner = this;

    if (done == null) {
      done = (c) {};
    }
    call.onceDone(done);
    this._subs[call.id] = call;

    this.send(Message.sub(call.id, subName, args));
  }

  Future sub(String subName, List<dynamic> args) {}

  void send(dynamic msg) {
    json.encode(msg);
    // send to proxy
  }

  void close() {
    if (this._pingTimer != null) {
      this._pingTimer.cancel();
      this._pingTimer = null;
    }

    if (this._ws != null) {
      this._ws.close(WebSocketStatus.normalClosure);
      this._ws = null;
    }

    this._collections.values.forEach((collection) => collection._reset());
    this._status(ConnectStatus.disconnected);
  }

  void resetStats() {
    // stats reset todo add
    this._reconnects = 0;
    this._pingsIn = 0;
    this._pingsOut = 0;
  }

  // ClientStats stats()

  bool socketLogActive() {
    return true; // Todo to be done
  }

  Collection collectionByName(String name) {
    if (!this._collections.containsKey(name)) {
      final collection = Collection.key(name);
      this._collections[name] = collection;
    }
    return this._collections[name];
  }

//  List<CollectionStats> collectionStats()
  void _start(WebSocket ws, _Connect connect) {
    this._status(ConnectStatus.connecting);

    this._ws = ws;
    // todo writer and reader

    // todo event emitter;
    this.send(connect);
  }

  void _reconnectLater() {
    this.close();
    this._reconnectLock.acquire();
    if (this._reconnectTimer == null) {
      this._reconnectTimer = Timer(this.reconnectInterval, this.reconnect);
    }
    this._reconnectLock.release();
  }

  void ping() {}

  void inboxManager() {
    this._ws.listen((event) {
      final message = json.decode(event) as Map<String, dynamic>;
      if (message.containsKey('msg')) {
        final mtype = message['msg'];
        switch (mtype) {
          case 'connected':
            {
              this._status(ConnectStatus.connected);
              this._collections.values.forEach((c) => c._init());
              this._version = '1';
              this._session = message['session'] as String;
//              this._pingTimer = Timer(this.heartbeatInterval, () {
//                this.ping();
//              });
              this._connectionListener.forEach((l) => l());
              break;
            }
          case 'failed':
            {
              break;
            }
          case 'ping':
            {
              if (message.containsKey('id')) {
                this.send(Message.pong(message['id']));
              } else {
                this.send(Message.pong(null));
              }
              this._pingsIn++;
            }
        }
      }
    });
  }
}
