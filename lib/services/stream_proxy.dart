import 'dart:async';
import 'dart:io';
import '../utils/app_logger.dart';

class StreamMetadata {
  final String originalUrl;
  final int totalSize;
  final String mimeType;

  StreamMetadata({
    required this.originalUrl,
    required this.totalSize,
    required this.mimeType,
  });
}

class StreamProxy {
  static HttpServer? _server;
  static int _port = 0;
  static final Map<String, StreamMetadata> _activeStreams = {};

  // Active streaming sessions per songId (for seek / skip cancellation)
  static final Map<String, _ActiveSession> _activeSessions = {};
  static int _sessionCounter = 0;

  static int get port => _port;
  static bool get isRunning => _server != null;

  static Future<void> ensureStarted() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _server!.listen(_handleRequest, onError: (e) {});
    } catch (_) {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8099);
        _port = 8099;
        _server!.listen(_handleRequest, onError: (e) {});
      } catch (_) {
        _port = 0;
      }
    }
  }

  static String getProxyUrl({
    required String songId,
    required String originalUrl,
    required int totalSize,
    required String mimeType,
  }) {
    _activeStreams[songId] = StreamMetadata(
      originalUrl: originalUrl,
      totalSize: totalSize,
      mimeType: mimeType,
    );
    return "http://127.0.0.1:$_port/stream?id=$songId";
  }

  static Future<void> _handleRequest(HttpRequest request) async {
    final uri = request.uri;
    if (uri.path != '/stream') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final songId = uri.queryParameters['id'];
    AppLogger.info("StreamProxy: ${request.method} request for $songId (Range: ${request.headers.value(HttpHeaders.rangeHeader)})", tag: "StreamProxy");
    StreamMetadata? metadata =
        songId != null ? _activeStreams[songId] : null;

    if (metadata == null) {
      final fallbackUrl = uri.queryParameters['url'];
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
        final decodedUrl = Uri.decodeComponent(fallbackUrl);
        final size = int.tryParse(uri.queryParameters['size'] ?? '0') ?? 0;
        final type = uri.queryParameters['type'] ?? 'audio/mp4';
        metadata = StreamMetadata(
          originalUrl: decodedUrl,
          totalSize: size,
          mimeType: type,
        );
      }
    }

    if (metadata == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final originalUrl = metadata.originalUrl;
    int totalSize = metadata.totalSize;

    // 1. Instant HEAD response (0ms probe, ExoPlayer duration calculation passes immediately)
    if (request.method == 'HEAD') {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, metadata.mimeType);
      if (totalSize > 0) {
        request.response.headers
            .set(HttpHeaders.contentLengthHeader, totalSize.toString());
      }
      await request.response.close();
      return;
    }

    // Only allow GET requests for streaming
    if (request.method != 'GET') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    // 2. Cancel any previous ongoing stream for this songId (prevents seek/skip freezing)
    if (songId != null) {
      final prevSession = _activeSessions.remove(songId);
      prevSession?.cancel();
    }

    final session = _ActiveSession(++_sessionCounter);
    if (songId != null) {
      _activeSessions[songId] = session;
    }

    // 3. Parse incoming Range header from ExoPlayer
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    int start = 0;
    int? end;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final spec = rangeHeader.substring(6).trim();
      final parts = spec.split('-');
      start = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1 && parts[1].isNotEmpty) {
        end = int.tryParse(parts[1]);
      }
    }

    final targetEnd = (end != null && (totalSize <= 0 || end < totalSize))
        ? end
        : (totalSize > 0 ? totalSize - 1 : start + (20 * 1024 * 1024));

    final contentLength = targetEnd - start + 1;

    // 4. Setup Response Headers for ExoPlayer
    request.response.bufferOutput = false; // Stream bytes directly without buffering delay

    if (rangeHeader != null) {
      request.response.statusCode = HttpStatus.partialContent; // 206
      if (totalSize > 0) {
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$targetEnd/$totalSize',
        );
      } else {
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$targetEnd/*',
        );
      }
    } else {
      request.response.statusCode = HttpStatus.ok; // 200
    }

    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, metadata.mimeType);
    request.response.headers
        .set(HttpHeaders.contentLengthHeader, contentLength.toString());

    // 5. Stream from YouTube in 512KB chunks with session cancellation
    const int chunkSize = 524288;
    int currentPos = start;

    try {
      while (currentPos <= targetEnd) {
        if (session.isCancelled) break;

        int chunkEnd = currentPos + chunkSize - 1;
        if (chunkEnd > targetEnd) {
          chunkEnd = targetEnd;
        }

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 8);
        client.autoUncompress = false;
        session.currentClient = client;

        try {
          final chunkUri = Uri.parse(originalUrl);
          final ytReq = await client.getUrl(chunkUri);
          ytReq.headers
              .set(HttpHeaders.rangeHeader, 'bytes=$currentPos-$chunkEnd');
          String ua = 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; Quest 2) gzip';
          if (originalUrl.contains('c=IOS')) {
            ua = 'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)';
          } else if (originalUrl.contains('c=ANDROID_VR')) {
            ua = 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; Quest 2) gzip';
          } else if (originalUrl.contains('c=ANDROID')) {
            ua = 'com.google.android.youtube/19.09.37 (Linux; U; Android 11) gzip';
          } else {
            ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
          }
          ytReq.headers.set(HttpHeaders.userAgentHeader, ua);

          final ytRes = await ytReq.close();
          if (ytRes.statusCode == HttpStatus.ok ||
              ytRes.statusCode == HttpStatus.partialContent) {
            final completer = Completer<void>();
            session.currentCompleter = completer;

            StreamSubscription<List<int>>? subscription;
            bool clientDisconnected = false;

            subscription = ytRes.listen(
              (data) {
                if (session.isCancelled) {
                  subscription?.cancel();
                  if (!completer.isCompleted) completer.complete();
                  return;
                }
                try {
                  request.response.add(data);
                } catch (_) {
                  clientDisconnected = true;
                  subscription?.cancel();
                  if (!completer.isCompleted) completer.complete();
                }
              },
              onDone: () {
                if (!completer.isCompleted) completer.complete();
              },
              onError: (_) {
                if (!completer.isCompleted) completer.complete();
              },
              cancelOnError: true,
            );
            session.currentSub = subscription;

            await completer.future;

            try {
              client.close(force: true);
            } catch (_) {}

            if (clientDisconnected || session.isCancelled) {
              break;
            }

            try {
              await request.response.flush();
            } catch (_) {
              break;
            }

            currentPos = chunkEnd + 1;
          } else {
            AppLogger.error("StreamProxy: YouTube returned status ${ytRes.statusCode} for $songId (chunk: bytes=$currentPos-$chunkEnd)", tag: "StreamProxy");
            await ytRes.drain();
            try {
              client.close(force: true);
            } catch (_) {}
            break;
          }
        } catch (_) {
          try {
            client.close(force: true);
          } catch (_) {}
          break;
        }
      }
    } catch (_) {
      // Disconnection / normal player exit
    } finally {
      if (songId != null && _activeSessions[songId] == session) {
        _activeSessions.remove(songId);
      }
      session.cancel();
      try {
        await request.response.close();
      } catch (_) {}
    }
  }
}

class _ActiveSession {
  final int id;
  bool isCancelled = false;
  HttpClient? currentClient;
  StreamSubscription<List<int>>? currentSub;
  Completer<void>? currentCompleter;

  _ActiveSession(this.id);

  void cancel() {
    isCancelled = true;
    try {
      currentSub?.cancel();
    } catch (_) {}
    try {
      currentClient?.close(force: true);
    } catch (_) {}
    if (currentCompleter != null && !currentCompleter!.isCompleted) {
      currentCompleter!.complete();
    }
  }
}
