enum AudioEncoder {
  aacLc,
  aacEld,
  aacHe,
  amrNb,
  amrWb,
  opus,
  flac,
  pcm16bit,
  wav,
}

class RecordConfig {
  final AudioEncoder encoder;

  const RecordConfig({
    this.encoder = AudioEncoder.aacLc,
  });
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
