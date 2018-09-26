part of ddp;

typedef void UpdateListener(
    String collection, String operation, String id, Map<String, dynamic> doc);

Tuple2<String, Map<String, dynamic>> _parseUpdate(Map<String, dynamic> update) {
  if (update.containsKey('id')) {
    final id = update['id'];
    if (id.runtimeType == String) {
      if (update.containsKey('fields')) {
        final updates = update['fields'];
        if (updates is Map) {
          return Tuple2(id, updates);
        }
      }
      return Tuple2(id, null);
    }
  }
  return Tuple2('', null);
}

abstract class Collection {
  Map<String, dynamic> findOne(String id);

  Map<String, Map<String, dynamic>> findAll();

  void addUpdateListener(UpdateListener listener);

  void _added(Map<String, dynamic> msg);

  void _changed(Map<String, dynamic> msg);

  void _removed(Map<String, dynamic> msg);

  void _addedBefore(Map<String, dynamic> msg);

  void _movedBefore(Map<String, dynamic> msg);

  void _init();

  void _reset();

  factory Collection.mock() => MockCache();

  factory Collection.key(String name) => KeyCache(name, {}, []);
}

class KeyCache implements Collection {
  String name;
  Map<String, Map<String, dynamic>> _items;
  List<UpdateListener> _listeners;

  KeyCache(this.name, this._items, this._listeners);

  void _notify(String operation, String id, Map<String, dynamic> doc) {
    this._listeners.forEach((l) => l(this.name, operation, id, doc));
  }

  @override
  void _added(Map<String, dynamic> msg) {
    final pair = _parseUpdate(msg);
    if (pair.item2 != null) {
      this._items[pair.item1] = pair.item2;
      this._notify('create', pair.item1, pair.item2);
    }
  }

  @override
  void _addedBefore(Map<String, dynamic> msg) {}

  @override
  void _changed(Map<String, dynamic> msg) {
    final pair = _parseUpdate(msg);
    if (pair.item2 != null) {
      if (this._items.containsKey(pair.item1)) {
        final item = this._items[pair.item1];
        pair.item2.forEach((key, value) => item[key] = value);
        this._items[pair.item1] = item;
        this._notify('update', pair.item1, item);
      }
    }
  }

  @override
  void _init() {}

  @override
  void _movedBefore(Map<String, dynamic> msg) {}

  @override
  void _removed(Map<String, dynamic> msg) {
    final pair = _parseUpdate(msg);
    if (pair.item1.length > 0) {
      this._items.remove(pair.item1);
      this._notify('remove', pair.item1, null);
    }
  }

  @override
  void _reset() {
    this._notify('reset', '', null);
  }

  @override
  void addUpdateListener(UpdateListener listener) =>
      this._listeners.add(listener);

  @override
  Map<String, Map<String, dynamic>> findAll() => this._items;

  @override
  Map<String, dynamic> findOne(String id) => this._items[id];
}

class OrderedCache implements Collection {
  List<dynamic> _items;

  @override
  void _added(Map<String, dynamic> msg) {}

  @override
  void _addedBefore(Map<String, dynamic> msg) {}

  @override
  void _changed(Map<String, dynamic> msg) {}

  @override
  void _init() {}

  @override
  void _movedBefore(Map<String, dynamic> msg) {}

  @override
  void _removed(Map<String, dynamic> msg) {}

  @override
  void _reset() {}

  @override
  void addUpdateListener(UpdateListener listener) {}

  @override
  Map<String, Map<String, dynamic>> findAll() => {};

  @override
  Map<String, dynamic> findOne(String id) => null;
}

class MockCache implements Collection {
  @override
  void _added(Map<String, dynamic> msg) {}

  @override
  void _addedBefore(Map<String, dynamic> msg) {}

  @override
  void _changed(Map<String, dynamic> msg) {}

  @override
  void _init() {}

  @override
  void _movedBefore(Map<String, dynamic> msg) {}

  @override
  void _removed(Map<String, dynamic> msg) {}

  @override
  void _reset() {}

  @override
  void addUpdateListener(UpdateListener listener) {}

  @override
  Map<String, Map<String, dynamic>> findAll() => {};

  @override
  Map<String, dynamic> findOne(String id) => null;
}
