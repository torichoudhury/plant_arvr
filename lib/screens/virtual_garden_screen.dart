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

  String statusText = "Starting AR session...";
  int objectCount = 0;
  bool isARReady = false;
  bool isInitializing = true;
  Timer? _statusTimer;
  List<String> placedNodeNames = []; // Track placed nodes
  List<ARPlaneAnchor> placedAnchors = []; // Track placed anchors
  String selectedPlant = "neem"; // Default plant selection will remain neem

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Add a timer to update status during initialization
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isInitializing && mounted) {
        setState(() {
          if (statusText.contains("Starting")) {
            statusText = "Initializing camera and sensors...";
          } else if (statusText.contains("Initializing")) {
            statusText = "Detecting environment...";
          } else {
            statusText = "Point camera at textured flat surfaces";
          }
        });
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
    super.dispose();
  }

  void _cleanupAR() {
    // Only dispose the session manager
    arSessionManager?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App lifecycle management - basic implementation
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
      // Initialize AR session with optimized settings
      await this.arSessionManager!.onInitialize(
        showFeaturePoints: true,
        showPlanes: true,
        showWorldOrigin: false, // Disable to reduce visual clutter
        handlePans: false,
        handleRotation: false,
        handleTaps: true,
      );

      // Initialize object manager
      await this.arObjectManager!.onInitialize();

      // Set up callbacks
      this.arSessionManager!.onPlaneOrPointTap = onPlaneTap;

      // Wait a moment for AR to fully initialize
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        isARReady = true;
        isInitializing = false;
        statusText =
            "AR Ready! Point at flat surfaces and tap to place ${selectedPlant == 'neem' ? 'Neem' : 'Tulsi'} plants";
      });

      print("AR initialization completed successfully");
    } catch (e) {
      print("AR initialization error: $e");
      setState(() {
        statusText = "AR failed to initialize: $e";
        isInitializing = false;
      });
    }
  }

  Future<void> onPlaneTap(List<dynamic> hitTestResults) async {
    print("Tap detected! Processing ${hitTestResults.length} hit results");

    if (!isARReady) {
      setState(() {
        statusText = "AR is still initializing, please wait...";
      });
      return;
    }

    if (hitTestResults.isEmpty) {
      setState(() {
        statusText =
            "No surface found - try pointing at a flat, textured surface";
      });

      // Reset status after a delay
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            statusText =
                "Point at flat surfaces and tap to place ${selectedPlant == 'neem' ? 'Neem' : 'Tulsi'} plants";
          });
        }
      });
      return;
    }

    setState(() {
      statusText = "Surface detected! Placing object...";
    });

    try {
      // Use the first hit result
      var hitResult = hitTestResults.first;
      print("Hit result transform: ${hitResult.worldTransform}");

      // Create anchor with the hit test result
      var anchor = ARPlaneAnchor(transformation: hitResult.worldTransform);
      bool? didAddAnchor = await arAnchorManager!.addAnchor(anchor);

      print("Anchor added: $didAddAnchor");

      if (didAddAnchor == true) {
        String modelUrl;
        String plantName;
        vector_math.Vector3 scale;
        vector_math.Vector3 position;

        switch (selectedPlant) {
          case "neem":
            modelUrl = "assets/neem.glb";
            plantName = "Neem Plant";
            scale = vector_math.Vector3(0.15, 0.15, 0.15);
            position = vector_math.Vector3(0.0, 0.0, 0.0);
            break;
          case "tulsi":
            modelUrl = "assets/basil.glb";
            plantName = "Tulsi Plant";
            scale = vector_math.Vector3(0.1, 0.1, 0.1);
            position = vector_math.Vector3(0.0, 0.02, 0.0);
            break;
          case "rosemary":
            modelUrl = "assets/rosemary.glb";
            plantName = "Rosemary Plant";
            scale = vector_math.Vector3(0.1, 0.1, 0.1);
            position = vector_math.Vector3(0.0, 0.0, 0.0);
            break;
          case "eucalyptus":
            modelUrl = "assets/eucalyptus.glb";
            plantName = "Eucalyptus Plant";
            scale = vector_math.Vector3(0.15, 0.15, 0.15);
            position = vector_math.Vector3(0.0, 0.0, 0.0);
            break;
          case "aloe_vera":
            modelUrl = "assets/aloe_vera.glb";
            plantName = "Aloe Vera Plant";
            scale = vector_math.Vector3(0.08, 0.08, 0.08);
            position = vector_math.Vector3(0.0, 0.0, 0.0);
            break;
          default:
            modelUrl = "assets/neem.glb";
            plantName = "Plant";
            scale = vector_math.Vector3(0.1, 0.1, 0.1);
            position = vector_math.Vector3(0.0, 0.0, 0.0);
        }

        // Create plant node
        var node = ARNode(
          type: NodeType.localGLTF2,
          uri: modelUrl,
          scale: scale,
          position: position,
          rotation: vector_math.Vector4(0.0, 1.0, 0.0, 0.0),
          name: "${selectedPlant}_$objectCount",
        );

        bool? didAddNode = await arObjectManager!.addNode(
          node,
          planeAnchor: anchor,
        );
        print("Node added: $didAddNode");

        if (didAddNode == true) {
          // Track the placed node and anchor
          placedNodeNames.add(node.name);
          placedAnchors.add(anchor);

          setState(() {
            objectCount++;
            statusText = "Success! $plantName #$objectCount placed";
          });

          // Reset status after celebration
          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                statusText =
                    "Tap on surfaces to place more ${selectedPlant == 'neem' ? 'Neem' : 'Tulsi'} plants";
              });
            }
          });

          print("Successfully placed object #$objectCount");
        } else {
          setState(() {
            statusText = "Failed to place object - try again";
          });
        }
      } else {
        setState(() {
          statusText = "Could not anchor to surface - try a different spot";
        });
      }
    } catch (e) {
      print("Error in onPlaneTap: $e");
      setState(() {
        statusText = "Error placing object: ${e.toString()}";
      });
    }
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
      ),
    );
  }

  Widget _buildObjectCounter() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedPlant == "neem" ? Icons.park : Icons.local_florist,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              "${selectedPlant == 'neem' ? 'Neem' : 'Tulsi'} Plants: $objectCount",
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
      child: Container(
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
            statusText = "$label selected - tap surfaces to place plants";
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color:
                selectedPlant == plantType
                    ? Colors.green
                    : Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
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
                  color:
                      selectedPlant == plantType ? Colors.white : Colors.green,
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
                  // Remove all tracked nodes by recreating them as ARNode objects
                  for (int i = 0; i < placedNodeNames.length; i++) {
                    String nodeName = placedNodeNames[i];
                    // Create a temporary ARNode to pass to removeNode
                    var nodeToRemove = ARNode(
                      type: NodeType.localGLTF2,
                      uri: "", // Empty URI for removal
                      name: nodeName,
                    );
                    await arObjectManager?.removeNode(nodeToRemove);
                  }

                  // Remove all tracked anchors
                  for (ARPlaneAnchor anchor in placedAnchors) {
                    await arAnchorManager?.removeAnchor(anchor);
                  }

                  // Clear our tracking lists
                  placedNodeNames.clear();
                  placedAnchors.clear();

                  setState(() {
                    objectCount = 0;
                    statusText =
                        "All plants cleared - tap surfaces to place new ones";
                  });

                  print("Successfully cleared all objects");
                } catch (e) {
                  print("Error clearing objects: $e");
                  setState(() {
                    statusText = "Error clearing objects - try restarting";
                  });
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
