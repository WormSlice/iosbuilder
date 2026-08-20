class RecordConfig {
  const RecordConfig();
}

class AudioRecorder {
  Future<void> start(RecordConfig config, {required String path}) async {}

  Future<String?> stop() async {
    return null;
  }

  Future<bool> hasPermission() async {
    return true;
  }

  void dispose() {}
}
