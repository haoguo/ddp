library ddp;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tuple/tuple.dart';

part 'ddp_client.dart';
part 'ddp_collection.dart';
part 'ddp_messages.dart';
part 'ddp_stats.dart';

class _IdManager {
  int _next = 0;

  String next() {
    final next = _next;
    _next++;
    return next.toRadixString(16);
  }
}

class _PingTracker {
  Function(Error) _handler;
  Duration _timeout;
  Timer _timer;
}

typedef void OnCallDone(Call call);

class Call {
  String id;
  String serviceMethod;
  dynamic args;
  dynamic reply;
  Error error;
  DdpClient owner;
  List<OnCallDone> _handlers = [];

  void onceDone(OnCallDone fn) {
    this._handlers.add(fn);
  }

  void done() {
    owner._calls.remove(this.id);
    _handlers.forEach((handler) => handler(this));
    _handlers.clear();
  }
}
