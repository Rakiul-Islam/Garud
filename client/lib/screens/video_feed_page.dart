import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:async';

class VideoFeedPage extends StatefulWidget {
  final String serverUrl;
  final String garudId;

  const VideoFeedPage({
    Key? key,
    this.serverUrl = 'https://api.rakiulislam.tech',
    this.garudId = 'garud002',
  }) : super(key: key);

  @override
  _VideoFeedPageState createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  StreamSubscription<Uint8List>? _streamSubscription;
  Uint8List? _currentFrame;
  bool _isLoading = true;
  String? _errorMessage;
  http.Client? _httpClient;

  @override
  void initState() {
    super.initState();
    _startVideoStream();
  }

  void _startVideoStream() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _httpClient = http.Client();
      final url = '${widget.serverUrl}/video_feed/${widget.garudId}';
      
      final request = http.Request('GET', Uri.parse(url));
      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        _streamSubscription = _parseMjpegStream(response.stream).listen(
          (frameData) {
            if (mounted) {
              setState(() {
                _currentFrame = frameData;
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Stream error: $error';
                _isLoading = false;
              });
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _errorMessage = 'Stream ended';
                _isLoading = false;
              });
            }
          },
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to connect: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Stream<Uint8List> _parseMjpegStream(Stream<List<int>> stream) async* {
    List<int> buffer = [];
    bool inFrame = false;
    
    await for (List<int> chunk in stream) {
      buffer.addAll(chunk);
      
      while (buffer.isNotEmpty) {
        if (!inFrame) {
          // Look for start of JPEG frame (FF D8)
          int startIndex = -1;
          for (int i = 0; i < buffer.length - 1; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
              startIndex = i;
              break;
            }
          }
          
          if (startIndex == -1) {
            // No start found, clear buffer
            buffer.clear();
            break;
          }
          
          // Remove data before JPEG start
          if (startIndex > 0) {
            buffer = buffer.sublist(startIndex);
          }
          inFrame = true;
        }
        
        if (inFrame) {
          // Look for end of JPEG frame (FF D9)
          int endIndex = -1;
          for (int i = 0; i < buffer.length - 1; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
              endIndex = i + 2; // Include the end marker
              break;
            }
          }
          
          if (endIndex != -1) {
            // Complete frame found
            yield Uint8List.fromList(buffer.sublist(0, endIndex));
            buffer = buffer.sublist(endIndex);
            inFrame = false;
          } else {
            // Incomplete frame, wait for more data
            break;
          }
        }
      }
    }
  }

  void _reconnect() {
    _stopStream();
    _startVideoStream();
  }

  void _stopStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _httpClient?.close();
    _httpClient = null;
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Feed - ${widget.garudId.length > 8 ? widget.garudId.substring(0, 8) : widget.garudId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showClientInfo(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 300, // Adjust as needed
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildContent(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting to video feed...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _reconnect,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentFrame != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _currentFrame!,
          fit: BoxFit.contain,
          gaplessPlayback: true, // Smooth frame transitions
        ),
      );
    }

    return const Center(
      child: Text('No video data available'),
    );
  }

  void _showClientInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Client Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server URL: ${widget.serverUrl}'),
            Text('Client ID: ${widget.garudId}'),
            Text('Video Feed URL: ${widget.serverUrl}/video_feed/${widget.garudId}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}