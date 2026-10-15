import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();

    try {
      StreamManifest? res;

      // Fast default client (typically resolves in 1-2s) with fallback
      try {
        res = await yt.videos.streamsClient.getManifest(videoId);
      } catch (e) {
        try {
          res = await yt.videos.streamsClient.getManifest(
            videoId,
            ytClients: [YoutubeApiClient.android],
          );
        } catch (_) {
          res = await yt.videos.streamsClient.getManifest(
            videoId,
            ytClients: [YoutubeApiClient.androidVr],
          );
        }
      }

      final List<Audio> allAudio = [];

      // 1. Tag 18 (muxed 360p MP4 with ratebypass=yes)
      // Provides 128 kbps AAC audio without YouTube's 1MB SABR throttling or seek 403s
      final tag18 = res.muxed.cast<MuxedStreamInfo?>().firstWhere(
          (e) => e?.tag == 18,
          orElse: () => null);
      if (tag18 != null) {
        allAudio.add(Audio(
          itag: tag18.tag,
          audioCodec: Codec.mp4a,
          bitrate: 128000,
          duration: 0,
          loudnessDb: 0.0,
          url: tag18.url.toString(),
          size: tag18.size.totalBytes,
        ));
      }

      // 2. Audio-only formats (itag 140, 251, etc.)
      for (final e in res.audioOnly) {
        allAudio.add(Audio(
          itag: e.tag,
          audioCodec: e.audioCodec.toString().contains('mp')
              ? Codec.mp4a
              : Codec.opus,
          bitrate: e.bitrate.bitsPerSecond,
          duration: 0,
          loudnessDb: 0.0,
          url: e.url.toString(),
          size: e.size.totalBytes,
        ));
      }

      if (allAudio.isEmpty) {
        return StreamProvider(
          playable: false,
          statusMSG: "No audio stream available",
        );
      }

      return StreamProvider(
        playable: true,
        statusMSG: "OK",
        audioFormats: allAudio,
      );
    } catch (e) {
      if (e is SocketException) {
        return StreamProvider(
          playable: false,
          statusMSG: "networkError",
        );
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message,
        );
      } else if (e is VideoRequiresPurchaseException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song requires purchase",
        );
      } else if (e is VideoUnavailableException) {
        return StreamProvider(
          playable: false,
          statusMSG: "Song is unavailable",
        );
      } else if (e is YoutubeExplodeException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message,
        );
      } else {
        return StreamProvider(
          playable: false,
          statusMSG: "Unknown error occurred",
        );
      }
    } finally {
      yt.close();
    }
  }

  Audio? get highestQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    // Prefer itag 18 (unthrottled ratebypass mp4a) for 100% seek & playback reliability
    final itag18 = audioFormats!.cast<Audio?>().firstWhere(
        (item) => item!.itag == 18,
        orElse: () => null);
    if (itag18 != null) return itag18;

    final itag140 = audioFormats!.cast<Audio?>().firstWhere(
        (item) => item!.itag == 140,
        orElse: () => null);
    if (itag140 != null) return itag140;

    final itag251 = audioFormats!.cast<Audio?>().firstWhere(
        (item) => item!.itag == 251,
        orElse: () => null);
    if (itag251 != null) return itag251;

    return audioFormats!.first;
  }

  Audio? get highestBitrateMp4aAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    // Prefer itag 18: unthrottled with ratebypass=yes, immune to YouTube 403 Forbidden
    final itag18 = audioFormats!.cast<Audio?>().firstWhere(
        (item) => item?.itag == 18,
        orElse: () => null);
    if (itag18 != null) return itag18;

    return audioFormats!.cast<Audio?>().lastWhere(
        (item) => item!.itag == 140 || item.itag == 139,
        orElse: () => audioFormats!.first);
  }

  Audio? get highestBitrateOpusAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    return audioFormats!.cast<Audio?>().lastWhere(
        (item) => item!.itag == 251 || item.itag == 250,
        orElse: () => audioFormats!.first);
  }

  Audio? get lowQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    return audioFormats!.cast<Audio?>().lastWhere(
        (item) => item!.itag == 249 || item.itag == 139,
        orElse: () => audioFormats!.first);
  }

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson()
    };
  }
}

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;
  Audio(
      {required this.itag,
      required this.audioCodec,
      required this.bitrate,
      required this.duration,
      required this.loudnessDb,
      required this.url,
      required this.size});

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.toString(),
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size
      };

  factory Audio.fromJson(json) => Audio(
      audioCodec: (json["audioCodec"] as String).contains("mp4a")
          ? Codec.mp4a
          : Codec.opus,
      itag: json['itag'],
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'])?.toDouble() ?? 0.0,
      url: json['url'],
      size: json["size"] ?? 0);
}

enum Codec { mp4a, opus }
