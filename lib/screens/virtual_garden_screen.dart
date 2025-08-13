import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'dart:async';

class ImprovedARTest extends StatefulWidget {
  const ImprovedARTest({Key? key}) : super(key: key);

  @override
  _ImprovedARTestState createState() => _ImprovedARTestState();
}

class _ImprovedARTestState extends State<ImprovedARTest>
    with WidgetsBindingObserver {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  ARLocationManager? arLocationManager;

  // Use ValueNotifier for a more efficient state update
  final ValueNotifier<String> _statusNotifier = ValueNotifier(
    "Starting AR session...",
  );
  int objectCount = 0;
  bool isARReady = false;
  bool isInitializing = true;
  Timer? _statusTimer;
  List<ARPlaneAnchor> placedAnchors = []; // Track placed anchors
  String selectedPlant = "neem"; // Default plant selection

  // Add a model cache
  final Map<String, ARNode> _modelCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Add a timer to update status during initialization
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isInitializing && mounted) {
        if (_statusNotifier.value.contains("Starting")) {
          _statusNotifier.value = "Initializing camera and sensors...";
        } else if (_statusNotifier.value.contains("Initializing")) {
          _statusNotifier.value = "Detecting environment...";
        } else {
          _statusNotifier.value = "Point camera at textured flat surfaces";
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _cleanupAR();
    _statusNotifier.dispose(); // Dispose of the ValueNotifier
    super.dispose();
  }

  Future<void> _cleanupAR() async {
    // Clear all nodes and anchors
    if (arObjectManager != null && arAnchorManager != null) {
      for (final anchor in placedAnchors) {
        await arAnchorManager!.removeAnchor(anchor);
      }
    }
    placedAnchors.clear();
    objectCount = 0;
    arSessionManager?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print("App paused - AR session may be affected");
    } else if (state == AppLifecycleState.resumed) {
      print("App resumed");
    }
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) async {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arLocationManager = arLocationManager;

    print("AR View Created - Starting initialization...");

    try {
      await this.arSessionManager!.onInitialize(
        showFeaturePoints: true,
        showPlanes: true,
        showWorldOrigin: false,
        handlePans: false,
        handleRotation: false,
        handleTaps: true,
      );

      await this.arObjectManager!.onInitialize();
      this.arSessionManager!.onPlaneOrPointTap = onPlaneTap;

      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        isARReady = true;
        isInitializing = false;
      });
      _statusNotifier.value =
          "AR Ready! Tap to place a ${selectedPlant == 'neem' ? 'Neem' : 'Tulsi'} plant";

      print("AR initialization completed successfully");
    } catch (e) {
      print("AR initialization error: $e");
      setState(() {
        isInitializing = false;
      });
      _statusNotifier.value = "AR failed to initialize: $e";
    }
  }

  Future<void> onPlaneTap(List<dynamic> hitTestResults) async {
    if (!isARReady) {
      _statusNotifier.value = "AR is still initializing, please wait...";
      return;
    }

    if (hitTestResults.isEmpty) {
      _statusNotifier.value =
          "No surface found - try pointing at a flat, textured surface";
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _statusNotifier.value =
              "Point at flat surfaces and tap to place plants";
        }
      });
      return;
    }

    _statusNotifier.value = "Surface detected! Placing object...";

    try {
      var hitResult = hitTestResults.first;
      var anchor = ARPlaneAnchor(transformation: hitResult.worldTransform);
      bool? didAddAnchor = await arAnchorManager!.addAnchor(anchor);

      if (didAddAnchor == true) {
        String modelUrl;
        String plantName;
        vector_math.Vector3 scale;

        switch (selectedPlant) {
          case "neem":
            modelUrl =
                "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/neem.glb";
            plantName = "Neem Plant";
            scale = vector_math.Vector3(0.8, 0.15, 0.15);
            break;
          case "tulsi":
            modelUrl =
                "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/basil.glb";
            plantName = "Tulsi Plant";
            scale = vector_math.Vector3(0.4, 0.1, 0.1);
            break;
          case "rosemary":
            modelUrl =
                "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/rosemary.glb";
            plantName = "Rosemary Plant";
            scale = vector_math.Vector3(0.3, 0.1, 0.1);
            break;
          case "eucalyptus":
            modelUrl =
                "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/eucalyptus.glb";
            plantName = "Eucalyptus Plant";
            scale = vector_math.Vector3(0.4, 0.15, 0.15);
            break;
          case "aloe_vera":
            modelUrl =
                "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/aloe_vera.glb";
            plantName = "Aloe Vera Plant";
            scale = vector_math.Vector3(0.3, 0.08, 0.08);
            break;
          default:
            modelUrl =
                "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/neem.glb";
            plantName = "Plant";
            scale = vector_math.Vector3(0.4, 0.1, 0.1);
            break;
        }

        var node = await _loadModel(
          modelUrl,
          "${selectedPlant}_$objectCount",
          scale,
        );

        bool? didAddNode = await arObjectManager!.addNode(
          node!,
          planeAnchor: anchor,
        );

        if (didAddNode == true) {
          placedAnchors.add(anchor);
          setState(() {
            objectCount++;
          });
          _statusNotifier.value = "Success! $plantName #$objectCount placed";

          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              _statusNotifier.value = "Tap on surfaces to place more plants";
            }
          });
        } else {
          _statusNotifier.value = "Failed to place object - try again";
        }
      } else {
        _statusNotifier.value =
            "Could not anchor to surface - try a different spot";
      }
    } catch (e) {
      print("Error in onPlaneTap: $e");
      _statusNotifier.value = "Error placing object: ${e.toString()}";
    }
  }

  Future<ARNode?> _loadModel(
    String modelUrl,
    String nodeName,
    vector_math.Vector3 scale,
  ) async {
    try {
      // Check if model is cached
      if (_modelCache.containsKey(modelUrl)) {
        print("Using cached model for $nodeName");
        final cachedNode = _modelCache[modelUrl]!;
        return ARNode(
          type: cachedNode.type,
          uri: cachedNode.uri,
          scale: scale,
          position: vector_math.Vector3(0.0, 0.0, 0.0),
          rotation: vector_math.Vector4(0.0, 1.0, 0.0, 0.0),
          name: nodeName,
        );
      }

      print("Loading model from URL: $modelUrl");
      var node = ARNode(
        type: NodeType.webGLB,
        uri: modelUrl,
        scale: scale,
        position: vector_math.Vector3(0.0, 0.0, 0.0),
        rotation: vector_math.Vector4(0.0, 1.0, 0.0, 0.0),
        name: nodeName,
      );

      _modelCache[modelUrl] = node;
      print("Model loaded and cached successfully: $nodeName");
      return node;
    } catch (e) {
      print("Error loading model: $e");
      _statusNotifier.value = "Error loading model: $e";
      return null;
    }
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: ValueListenableBuilder<String>(
        valueListenable: _statusNotifier,
        builder: (context, statusText, child) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isARReady ? Icons.check_circle : Icons.hourglass_empty,
                      color: isARReady ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
                if (isARReady) ...[
                  const SizedBox(height: 12),
                  const Text(
                    "Tips for better detection:",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "• Ensure good lighting\n• Use textured surfaces (avoid plain white)\n• Move device slowly to scan\n• Try tables, floors, or books",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildObjectCounter() {
    // Helper function to get proper plant display name
    String getPlantDisplayName() {
      switch (selectedPlant) {
        case "neem":
          return "Neem";
        case "tulsi":
          return "Tulsi";
        case "rosemary":
          return "Rosemary";
        case "eucalyptus":
          return "Eucalyptus";
        case "aloe_vera":
          return "Aloe Vera";
        default:
          return "Plant";
      }
    }

    // Helper function to get proper plant icon
    IconData getPlantIcon() {
      switch (selectedPlant) {
        case "neem":
          return Icons.park;
        case "tulsi":
          return Icons.local_florist;
        case "rosemary":
          return Icons.spa;
        case "eucalyptus":
          return Icons.nature;
        case "aloe_vera":
          return Icons.eco;
        default:
          return Icons.local_florist;
      }
    }

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(color: Colors.green, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(getPlantIcon(), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              "${getPlantDisplayName()} Plants: $objectCount",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantSelector() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 16,
      right: 16,
      child: SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            _buildPlantButton("neem", "Neem", Icons.park),
            _buildPlantButton("tulsi", "Tulsi", Icons.local_florist),
            _buildPlantButton("rosemary", "Rosemary", Icons.spa),
            _buildPlantButton("eucalyptus", "Eucalyptus", Icons.nature),
            _buildPlantButton("aloe_vera", "Aloe Vera", Icons.eco),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantButton(String plantType, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedPlant = plantType;
          });
          _statusNotifier.value =
              "$label selected - tap surfaces to place plants";
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selectedPlant == plantType
                ? Colors.green
                : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selectedPlant == plantType ? Colors.white : Colors.green,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selectedPlant == plantType
                      ? Colors.white
                      : Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AR Surface Detection'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (objectCount > 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                try {
                  // This is the more efficient way to remove all objects
                  for (ARPlaneAnchor anchor in placedAnchors) {
                    await arAnchorManager?.removeAnchor(anchor);
                  }
                  placedAnchors.clear();
                  setState(() {
                    objectCount = 0;
                  });
                  _statusNotifier.value =
                      "All plants cleared - tap surfaces to place new ones";
                  print("Successfully cleared all objects");
                } catch (e) {
                  print("Error clearing objects: $e");
                  _statusNotifier.value =
                      "Error clearing objects - try restarting";
                }
              },
              tooltip: 'Clear all plants',
            ),
        ],
      ),
      body: Stack(
        children: [
          // AR View
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // Status overlay
          _buildStatusOverlay(),

          // Object counter
          _buildObjectCounter(),

          // Plant selector
          _buildPlantSelector(),

          // Loading indicator during initialization
          if (isInitializing)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Initializing AR...",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
