import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:rhythm_music/services/stream_service.dart';
import 'package:rhythm_music/services/stream_proxy.dart';

void main() {
  test('Verify Desktop Pipeline for 8W-pRnIe7UM', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    final dllFile = File(r"C:\Users\mdafs\AppData\Local\Programs\rhythm_music\libmpv-2.dll");
    final dllPath = dllFile.existsSync()
        ? dllFile.path
        : (File("libmpv-2.dll").existsSync() ? File("libmpv-2.dll").absolute.path : null);
    MediaKit.ensureInitialized(libmpv: dllPath);
    JustAudioMediaKit.registerWith();

    // 1. Fetch Song 8W-pRnIe7UM via stream_service.dart
    print("[1/3] Fetching stream URL for song: 8W-pRnIe7UM...");
    final streamProvider = await StreamProvider.fetch('8W-pRnIe7UM');
    print(" -> StreamProvider playable: ${streamProvider.playable}");
    print(" -> StreamProvider statusMSG: ${streamProvider.statusMSG}");

    expect(streamProvider.playable, isTrue);
    expect(streamProvider.highestQualityAudio, isNotNull);

    final audio = streamProvider.highestQualityAudio!;
    print(" -> Resolved Audio Format: itag=${audio.itag}, codec=${audio.audioCodec}, size=${audio.size}");
    print(" -> URL snippet: ${audio.url.substring(0, 100)}...");

    // 2. Start StreamProxy and generate proxy URL
    print("\n[2/3] Starting StreamProxy with httpClient.userAgent override...");
    await StreamProxy.ensureStarted();
    print(" -> StreamProxy port: ${StreamProxy.port}");

    final proxyUrl = StreamProxy.getProxyUrl(
      songId: '8W-pRnIe7UM',
      originalUrl: audio.url,
      totalSize: audio.size,
      mimeType: audio.audioCodec == Codec.mp4a ? 'audio/mp4' : 'audio/webm',
    );
    print(" -> Generated Proxy URL: $proxyUrl");

    // Verify direct proxy probe
    final probeClient = HttpClient();
    final headReq = await probeClient.headUrl(Uri.parse(proxyUrl));
    final headRes = await headReq.close();
    print(" -> Local Proxy HEAD Response Status: ${headRes.statusCode}");
    expect(headRes.statusCode, 200);

    // 3. Play through AudioPlayer (using just_audio + just_audio_media_kit on Windows)
    print("\n[3/3] Playing proxy URL through just_audio + just_audio_media_kit AudioPlayer...");
    final player = AudioPlayer();
    await player.setAudioSource(AudioSource.uri(Uri.parse(proxyUrl)));

    print(" -> Calling player.play()...");
    player.play();

    // Watchdog re-trigger if needed
    Future.delayed(const Duration(milliseconds: 150), () {
      if (player.processingState == ProcessingState.ready && !player.playing) {
        print(" [Watchdog 150ms] Re-triggering player.play()");
        player.play();
      }
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (player.processingState == ProcessingState.ready && !player.playing) {
        print(" [Watchdog 400ms] Re-triggering player.play()");
        player.play();
      }
    });

    print(" -> Waiting 6 seconds to observe live audio playback...");
    for (int i = 1; i <= 6; i++) {
      await Future.delayed(const Duration(seconds: 1));
      print("    [T+${i}s] playing=${player.playing}, state=${player.processingState}, position=${player.position.inSeconds}s, duration=${player.duration?.inSeconds ?? 0}s");
    }

    print("\n=================================================================");
    print("FINAL PLAYBACK STATS:");
    print("Playing: ${player.playing}");
    print("Processing State: ${player.processingState}");
    print("Duration: ${player.duration?.inSeconds} seconds");
    print("Position: ${player.position.inSeconds} seconds");
    print("=================================================================");

    expect(player.playing, isTrue);
    expect((player.position.inSeconds) >= 3, isTrue);

    await player.dispose();
  }, timeout: const Timeout(Duration(seconds: 40)));
}
