import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  late RtcEngine _engine;
  bool _isInitialized = false;
  bool _isInChannel = false;

  Function(bool isConnected)? onRtmpStatusChanged;
  Function(String error)? onError;
  Function(int remoteUid)? onRemoteUserJoined;
  Function(int remoteUid)? onRemoteUserLeft;
  Function()? onConnectionLost;
  Function()? onConnectionRecovered;

  RtcEngine get engine => _engine;
  bool get isInChannel => _isInChannel;

  final String appId = "15814dfdd1ff44fb897b56d92b3047db";

  // Dear flyweis Team:  This is Agora Temp Token expire in 24 hrs so pls renew it...
  final String token = "007eJxTYOB9Mf/XORGJdVxx3YJvJk/bHPqfM2XCja1Xdp7mWq++Ij1DgcHQ1MLQJCUtJcUwLc3EJC3JwtI8ydQsxdIoydjAxDwlqVtHJqshkJEhYHMwCyMDBIL4fAxuOZXlqZnFAUX5WanJJQwMAOUxI9M=";

  static const String channelName = "FlyweisProject";



  Future<bool> initialize() async {
    try {
      await [Permission.microphone, Permission.camera].request();

      _engine = createAgoraRtcEngine();

      await _engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );

      await _engine.enableVideo();
      await _engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 30,
          bitrate: 1500,
        ),
      );

      _registerEventHandlers();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error: $e');
      onError?.call('Failed to initialize: $e');
      return false;
    }
  }

  void _registerEventHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Joined channel');
          _isInChannel = true;
        },

        onLeaveChannel: (connection, stats) {
          debugPrint('Left channel');
          _isInChannel = false;
        },

        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('User joined: $remoteUid');
          onRemoteUserJoined?.call(remoteUid);
        },

        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('User left: $remoteUid');
          onRemoteUserLeft?.call(remoteUid);
        },

        // FIXED VERSION - No enum errors
        onRtmpStreamingStateChanged: (url, state, errorCode) {
          debugPrint('RTMP State: $state');

          // Convert to int for checking
          Object stateValue = state is int ? state : int.tryParse(state.toString()) ?? -1;

          if (stateValue == 2) { // Running state
            onRtmpStatusChanged?.call(true);
            debugPrint('✅ RTMP Connected');
          }
          else if (stateValue == 4) { // Failure state
            String errorMsg = 'RTMP Failed';
            if (errorCode != null) {
              Object errorValue = errorCode is int ? errorCode : int.tryParse(errorCode.toString()) ?? 0;
              if (errorValue == 2) errorMsg = 'Invalid stream key';
              if (errorValue == 3) errorMsg = 'Connection timeout';
            }
            onError?.call(errorMsg);
            onRtmpStatusChanged?.call(false);
            debugPrint('❌ RTMP Failed');
          }
        },

        onConnectionStateChanged: (connection, state, reason) {
          if (state == ConnectionStateType.connectionStateReconnecting) {
            onConnectionLost?.call();
          } else if (state == ConnectionStateType.connectionStateConnected) {
            onConnectionRecovered?.call();
          }
        },

        onError: (err, msg) {
          debugPrint('Error: $msg');
          onError?.call(msg);
        },
      ),
    );
  }

  Future<void> startLiveAsHost() async {
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.startPreview();
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> joinAsAudience() async {
    await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<bool> startRtmpStream(String rtmpUrl, String streamKey) async {
    try {
      final fullUrl = '$rtmpUrl/$streamKey';
      final transcoding = LiveTranscoding(
        width: 720,
        height: 1280,
        videoBitrate: 1500,
        videoFramerate: 30,
        audioBitrate: 48,
        audioSampleRate: AudioSampleRateType.audioSampleRate48000,
        audioChannels: 2,
        lowLatency: true,
        backgroundColor: 0x000000,
        userCount: 0,
        transcodingUsers: [],
      );

      await _engine.startRtmpStreamWithTranscoding(
        url: fullUrl,
        transcoding: transcoding,
      );
      return true;
    } catch (e) {
      onError?.call('Failed to start RTMP: $e');
      return false;
    }
  }

  Future<void> stopRtmpStream(String rtmpUrl, String streamKey) async {
    try {
      final fullUrl = '$rtmpUrl/$streamKey';
      await _engine.stopRtmpStream(fullUrl);
    } catch (e) {
      debugPrint('Stop RTMP error: $e');
    }
  }

  Future<void> stopLive() async {
    await _engine.leaveChannel();
    _isInChannel = false;
  }

  void dispose() {
    _engine.release();
    _isInitialized = false;
    _isInChannel = false;
  }
}