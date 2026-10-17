import 'dart:convert';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;
  StreamProvider(
      {required this.playable, this.audioFormats, this.statusMSG = ""});

  static Future<StreamProvider> fetch(String videoId) async {
    // LAYER 1: YOUTUBE EXPLODE WITH ANDROID_VR & IOS CLIENTS (requireWatchPage: false)
    // Strictly audio-only streams (itag 140, 251, 139, 250, 249) without video container overhead or 403 blocks
    final yt = YoutubeExplode();
    try {
      StreamManifest? res;
      try {
        res = await yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [YoutubeApiClient.androidVr],
          requireWatchPage: false,
        );
      } catch (_) {
        try {
          res = await yt.videos.streamsClient.getManifest(
            videoId,
            ytClients: [YoutubeApiClient.ios],
            requireWatchPage: false,
          );
        } catch (_) {}
      }

      if (res != null) {
        final List<Audio> allAudio = [];

        // Strictly Audio-only formats (itag 140 AAC, 251 Opus, 139, 250, 249)
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

        if (allAudio.isNotEmpty) {
          return StreamProvider(
            playable: true,
            statusMSG: "OK",
            audioFormats: allAudio,
          );
        }
      }
    } catch (_) {
    } finally {
      yt.close();
    }

    // LAYER 2: DIRECT INNERTUBE MOBILE API (ZERO WATCH-PAGE CALLS)
    try {
      final directAudio = await _fetchDirectInnertube(videoId);
      if (directAudio != null && directAudio.isNotEmpty) {
        return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: directAudio,
        );
      }
    } catch (_) {}

    // LAYER 3: PIPED PUBLIC API FALLBACK (EMERGENCY FAILSAFE)
    try {
      final pipedAudio = await _fetchPipedFallback(videoId);
      if (pipedAudio != null && pipedAudio.isNotEmpty) {
        return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: pipedAudio,
        );
      }
    } catch (_) {}

    return StreamProvider(
      playable: false,
      statusMSG: "No audio stream available",
    );
  }

  // LAYER 1 HELPER: Direct Innertube Mobile API with Client Rotation
  static Future<List<Audio>?> _fetchDirectInnertube(String videoId) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    final clients = [
      // Client 1: IOS (Highest reliability, direct URLs with Google API key)
      {
        'url':
            'https://www.youtube.com/youtubei/v1/player?key=AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc&prettyPrint=false',
        'headers': {
          'Content-Type': 'application/json',
          'User-Agent':
              'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
          'X-YouTube-Client-Name': '5',
          'X-YouTube-Client-Version': '20.10.4',
          'Origin': 'https://www.youtube.com',
        },
        'body': {
          "videoId": videoId,
          "context": {
            "client": {
              "clientName": "IOS",
              "clientVersion": "20.10.4",
              "deviceMake": "Apple",
              "deviceModel": "iPhone16,2",
              "userAgent":
                  "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
              "hl": "en",
              "platform": "MOBILE",
              "osName": "IOS",
              "osVersion": "18.1.0.22B83",
              "timeZone": "UTC",
              "gl": "US",
              "utcOffsetMinutes": 0
            }
          }
        }
      },
      // Client 2: ANDROID_VR
      {
        'url': 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        'headers': {
          'Content-Type': 'application/json',
          'User-Agent':
              'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; en_US; Quest 2; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
          'X-YouTube-Client-Name': '28',
          'X-YouTube-Client-Version': '1.56.21',
          'Origin': 'https://www.youtube.com',
        },
        'body': {
          "videoId": videoId,
          "context": {
            "client": {
              "clientName": "ANDROID_VR",
              "clientVersion": "1.56.21",
              "androidSdkVersion": 32,
              "hl": "en",
              "gl": "US"
            }
          }
        }
      },
    ];

    try {
      for (final c in clients) {
        try {
          final uri = Uri.parse(c['url'] as String);
          final req = await client.postUrl(uri).timeout(const Duration(seconds: 5));
          final headers = c['headers'] as Map<String, String>;
          headers.forEach((k, v) => req.headers.set(k, v));
          req.write(jsonEncode(c['body']));

          final res = await req.close().timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final resBody = await res.transform(utf8.decoder).join();
            final json = jsonDecode(resBody) as Map<String, dynamic>;
            final status = json['playabilityStatus']?['status'];
            if (status == 'OK' && json['streamingData'] != null) {
              final parsed = _parseInnertubeStreamingData(json);
              if (parsed.isNotEmpty) {
                return parsed;
              }
            }
          }
        } catch (_) {
          // Try next client in rotation
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

  static List<Audio> _parseInnertubeStreamingData(Map<String, dynamic> data) {
    final List<Audio> allAudio = [];
    final streamingData = data['streamingData'];
    if (streamingData == null) return allAudio;

    final adaptiveFormats = streamingData['adaptiveFormats'] as List? ?? [];
    final playerLoudness = (data['playerConfig']?['audioConfig']?['loudnessDb'] as num?)?.toDouble() ?? 0.0;

    for (final f in adaptiveFormats) {
      if (f is! Map) continue;
      final url = f['url'] as String?;
      if (url == null || url.isEmpty) continue;

      final mimeType = f['mimeType'] as String? ?? '';
      final itag = f['itag'] as int? ?? 0;

      // Strictly audio-only streams (e.g. audio/mp4 itag 140/139, audio/webm itag 251/250/249)
      if (mimeType.startsWith('audio/')) {
        final codec = mimeType.contains('mp')
            ? Codec.mp4a
            : Codec.opus;
        final bitrate = (f['bitrate'] as num?)?.toInt() ?? 128000;
        final duration = int.tryParse(f['approxDurationMs']?.toString() ?? '') ?? 0;
        final size = int.tryParse(f['contentLength']?.toString() ?? '') ?? 0;
        final loudnessDb = (f['loudnessDb'] as num?)?.toDouble() ?? playerLoudness;

        allAudio.add(Audio(
          itag: itag,
          audioCodec: codec,
          bitrate: bitrate,
          duration: duration,
          loudnessDb: loudnessDb,
          url: url,
          size: size,
        ));
      }
    }
    return allAudio;
  }

  // LAYER 3 HELPER: Piped Public API Fallback
  static Future<List<Audio>?> _fetchPipedFallback(String videoId) async {
    final instances = [
      "https://pipedapi.kavin.rocks",
      "https://pipedapi.tokhmi.xyz",
      "https://api.piped.private.coffee",
      "https://pipedapi.leptons.xyz",
    ];

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 4);

    try {
      for (final base in instances) {
        try {
          final req = await client
              .getUrl(Uri.parse("$base/streams/$videoId"))
              .timeout(const Duration(seconds: 4));
          final res = await req.close().timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            final json = jsonDecode(body) as Map<String, dynamic>;
            final audioStreams = json['audioStreams'] as List? ?? [];
            final List<Audio> pipedAudio = [];
            for (final item in audioStreams) {
              if (item is! Map) continue;
              final url = item['url'] as String?;
              if (url == null || url.isEmpty) continue;
              final mime = (item['format'] ?? item['mimeType'] ?? '').toString();
              final itag = (item['itag'] as num?)?.toInt() ?? 140;
              final bitrate = (item['bitrate'] as num?)?.toInt() ?? 128000;
              final size = (item['contentLength'] as num?)?.toInt() ?? 0;
              final codec = mime.contains('mp') ? Codec.mp4a : Codec.opus;

              pipedAudio.add(Audio(
                itag: itag,
                audioCodec: codec,
                bitrate: bitrate,
                duration: 0,
                loudnessDb: 0.0,
                url: url,
                size: size,
              ));
            }
            if (pipedAudio.isNotEmpty) {
              return pipedAudio;
            }
          }
        } catch (_) {
          // Try next instance
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

  Audio? get highestQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
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
