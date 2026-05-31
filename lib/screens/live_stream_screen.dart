import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/platform_preset.dart';
import '../services/agora_service.dart';
import '../models/platform_config.dart';

class LiveStreamScreen extends StatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late AgoraService _agoraService;

  bool _isInitialized = false;
  bool _isInitializing = true;
  String? _initError;

  bool _isHost = true;
  bool _isLiveActive = false;
  bool _isJoining = false;
  int? _remoteUid;

  final Map<String, bool> _rtmpStatus = {};
  final Map<String, PlatformConfig> _platforms = {};
  final List<PlatformConfig> _enabledPlatforms = [];

  final TextEditingController _platformNameController = TextEditingController();
  final TextEditingController _rtmpUrlController = TextEditingController();
  final TextEditingController _streamKeyController = TextEditingController();

  String _statusMessage = "Initializing...";
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = "Initializing Agora SDK...";
    });

    try {
      _agoraService = AgoraService();

      _setupCallbacks();

      final initialized = await _agoraService.initialize();

      if (initialized && mounted) {
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
          _statusMessage = "Ready to go live";
          _statusColor = Colors.green;
        });

        await _loadSavedPlatforms();

        Fluttertoast.showToast(msg: "App initialized successfully");
      } else {
        throw Exception("Failed to initialize Agora SDK");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
          _statusMessage = "Initialization failed: $e";
          _statusColor = Colors.red;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize: $e')),
        );
      }
    }
  }

  void _setupCallbacks() {
    if (_agoraService == null) return;

    _agoraService.onRtmpStatusChanged = (isConnected) {
      if (mounted) {
        setState(() {
          if (isConnected) {
            _statusMessage = "Cross-live connected successfully";
            _statusColor = Colors.green;
            Fluttertoast.showToast(msg: "RTMP stream connected");
          } else {
            _statusMessage = "Cross-live connection failed";
            _statusColor = Colors.red;
            Fluttertoast.showToast(msg: "RTMP stream failed", backgroundColor: Colors.red);
          }
        });
      }
    };

    _agoraService.onError = (error) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error: $error";
          _statusColor = Colors.red;
        });
        Fluttertoast.showToast(msg: error, backgroundColor: Colors.red);
      }
    };

    _agoraService.onRemoteUserJoined = (uid) {
      if (mounted) {
        setState(() {
          _remoteUid = uid;
          _statusMessage = "Audience joined the live stream";
        });
        Fluttertoast.showToast(msg: "New audience joined");
      }
    };

    _agoraService.onRemoteUserLeft = (uid) {
      if (mounted) {
        setState(() {
          _remoteUid = null;
        });
      }
    };

    _agoraService.onConnectionLost = () {
      if (mounted) {
        setState(() {
          _statusMessage = "Connection lost, reconnecting...";
          _statusColor = Colors.orange;
        });
      }
    };

    _agoraService.onConnectionRecovered = () {
      if (mounted) {
        setState(() {
          _statusMessage = "Connection recovered";
          _statusColor = Colors.green;
        });
      }
    };
  }

  Future<void> _loadSavedPlatforms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final platformsJson = prefs.getStringList('platforms') ?? [];

      if (mounted) {
        setState(() {
          for (var json in platformsJson) {
            final platform = PlatformConfig.fromJson(jsonDecode(json));
            _platforms[platform.id] = platform;
            if (platform.isEnabled) {
              _enabledPlatforms.add(platform);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading platforms: $e');
    }
  }

  Future<void> _savePlatform(PlatformConfig platform) async {
    final prefs = await SharedPreferences.getInstance();
    final platformsList = _platforms.values.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('platforms', platformsList);
  }

  Future<void> _addPlatform() async {
    if (_platformNameController.text.isEmpty ||
        _rtmpUrlController.text.isEmpty ||
        _streamKeyController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields");
      return;
    }

    final platform = PlatformConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      platformName: _platformNameController.text,
      rtmpUrl: _rtmpUrlController.text,
      streamKey: _streamKeyController.text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _platforms[platform.id] = platform;
      _enabledPlatforms.add(platform);
    });

    await _savePlatform(platform);

    // Clear controllers
    _platformNameController.clear();
    _rtmpUrlController.clear();
    _streamKeyController.clear();

    // Close dialog
    Navigator.pop(context);
    Fluttertoast.showToast(msg: "Platform added successfully");
  }

  Future<void> _startLive() async {
    // Check if initialized
    if (!_isInitialized) {
      Fluttertoast.showToast(msg: "App not initialized yet. Please wait.");
      return;
    }

    setState(() {
      _isJoining = true;
      _statusMessage = "Starting live stream...";
      _statusColor = Colors.orange;
    });

    try {
      await _agoraService.startLiveAsHost();

      if (mounted) {
        setState(() {
          _isLiveActive = true;
          _statusMessage = "Live in progress";
          _statusColor = Colors.red;
        });
      }

      // Start RTMP streams for all enabled platforms
      await _startCrossLiveStreaming();

      Fluttertoast.showToast(msg: "Live stream started successfully");
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Failed to start live: $e";
          _statusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _startCrossLiveStreaming() async {
    for (var platform in _enabledPlatforms) {
      if (mounted) {
        setState(() {
          _rtmpStatus[platform.id] = false;
          _statusMessage = "Connecting to ${platform.platformName}...";
        });
      }

      final success = await _agoraService.startRtmpStream(
        platform.rtmpUrl,
        platform.streamKey,
      );

      if (mounted) {
        setState(() {
          _rtmpStatus[platform.id] = success;
          if (!success) {
            _statusMessage = "Failed to connect to ${platform.platformName}";
          }
        });
      }

      if (success) {
        Fluttertoast.showToast(msg: "Connected to ${platform.platformName}");
      }
    }
  }

  Future<void> _joinAsAudience() async {
    if (!_isInitialized) {
      Fluttertoast.showToast(msg: "App not initialized yet. Please wait.");
      return;
    }

    setState(() {
      _isJoining = true;
      _statusMessage = "Joining as audience...";
    });

    try {
      await _agoraService.joinAsAudience();

      if (mounted) {
        setState(() {
          _isLiveActive = true;
          _statusMessage = "Watching live stream";
          _statusColor = Colors.blue;
        });
      }

      Fluttertoast.showToast(msg: "Joined as audience");
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Failed to join: $e";
          _statusColor = Colors.red;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _stopLive() async {
    setState(() {
      _statusMessage = "Ending live stream...";
    });

    // Stop all RTMP streams
    for (var platform in _enabledPlatforms) {
      await _agoraService.stopRtmpStream(platform.rtmpUrl, platform.streamKey);
    }

    // Stop Agora live
    await _agoraService.stopLive();

    if (mounted) {
      setState(() {
        _isLiveActive = false;
        _remoteUid = null;
        _rtmpStatus.clear();
        _statusMessage = "Live ended";
        _statusColor = Colors.grey;
      });
    }

    Fluttertoast.showToast(msg: "Live stream ended");
  }

  // Add this method to your LiveStreamScreen class

  void _showAddPlatformWithPresetsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Streaming Platform'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Platform presets
              const Text(
                'Quick Setup with Presets',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: PlatformPreset.presets.length,
                  itemBuilder: (context, index) {
                    final preset = PlatformPreset.presets[index];
                    return ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(preset.name),
                      subtitle: Text(preset.rtmpUrl),
                      trailing: IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () {
                          // Show info dialog
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(preset.name),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('RTMP URL: ${preset.rtmpUrl}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'To get stream key:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(preset.documentationUrl),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(_),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      onTap: () {
                        // Auto-fill the form
                        _platformNameController.text = preset.name;
                        _rtmpUrlController.text = preset.rtmpUrl;
                        Navigator.pop(context); // Close preset dialog
                        _showStreamKeyInputDialog(); // Show stream key input
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              // const Text('Or Manual Setup'),
              // const SizedBox(height: 8),
              // TextField(
              //   controller: _platformNameController,
              //   decoration: const InputDecoration(
              //     labelText: 'Platform Name',
              //     border: OutlineInputBorder(),
              //   ),
              // ),
              // const SizedBox(height: 8),
              // TextField(
              //   controller: _rtmpUrlController,
              //   decoration: const InputDecoration(
              //     labelText: 'RTMP URL',
              //     border: OutlineInputBorder(),
              //   ),
              // ),
              // const SizedBox(height: 8),
              // TextField(
              //   controller: _streamKeyController,
              //   decoration: const InputDecoration(
              //     labelText: 'Stream Key',
              //     border: OutlineInputBorder(),
              //     helperText: 'Find this in your platform\'s live dashboard',
              //   ),
              // ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addPlatform,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showStreamKeyInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Stream Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How to get your stream key:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Go to your platform\'s live dashboard\n'
                  '2. Look for "Stream Key" or "Ingest Settings"\n'
                  '3. Copy the key (it looks like a long string)\n'
                  '4. Paste it below',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _streamKeyController,
              decoration: const InputDecoration(
                labelText: 'Stream Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addPlatform();
            },
            child: const Text('Add Platform'),
          ),
        ],
      ),
    );
  }

  void _showAddPlatformDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Streaming Platform'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _platformNameController,
                decoration: const InputDecoration(
                  labelText: 'Platform Name',
                  hintText: 'e.g., YouTube, Facebook',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rtmpUrlController,
                decoration: const InputDecoration(
                  labelText: 'RTMP URL',
                  hintText: 'rtmp://a.rtmp.youtube.com/live2',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _streamKeyController,
                decoration: const InputDecoration(
                  labelText: 'Stream Key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addPlatform,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showManagePlatformsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Manage Platforms'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: _platforms.isEmpty
                  ? const Center(
                child: Text('No platforms added yet.\nTap + to add one.'),
              )
                  : ListView.builder(
                itemCount: _platforms.length,
                itemBuilder: (context, index) {
                  final platform = _platforms.values.elementAt(index);
                  final isEnabled = _enabledPlatforms.contains(platform);

                  return ListTile(
                    leading: Icon(
                      isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isEnabled ? Colors.green : Colors.grey,
                    ),
                    title: Text(platform.platformName),
                    subtitle: Text(platform.rtmpUrl),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setStateDialog(() {
                          _platforms.remove(platform.id);
                          _enabledPlatforms.remove(platform);
                        });
                        _savePlatform(platform);
                      },
                    ),
                    onTap: () {
                      setStateDialog(() {
                        if (isEnabled) {
                          _enabledPlatforms.remove(platform);
                        } else {
                          _enabledPlatforms.add(platform);
                        }
                      });
                      _savePlatform(platform);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    if (_agoraService != null) {
      _agoraService.dispose();
    }
    _platformNameController.dispose();
    _rtmpUrlController.dispose();
    _streamKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streaming Studio'),
        elevation: 2,
        actions: [
          if (_isInitialized && _isHost && !_isLiveActive)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showManagePlatformsDialog,
              tooltip: 'Manage Platforms',
            ),
          if (_isInitialized && _isHost && !_isLiveActive)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddPlatformWithPresetsDialog,
              tooltip: 'Add Platform',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show loading indicator while initializing
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitFadingCircle(
              color: Colors.blue,
              size: 50,
            ),
            SizedBox(height: 20),
            Text(
              'Initializing Agora SDK...',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Please wait',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show error if initialization failed
    if (_initError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              'Initialization Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _initError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _initError = null;
                  _isInitializing = true;
                });
                _initializeApp();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Initialization'),
            ),
          ],
        ),
      );
    }

    // Show main UI when initialized
    return Column(
      children: [
        // Video View
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.black,
            child: _isLiveActive
                ? _isHost
                ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _agoraService.engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
                : _remoteUid != null
                ? AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _agoraService.engine,
                canvas: VideoCanvas(uid: _remoteUid),
                connection: const RtcConnection(
                  channelId: AgoraService.channelName,
                ),
              ),
            )
                : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitFadingCircle(
                    color: Colors.white,
                    size: 50,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Waiting for host to start...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.live_tv,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active live stream',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap "Go Live" to start broadcasting',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Live Status Bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: _statusColor.withOpacity(0.1),
          child: Row(
            children: [
              if (_isLiveActive && _isHost)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              if (_isLiveActive && _isHost)
                const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
              if (_isJoining)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),

        // RTMP Status Cards
        if (_isLiveActive && _isHost && _enabledPlatforms.isNotEmpty)
          Container(
            height: 100,
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _enabledPlatforms.length,
              itemBuilder: (context, index) {
                final platform = _enabledPlatforms[index];
                final isConnected = _rtmpStatus[platform.id] ?? false;

                return Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isConnected ? Icons.link : Icons.link_off,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        platform.platformName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isConnected ? 'Connected' : 'Failed',
                        style: TextStyle(
                          fontSize: 12,
                          color: isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),


        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              if (!_isLiveActive) ...[
                // Role Selection
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Host'),
                      icon: Icon(Icons.mic),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Audience'),
                      icon: Icon(Icons.visibility),
                    ),
                  ],
                  selected: {_isHost},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _isHost = selection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLiveActive
                          ? _stopLive
                          : (_isHost ? _startLive : _joinAsAudience),
                      icon: Icon(_isLiveActive ? Icons.stop : Icons.play_arrow),
                      label: Text(_isLiveActive
                          ? 'End Live'
                          : (_isHost ? 'Go Live' : 'Join Live')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLiveActive ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (!_isLiveActive && _isHost && _platforms.isEmpty)
                    const SizedBox(width: 12),
                  if (!_isLiveActive && _isHost && _platforms.isEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showAddPlatformWithPresetsDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Platform'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),

              if (!_isLiveActive && _isHost && _platforms.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showAddPlatformWithPresetsDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Platform'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}