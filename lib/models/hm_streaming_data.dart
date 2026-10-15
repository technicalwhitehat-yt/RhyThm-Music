import 'package:rhythm_music/services/stream_service.dart'show Audio;

class HMStreamingData {
  final bool playable;
  final String statusMSG;
  final Audio? lowQualityAudio;
  final Audio? highQualityAudio;
  int qualityIndex = 1;
  HMStreamingData({
    required this.playable,
    required this.statusMSG,
    this.lowQualityAudio,
    this.highQualityAudio,
  });

  setQualityIndex(int index) {
    qualityIndex = index;
  }

  Audio? get audio => qualityIndex == 0 ? lowQualityAudio : highQualityAudio;

  factory HMStreamingData.fromJson(json) {
    if(!json['playable']) {
      return HMStreamingData(
        playable: false,
        statusMSG: json['statusMSG'],
      );
    }
    final lowQualityAudio = json['lowQualityAudio'] != null
        ? Audio.fromJson(json['lowQualityAudio'])
        : null;
    final highQualityAudio = json['highQualityAudio'] != null
        ? Audio.fromJson(json['highQualityAudio'])
        : null;
    return HMStreamingData(
        playable: json['playable'] ?? true,
        statusMSG: json['statusMSG'] ?? "OK",
        lowQualityAudio: lowQualityAudio ?? highQualityAudio,
        highQualityAudio: highQualityAudio ?? lowQualityAudio);
  }

  Map<String, dynamic> toJson() => {
        "playable": playable,
        "statusMSG": statusMSG,
        "lowQualityAudio": lowQualityAudio?.toJson(),
        "highQualityAudio": highQualityAudio?.toJson(),
      };
}
