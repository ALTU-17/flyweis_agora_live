class PlatformConfig {
  final String id;
  final String platformName;
  final String rtmpUrl;
  final String streamKey;
  final bool isEnabled;
  final DateTime createdAt;

  PlatformConfig({
    required this.id,
    required this.platformName,
    required this.rtmpUrl,
    required this.streamKey,
    this.isEnabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'platformName': platformName,
    'rtmpUrl': rtmpUrl,
    'streamKey': streamKey,
    'isEnabled': isEnabled,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PlatformConfig.fromJson(Map<String, dynamic> json) => PlatformConfig(
    id: json['id'],
    platformName: json['platformName'],
    rtmpUrl: json['rtmpUrl'],
    streamKey: json['streamKey'],
    isEnabled: json['isEnabled'],
    createdAt: DateTime.parse(json['createdAt']),
  );

  String get fullRtmpUrl => '$rtmpUrl/$streamKey';
}

