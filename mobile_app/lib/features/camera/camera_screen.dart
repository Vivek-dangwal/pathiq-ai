import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _permissionDenied = false;
  String _status = 'Requesting camera permission...';

  // Frame throttling: process at ~10 FPS instead of every camera frame
  static const int targetFps = 10;
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  int _framesProcessedCount = 0;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      setState(() {
        _permissionDenied = true;
        _status = 'Camera permission denied. PathIQ AI needs camera access to detect road hazards.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'No camera found on this device.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) return;

      // Start the image stream; we throttle inside the callback below
      await controller.startImageStream(_onFrameAvailable);

      setState(() {
        _controller = controller;
        _status = 'Camera ready — throttled to ~$targetFps FPS';
      });
    } catch (e) {
      setState(() => _status = 'Camera error: $e');
    }
  }

  void _onFrameAvailable(CameraImage image) {
    final now = DateTime.now();
    final msSinceLastFrame = now.difference(_lastFrameProcessed).inMilliseconds;
    final minIntervalMs = (1000 / targetFps).round();

    if (msSinceLastFrame < minIntervalMs) {
      // Skip this frame — too soon since the last processed one
      return;
    }

    _lastFrameProcessed = now;
    _framesProcessedCount++;

    // This is where inference will run in Milestone M3.
    // For now we just count throttled frames to prove the mechanism works.
    if (mounted) {
      setState(() {
        _status = 'Camera ready — frames processed: $_framesProcessedCount (~$targetFps FPS target)';
      });
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Preview')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_status, textAlign: TextAlign.center),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(child: Text(_status));
    }

    return Stack(
      children: [
        CameraPreview(_controller!),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black54,
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}