part of ddp;

class Doc {
  dynamic root;

  Doc(this.root);

  Map<String, dynamic> map(String path) {
    final _item = this.item(path);
    if (_item != null && _item.runtimeType == Map) {
      return _item;
    }
    return null;
  }

  List<dynamic> array(String path) {
    final _item = this.item(path);
    if (_item != null && _item.runtimeType == List) {
      return _item;
    }
    return null;
  }

  dynamic item(String path) {
    Map<String, dynamic> item = this.root;
    path.split('.').forEach((step) {
      if (item.runtimeType == Map) {
        item = item[step];
      } else {
        return null;
      }
    });
    return item;
  }
}

