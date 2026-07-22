import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    final videoId = 'h1-37d4Y_68'; // 3 TROKAS
    final manifest = await yt.videos.streamsClient.getManifest(videoId);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
    print('Audio URL: ${audioStreamInfo.url}');
  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}
