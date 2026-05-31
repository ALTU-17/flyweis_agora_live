class PlatformPreset {
  final String name;
  final String rtmpUrl;
  final String documentationUrl;

  const PlatformPreset({
    required this.name,
    required this.rtmpUrl,
    required this.documentationUrl,
  });

  static const List<PlatformPreset> presets = [
    PlatformPreset(
      name: 'YouTube Live',
      rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2',
      documentationUrl: 'https://support.google.com/youtube/answer/2907883',
    ),
    PlatformPreset(
      name: 'Facebook Live',
      rtmpUrl: 'rtmps://live-api-s.facebook.com:443/rtmp/',
      documentationUrl: 'https://www.facebook.com/facebookmedia/get-started/live',
    ),
    PlatformPreset(
      name: 'Instagram Live',
      rtmpUrl: 'rtmps://live-upload.instagram.com/rtmp/',
      documentationUrl: 'https://developers.facebook.com/docs/instagram-platform/live-api',
    ),
  ];
}
