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
  }

  void reconnect() {
    this._reconnectLock.acquire();
    if (this._reconnectTimer != null) {
      this._reconnectTimer.cancel();
      this._reconnectTimer = null;
    }
    this._reconnectLock.release();

//    this.close();
    this._reconnects++;
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

//    this.send()
  }

  Future sub(String subName, List<dynamic> args) {}

  void send(dynamic msg) {
    json.encode(msg);
    // send to proxy
  }
}
