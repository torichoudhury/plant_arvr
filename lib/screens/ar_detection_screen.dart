import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/plant_detector_service.dart';

class ArDetectionScreen extends StatefulWidget {
  @override
  _ArDetectionScreenState createState() => _ArDetectionScreenState();
}

class _ArDetectionScreenState extends State<ArDetectionScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  PlantDetectionResult? _lastResult;
  Timer? _detectionTimer;
  final PlantDetectorService _detector = PlantDetectorService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _detector.loadModel();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _showPermissionDialog();
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        setState(() {
          _isCameraInitialized = true;
        });

        // Start continuous detection
        _startContinuousDetection();
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _startContinuousDetection() {
    _detectionTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isDetecting &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        _performDetection();
      }
    });
  }

  Future<void> _performDetection() async {
    if (_isDetecting) return;

    setState(() {
      _isDetecting = true;
    });

    try {
      // Capture image from camera
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);

      // Perform detection
      final result = await _detector.detectPlant(imageFile);

      setState(() {
        _lastResult = result;
        _isDetecting = false;
      });

      // Clean up the temporary image file
      await imageFile.delete();
    } catch (e) {
      print('Detection error: $e');
      setState(() {
        _isDetecting = false;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'This app needs camera access to provide AR plant detection functionality.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Settings'),
              ),
            ],
          ),
    );
  }

  Widget _buildConfidenceOverlay() {
    if (_lastResult == null) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getConfidenceColor(_lastResult!.confidence),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_florist,
                  color: _getConfidenceColor(_lastResult!.confidence),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Plant Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Plant: ${_lastResult!.label}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Confidence: ',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '${(_lastResult!.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: _getConfidenceColor(_lastResult!.confidence),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _lastResult!.confidence,
              backgroundColor: Colors.white30,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getConfidenceColor(_lastResult!.confidence),
              ),
              minHeight: 4,
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.4) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDetectionIndicator() {
    return Positioned(
      top: 50,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDetecting)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                Icons.visibility,
                color: _lastResult != null ? Colors.green : Colors.grey,
                size: 16,
              ),
            const SizedBox(width: 6),
            Text(
              _isDetecting ? 'Detecting...' : 'Ready',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    _detector.disposeModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AR Plant Detection',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () async {
              if (_cameras != null && _cameras!.length > 1) {
                final currentIndex = _cameras!.indexOf(
                  _cameraController!.description,
                );
                final nextIndex = (currentIndex + 1) % _cameras!.length;

                await _cameraController!.dispose();
                _cameraController = CameraController(
                  _cameras![nextIndex],
                  ResolutionPreset.high,
                  enableAudio: false,
                );

                await _cameraController!.initialize();
                setState(() {});
              }
            },
          ),
        ],
      ),
      body:
          _isCameraInitialized
              ? Stack(
                children: [
                  // Camera preview
                  Positioned.fill(child: CameraPreview(_cameraController!)),

                  // Confidence overlay
                  _buildConfidenceOverlay(),

                  // Detection indicator
                  _buildDetectionIndicator(),

                  // Crosshair/targeting overlay
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withOpacity(0.8),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.center_focus_strong,
                            color: Colors.white.withOpacity(0.8),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Point camera at plant',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom controls
                  Positioned(
                    bottom: 40,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton(
                          heroTag: "capture",
                          backgroundColor: Colors.white,
                          child: const Icon(
                            Icons.camera_alt,
                            color: Color(0xFF2E7D32),
                          ),
                          onPressed: () async {
                            if (_lastResult != null) {
                              // Capture current frame with detection result
                              final XFile image =
                                  await _cameraController!.takePicture();

                              // Show captured result
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Captured Detection'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.file(File(image.path)),
                                          const SizedBox(height: 16),
                                          Text('Plant: ${_lastResult!.label}'),
                                          Text(
                                            'Confidence: ${(_lastResult!.confidence * 100).toStringAsFixed(1)}%',
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing camera...'),
                  ],
                ),
              ),
    );
  }
}
