import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'foreground_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _permissionDenied = false;
  String _status = 'Requesting camera permission...';

  static const int targetFps = 10;
  DateTime _lastFrameProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  int _framesProcessedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
      setState(() => _status = 'App backgrounded — camera stream paused (service still alive)');
    } else if (state == AppLifecycleState.resumed) {
      controller.startImageStream(_onFrameAvailable);
      setState(() => _status = 'Camera ready — throttled to ~$targetFps FPS');
    }
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
      return;
    }

    _lastFrameProcessed = now;
    _framesProcessedCount++;

    if (mounted) {
      setState(() {
        _status = 'Camera ready — frames processed: $_framesProcessedCount (~$targetFps FPS target)';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final notifStatus = await Permission.notification.request();
                      if (!notifStatus.isGranted) {
                        setState(() => _status = 'Notification permission denied — service notification may not show.');
                      }
                      final started = await startForegroundTask();
                      setState(() {
                        _status = started
                            ? 'Background service started successfully'
                            : 'Failed to start background service';
                      });
                    },
                    child: const Text('Start Service'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final stopped = await stopForegroundTask();
                      setState(() {
                        _status = stopped ? 'Background service stopped' : 'Failed to stop service';
                      });
                    },
                    child: const Text('Stop Service'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                width: double.infinity,
                child: Text(
                  _status,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}