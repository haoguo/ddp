part of ddp;

class Message {
  String type;
  String id;

  Message(this.id, this.type);

  factory Message.ping(String id) => _Ping(id);

  factory Message.pong(String id) => _Pong(id);

  factory Message.method(String id, String serviceMethod, List<dynamic> args) =>
      _Method(id, serviceMethod, args);

  factory Message.sub(String id, String subName, List<dynamic> args) =>
      _Sub(id, subName, args);

  factory Message.connect() => _Connect('1', ['1'], null);

  factory Message.reconnect(String session) => _Connect('1', ['1'], session);

  String toJson() {
    return json.encode(this._toMap());
  }

  Map<String, dynamic> _toMap() {
    Map<String, dynamic> map = {};
    if (this.id != null) {
      map['id'] = this.id;
    }
    map['msg'] = this.type;
    return map;
  }
}

class _Ping extends Message {
  _Ping(String id) : super(id, 'ping');
}

class _Pong extends Message {
  _Pong(String id) : super(id, 'pong');
}

class _Method extends Message {
  String serviceMethod;
  List<dynamic> args;

  _Method(String id, this.serviceMethod, this.args) : super(id, 'method');

  @override
  Map<String, dynamic> _toMap() {
    final map = super._toMap();
    map['method'] = this.serviceMethod;
    map['params'] = args;
    return map;
  }
}

class _Sub extends Message {
  String subName;
  List<dynamic> args;

  _Sub(String id, this.subName, this.args) : super(id, 'sub');

  @override
  Map<String, dynamic> _toMap() {
    final map = super._toMap();
    map['name'] = this.subName;
    map['params'] = args;
    return map;
  }
}

class _Connect extends Message {
  String version;
  List<String> support;
  String session;

  _Connect(this.version, this.support, this.session) : super(null, 'connect');

  @override
  Map<String, dynamic> _toMap() {
    final map = super._toMap();
    map['version'] = this.version;
    map['support'] = this.support;
    if (this.session != null) {
      map['session'] = this.session;
    }
    return map;
  }
}
