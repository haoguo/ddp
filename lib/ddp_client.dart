part of ddp;

enum ConnectStatus {
  disconnected,
  dialing,
  connecting,
  connected,
}

typedef void _MessageHandler(Map<String, dynamic> message);

typedef void ConnectionListener();
typedef void StatusListener(ConnectStatus status);

abstract class ConnectionNotifier {
  void addConnectionListener(ConnectionListener listener);
}

abstract class StatusNotifier {
  void addStatusListener(StatusListener listener);
}

class DdpClient implements ConnectionNotifier, StatusNotifier {
  String _name;
  Duration heartbeatInterval;
  Duration heartbeatTimeout;
  Duration reconnectInterval;

  WriterStats _writeSocketStats;
  WriterStats _writeStats;
  WriterLogger _writeLog;
  ReaderStats _readSocketStats;
  ReaderStats _readStats;
  ReaderLogger _readLog;

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

  Map<String, List<_PingTracker>> _pings;
  Map<String, Call> _calls;
  Map<String, Call> _subs;
  Map<String, Call> _unsubs;

  Map<String, Collection> _collections;
  ConnectStatus _connectionStatus;
  Timer _reconnectTimer;
  Mutex _reconnectLock;

  List<StatusListener> _statusListeners;
  List<ConnectionListener> _connectionListener;

  _IdManager _idManager;

  Map<String, _MessageHandler> _messageHandlers;

  DdpClient(this._name, String url, String origin) {
    this.heartbeatInterval = const Duration(minutes: 1);
    this.heartbeatTimeout = const Duration(seconds: 15);
    this.reconnectInterval = const Duration(seconds: 5);
    this._collections = {};
    this._url = url;
    this._origin = origin;
//    this._inbox = Stream();
//    this.errors = Stream();
    this._pings = {};
    this._calls = {};
    this._subs = {};
    this._unsubs = {};
    this._connectionStatus = ConnectStatus.disconnected;
    this._reconnectLock = Mutex();

    this._writeSocketStats = WriterStats(null);
    this._writeStats = WriterStats(null);
    this._readSocketStats = ReaderStats(null);
    this._readStats = ReaderStats(null);

    this._writeLog = WriterLogger.text(null);
    this._readLog = ReaderLogger.text(null);

    this._idManager = _IdManager();

    this._statusListeners = [];
    this._connectionListener = [];

    this._reconnects = 0;
    this._pingsIn = 0;
    this._pingsOut = 0;
  }

  void _log(String msg) {
    print('[DdpClient - ${_name}] $msg');
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
      this._calls.values.forEach((call) => this.send(
          Message.method(call.id, call.serviceMethod, call.args).toJson()));
      this._subs.values.forEach((call) => this
          .send(Message.sub(call.id, call.serviceMethod, call.args).toJson()));
    }).catchError((error) {
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

    this.send(Message.sub(call.id, subName, args).toJson());
    return call;
  }

  Future<Call> sub(String subName, List<dynamic> args) {
    Completer<Call> completer = Completer();
    subscribe(subName, (call) => completer.complete(call), args);
    return completer.future;
  }

  Call unSubscribe(String id, OnCallDone done) {
    final call = Call()
      ..id = id
      ..owner = this;

    if (done == null) {
      done = (c) {};
    }
    call.onceDone(done);
    this._unsubs[call.id] = call;
    this.send(Message.unSub(call.id).toJson());
    return call;
  }

  Future<Call> unSub(String id) {
    Completer<Call> completer = Completer();
    unSubscribe(id, (call) => completer.complete(call));
    return completer.future;
  }

  Call go(String serviceMethod, OnCallDone done, List<dynamic> args) {
    if (args == null) {
      args = [];
    }
    final call = Call()
      ..id = this._idManager.next()
      ..serviceMethod = serviceMethod
      ..args = args
      ..owner = this;
    if (done == null) {
      done = (c) {};
    }
    call.onceDone(done);
    this._calls[call.id] = call;
    this.send(Message.method(call.id, serviceMethod, args).toJson());
    return call;
  }

  Future<Call> call(String serviceMethod, List<dynamic> args) {
    Completer<Call> completer = Completer();
    go(serviceMethod, (call) => completer.complete(call), args);
    return completer.future;
  }

  void send(dynamic msg) {
    this._writeStats.add(msg);
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
    this._readSocketStats.reset();
    this._readStats.reset();
    this._writeSocketStats.reset();
    this._writeStats.reset();
    this._reconnects = 0;
    this._pingsIn = 0;
    this._pingsOut = 0;
  }

  ClientStats stats() {
    return ClientStats()
      ..reads = this._readSocketStats.snapshot()
      ..totalReads = this._readStats.snapshot()
      ..writes = this._writeSocketStats.snapshot()
      ..totalWrites = this._writeStats.snapshot()
      ..reconnects = this._reconnects
      ..pingsSent = this._pingsOut
      ..pingsRecv = this._pingsIn;
  }

  bool socketLogActive() {
    return this._writeLog.active;
  }

  void setSocketLogActive(bool active) {
    assert(active != null);
    this._writeLog.active = active;
    this._readLog.active = active;
  }

  Collection collectionByName(String name) {
    if (!this._collections.containsKey(name)) {
      final collection = Collection.key(name);
      this._collections[name] = collection;
    }
    return this._collections[name];
  }

  List<CollectionStats> collectionStats() {
    List<CollectionStats> stats = [];
    this._collections.forEach((name, collection) => stats.add(CollectionStats()
      ..name = name
      ..count = collection.findAll().length));
    return stats;
  }

  void _start(WebSocket ws, _Connect connect) {
    this._status(ConnectStatus.connecting);

    this._initMessageHandlers();
    this._ws = ws;

    this._writeLog.setWriter(ws);
    this._writeSocketStats = WriterStats(this._writeLog);
    this._writeStats.setWriter(this._writeSocketStats);
    this._readLog.setReader(ws);
    this._readSocketStats = ReaderStats(this._readLog);
    this._readStats.setReader(this._readSocketStats);

    this.inboxManager();

    this.send(connect.toJson());
  }

  void _reconnectLater() {
    this.close();
    this._reconnectLock.acquire();
    if (this._reconnectTimer == null) {
      this._reconnectTimer = Timer(this.reconnectInterval, this.reconnect);
    }
    this._reconnectLock.release();
  }

  void ping() {
    this.pingPong(this._idManager.next(), this.heartbeatTimeout, (err) {
      if (err != null) {
        this._reconnectLater();
      }
    });
  }

  void pingPong(String id, Duration timeout, Function(Error) handler) {
    this.send(Message.ping(id).toJson());
    this._pingsOut++;
    if (!this._pings.containsKey(id)) {
      this._pings[id] = [];
    }
    final pingTracker = _PingTracker()
      .._handler = handler
      .._timeout = timeout
      .._timer = Timer(timeout, () {
        handler(ArgumentError('ping timeout'));
      });
    this._pings[id].add(pingTracker);
  }

  void _initMessageHandlers() {
    this._messageHandlers = {};
    this._messageHandlers['connected'] = (msg) {
      this._status(ConnectStatus.connected);
      this._collections.values.forEach((c) => c._init());
      this._version = '1';
      this._session = msg['session'] as String;
      this._pingTimer = Timer.periodic(this.heartbeatInterval, (Timer timer) {
        this.ping();
      });
      this._connectionListener.forEach((l) => l());
    };
    this._messageHandlers['ping'] = (msg) {
      if (msg.containsKey('id')) {
        this.send(Message.pong(msg['id']).toJson());
      } else {
        this.send(Message.pong(null).toJson());
      }
      this._pingsIn++;
    };
    this._messageHandlers['pong'] = (msg) {
      var key = '';
      if (msg.containsKey('id')) {
        key = msg['id'] as String;
      }
      if (this._pings.containsKey(key)) {
        final pings = this._pings[key];
        if (pings.length > 0) {
          final ping = pings[0];
          final newPings = pings.sublist(1);
          if (key.length == 0 || pings.length > 0) {
            this._pings[key] = newPings;
          }
          ping._timer.cancel();
          ping._handler(null);
        }
      }
    };
    this._messageHandlers['nosub'] = (msg) {
      if (msg.containsKey('id')) {
        final id = msg['id'] as String;
        final runningSub = this._subs[id];
        if (runningSub != null) {
          print(runningSub);
          this._log('Subscription returned a nosub error $msg');
          runningSub.error = ArgumentError(
              'Subscription returned a nosub error'); // TODO error type.
          runningSub.done();
          this._subs.remove(id);
        }

        final runningUnSub = this._unsubs[id];
        if (runningUnSub != null) {
          runningUnSub.done();
          this._unsubs.remove(id);
        }
      }
    };
    this._messageHandlers['ready'] = (msg) {
      if (msg.containsKey('subs')) {
        final subs = msg['subs'] as List<dynamic>;
        subs.forEach((sub) {
          if (this._subs.containsKey(sub)) {
            this._subs[sub].done();
            this._subs.remove(sub);
          }
        });
      }
    };
    this._messageHandlers['added'] =
        (msg) => this._collectionBy(msg)._added(msg);
    this._messageHandlers['changed'] =
        (msg) => this._collectionBy(msg)._changed(msg);
    this._messageHandlers['removed'] =
        (msg) => this._collectionBy(msg)._removed(msg);
    this._messageHandlers['addedBefore'] =
        (msg) => this._collectionBy(msg)._addedBefore(msg);
    this._messageHandlers['movedBefore'] =
        (msg) => this._collectionBy(msg)._movedBefore(msg);
    this._messageHandlers['result'] = (msg) {
      if (msg.containsKey('id')) {
        final id = msg['id'];
        final call = this._calls[id];
        this._calls.remove(id);
        if (msg.containsKey('error')) {
          final e = msg['error'];
          call.error = ArgumentError(json.encode(e)); // TODO Error Type
          call.reply = e;
        } else {
          call.reply = msg['result'];
        }
        call.done();
      }
    };
    this._messageHandlers['updated'] = (msg) {};
  }

  void inboxManager() {
    this._readStats.listen((event) {
      final message = json.decode(event) as Map<String, dynamic>;
      if (message.containsKey('msg')) {
        final mtype = message['msg'];
        if (this._messageHandlers.containsKey(mtype)) {
          this._messageHandlers[mtype](message);
        } else {
          this._log('Server sent unexpected message ${message}');
        }
      } else if (message.containsKey('server_id')) {
        final serverId = message['server_id'];
        if (serverId.runtimeType == String) {
          this._serverId = serverId;
        } else {
          this._log('Server cluster node ${serverId}');
        }
      } else {
        this._log('Server sent message without `msg` field ${message}');
      }
    });
  }

  Collection _collectionBy(Map<String, dynamic> msg) {
    if (msg.containsKey('collection')) {
      final name = msg['collection'];
      if (name.runtimeType == String) {
        return this.collectionByName(name);
      }
    }
    return Collection.mock();
  }
}
