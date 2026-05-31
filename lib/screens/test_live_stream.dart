import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TestLiveStreamScreen extends StatefulWidget {
  const TestLiveStreamScreen({super.key});

  @override
  State<TestLiveStreamScreen> createState() => _TestLiveStreamScreenState();
}

class _TestLiveStreamScreenState extends State<TestLiveStreamScreen> {
  // Test state variables
  bool _isLiveActive = false;
  bool _isHost = true;
  String _statusMessage = "Ready to test";
  Color _statusColor = Colors.grey;
  List<String> _connectedPlatforms = [];

  // Test platforms
  final List<TestPlatform> _testPlatforms = [
    TestPlatform(name: "YouTube Test", rtmp: "rtmp://test.youtube.com/live", key: "test123"),
    TestPlatform(name: "Facebook Test", rtmp: "rtmp://test.facebook.com/rtmp", key: "test456"),
    TestPlatform(name: "Twitch Test", rtmp: "rtmp://test.twitch.tv/app", key: "test789"),
  ];

  List<TestPlatform> _selectedPlatforms = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streaming Test App'),
        backgroundColor: Colors.green,
        actions: [
          if (_isLiveActive)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildVideoPreview(),

          // Status Bar
          _buildStatusBar(),

          // Live Controls
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildRoleSelector(),

                  const SizedBox(height: 20),

                  _buildPlatformSelector(),

                  const SizedBox(height: 20),

                  _buildActionButtons(),

                  const SizedBox(height: 20),

                  if (_connectedPlatforms.isNotEmpty)
                    _buildConnectedPlatforms(),

                  _buildTestGuide(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      height: 250,
      color: Colors.black,
      child: Center(
        child: _isLiveActive
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam, size: 60, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              _isHost ? "🎥 Broadcasting Live" : "📺 Watching Live Stream",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (_isHost && _connectedPlatforms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  children: _connectedPlatforms.map((platform) => Padding(
                    padding: const EdgeInsets.all(4),
                    child: Chip(
                      label: Text(platform),
                      backgroundColor: Colors.green,
                      labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  )).toList(),
                ),
              ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.live_tv, size: 60, color: Colors.grey),
            const SizedBox(height: 10),
            Text(
              "No active stream",
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 5),
            Text(
              "Tap 'Start Test Stream' to begin",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: _statusColor.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
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
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: _isHost ? Colors.green : Colors.grey[200],
            child: InkWell(
              onTap: !_isLiveActive ? () {
                setState(() {
                  _isHost = true;
                  _statusMessage = "Host mode selected";
                  _statusColor = Colors.blue;
                });
              } : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.mic, color: _isHost ? Colors.white : Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      "Host",
                      style: TextStyle(
                        color: _isHost ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Go Live",
                      style: TextStyle(
                        color: _isHost ? Colors.white70 : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            color: !_isHost ? Colors.blue : Colors.grey[200],
            child: InkWell(
              onTap: !_isLiveActive ? () {
                setState(() {
                  _isHost = false;
                  _statusMessage = "Audience mode selected";
                  _statusColor = Colors.blue;
                });
              } : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.visibility, color: !_isHost ? Colors.white : Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      "Audience",
                      style: TextStyle(
                        color: !_isHost ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Join Live",
                      style: TextStyle(
                        color: !_isHost ? Colors.white70 : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Platforms to Stream To:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._testPlatforms.map((platform) => Card(
          child: CheckboxListTile(
            title: Text(platform.name),
            subtitle: Text("RTMP: ${platform.rtmp}"),
            secondary: Icon(
              _selectedPlatforms.contains(platform)
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: _selectedPlatforms.contains(platform)
                  ? Colors.green
                  : Colors.grey,
            ),
            value: _selectedPlatforms.contains(platform),
            onChanged: !_isLiveActive ? (value) {
              setState(() {
                if (value == true) {
                  _selectedPlatforms.add(platform);
                } else {
                  _selectedPlatforms.remove(platform);
                }
                _statusMessage = "${_selectedPlatforms.length} platform(s) selected";
              });
            } : null,
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLiveActive ? _stopLive : (_isHost ? _startLive : _joinLive),
            icon: Icon(_isLiveActive ? Icons.stop : Icons.play_arrow),
            label: Text(
              _isLiveActive
                  ? "End Live Stream"
                  : (_isHost ? "Start Live Stream" : "Join as Audience"),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLiveActive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (!_isLiveActive && _isHost && _selectedPlatforms.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "⚠️ Select at least one platform to stream to",
              style: TextStyle(color: Colors.orange[700], fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildConnectedPlatforms() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.link, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  "Connected Platforms:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _connectedPlatforms.map((platform) => Chip(
                label: Text(platform),
                backgroundColor: Colors.green,
                labelStyle: const TextStyle(color: Colors.white),
                avatar: const Icon(Icons.check, color: Colors.white, size: 16),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestGuide() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Test Guide",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "✅ This is a SIMULATED test environment\n"
                  "✅ No real streaming credentials needed\n"
                  "✅ Test all features without YouTube verification\n"
                  "✅ Watch how the app behaves when live\n"
                  "✅ Simulates successful RTMP connections\n\n"
                  "To test:\n"
                  "1. Select 'Host' mode\n"
                  "2. Check platforms (YouTube, Facebook, Twitch)\n"
                  "3. Tap 'Start Live Stream'\n"
                  "4. Watch the status change to 'Connected'\n"
                  "5. See green badges appear\n"
                  "6. Tap 'End Live Stream' to stop",
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ============= TEST FUNCTIONS =============

  Future<void> _startLive() async {
    if (_selectedPlatforms.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please select at least one platform",
        backgroundColor: Colors.orange,
      );
      return;
    }

    setState(() {
      _isLiveActive = true;
      _statusMessage = "Starting live stream...";
      _statusColor = Colors.orange;
    });

    // Simulate starting live stream
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _statusMessage = "Live stream started! Connecting to platforms...";
    });

    // Simulate connecting to each platform
    for (var platform in _selectedPlatforms) {
      setState(() {
        _statusMessage = "Connecting to ${platform.name}...";
      });

      // Simulate connection delay
      await Future.delayed(const Duration(milliseconds: 800));

      setState(() {
        _connectedPlatforms.add(platform.name);
        _statusMessage = "✅ Connected to ${platform.name}";
      });

      Fluttertoast.showToast(
        msg: "Connected to ${platform.name}",
        backgroundColor: Colors.green,
      );
    }

    setState(() {
      _statusMessage = "🎥 LIVE - Streaming to ${_connectedPlatforms.length} platform(s)";
      _statusColor = Colors.red;
    });
  }

  Future<void> _joinLive() async {
    setState(() {
      _isLiveActive = true;
      _statusMessage = "Joining live stream...";
      _statusColor = Colors.orange;
    });

    // Simulate joining
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _statusMessage = "📺 Watching live stream";
      _statusColor = Colors.blue;
    });

    Fluttertoast.showToast(msg: "Joined as audience member");
  }

  Future<void> _stopLive() async {
    setState(() {
      _statusMessage = "Ending live stream...";
      _statusColor = Colors.orange;
    });

    // Simulate stopping
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLiveActive = false;
      _connectedPlatforms.clear();
      _selectedPlatforms.clear();
      _statusMessage = "Live stream ended";
      _statusColor = Colors.grey;
    });

    Fluttertoast.showToast(msg: "Live stream ended");
  }
}

class TestPlatform {
  final String name;
  final String rtmp;
  final String key;

  TestPlatform({
    required this.name,
    required this.rtmp,
    required this.key,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestPlatform && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}