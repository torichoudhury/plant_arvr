

// Main App Widget
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:plant_arvr/providers/ar_providers.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'dart:async';

class ImprovedARTest extends ConsumerStatefulWidget {
  const ImprovedARTest({Key? key}) : super(key: key);

  @override
  ConsumerState<ImprovedARTest> createState() => _ImprovedARTestState();
}

class _ImprovedARTestState extends ConsumerState<ImprovedARTest>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Start the status timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arStateNotifier = ref.read(arStateProvider.notifier);
      final statusNotifier = ref.read(statusProvider.notifier);
      arStateNotifier.startStatusTimer(statusNotifier);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(arStateProvider.notifier).dispose();
    _cleanupAR();
    super.dispose();
  }

  Future<void> _cleanupAR() async {
    final arState = ref.read(arStateProvider);
    final placedAnchors = ref.read(placedAnchorsProvider);
    final objectCountNotifier = ref.read(objectCountProvider.notifier);
    final placedAnchorsNotifier = ref.read(placedAnchorsProvider.notifier);

    if (arState.arObjectManager != null && arState.arAnchorManager != null) {
      for (final anchor in placedAnchors) {
        await arState.arAnchorManager!.removeAnchor(anchor);
      }
    }
    placedAnchorsNotifier.clearAnchors();
    objectCountNotifier.reset();
    arState.arSessionManager?.dispose();
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
    final arStateNotifier = ref.read(arStateProvider.notifier);
    final statusNotifier = ref.read(statusProvider.notifier);

    arStateNotifier.setManagers(
      arSessionManager: arSessionManager,
      arObjectManager: arObjectManager,
      arAnchorManager: arAnchorManager,
      arLocationManager: arLocationManager,
    );

    print("AR View Created - Starting initialization...");

    try {
      await arSessionManager.onInitialize(
        showFeaturePoints: true,
        showPlanes: true,
        showWorldOrigin: false,
        handlePans: false,
        handleRotation: false,
        handleTaps: true,
      );

      await arObjectManager.onInitialize();
      arSessionManager.onPlaneOrPointTap = onPlaneTap;

      await Future.delayed(const Duration(seconds: 2));

      arStateNotifier.setARReady(true);
      arStateNotifier.setInitializing(false);
      
      final selectedPlant = ref.read(selectedPlantProvider);
      final plants = ref.read(plantsProvider);
      final plantInfo = plants.firstWhere((p) => p.id == selectedPlant);
      statusNotifier.updateStatus("AR Ready! Tap to place a ${plantInfo.displayName} plant");

      print("AR initialization completed successfully");
    } catch (e) {
      print("AR initialization error: $e");
      arStateNotifier.setInitializing(false);
      statusNotifier.updateStatus("AR failed to initialize: $e");
    }
  }

  Future<void> onPlaneTap(List<dynamic> hitTestResults) async {
    final arState = ref.read(arStateProvider);
    final statusNotifier = ref.read(statusProvider.notifier);
    final selectedPlant = ref.read(selectedPlantProvider);
    final plants = ref.read(plantsProvider);
    final objectCount = ref.read(objectCountProvider);
    final objectCountNotifier = ref.read(objectCountProvider.notifier);
    final placedAnchorsNotifier = ref.read(placedAnchorsProvider.notifier);

    if (!arState.isARReady) {
      statusNotifier.updateStatus("AR is still initializing, please wait...");
      return;
    }

    if (hitTestResults.isEmpty) {
      statusNotifier.updateStatus("No surface found - try pointing at a flat, textured surface");
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          statusNotifier.updateStatus("Point at flat surfaces and tap to place plants");
        }
      });
      return;
    }

    statusNotifier.updateStatus("Surface detected! Placing object...");

    try {
      var hitResult = hitTestResults.first;
      var anchor = ARPlaneAnchor(transformation: hitResult.worldTransform);
      bool? didAddAnchor = await arState.arAnchorManager!.addAnchor(anchor);

      if (didAddAnchor == true) {
        final plantInfo = plants.firstWhere((p) => p.id == selectedPlant);
        
        var node = await _loadModel(
          plantInfo.modelUrl,
          "${selectedPlant}_$objectCount",
          plantInfo.scale,
        );

        bool? didAddNode = await arState.arObjectManager!.addNode(
          node!,
          planeAnchor: anchor,
        );

        if (didAddNode == true) {
          placedAnchorsNotifier.addAnchor(anchor);
          objectCountNotifier.increment();
          final newCount = ref.read(objectCountProvider);
          statusNotifier.updateStatus("Success! ${plantInfo.displayName} #$newCount placed");

          Timer(const Duration(seconds: 2), () {
            if (mounted) {
              statusNotifier.updateStatus("Tap on surfaces to place more plants");
            }
          });
        } else {
          statusNotifier.updateStatus("Failed to place object - try again");
        }
      } else {
        statusNotifier.updateStatus("Could not anchor to surface - try a different spot");
      }
    } catch (e) {
      print("Error in onPlaneTap: $e");
      statusNotifier.updateStatus("Error placing object: ${e.toString()}");
    }
  }

  Future<ARNode?> _loadModel(
    String modelUrl,
    String nodeName,
    vector_math.Vector3 scale,
  ) async {
    final modelCacheNotifier = ref.read(modelCacheProvider.notifier);
    final modelCache = ref.read(modelCacheProvider);
    final statusNotifier = ref.read(statusProvider.notifier);

    try {
      // Check if model is cached
      if (modelCache.containsKey(modelUrl)) {
        print("Using cached model for $nodeName");
        final cachedNode = modelCache[modelUrl]!;
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

      modelCacheNotifier.cacheModel(modelUrl, node);
      print("Model loaded and cached successfully: $nodeName");
      return node;
    } catch (e) {
      print("Error loading model: $e");
      statusNotifier.updateStatus("Error loading model: $e");
      return null;
    }
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Consumer(
        builder: (context, ref, child) {
          final statusText = ref.watch(statusProvider);
          final isARReady = ref.watch(arStateProvider.select((state) => state.isARReady));
          
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
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 80,
      left: 16,
      right: 16,
      child: Consumer(
        builder: (context, ref, child) {
          final objectCount = ref.watch(objectCountProvider);
          final currentPlantInfo = ref.watch(currentPlantInfoProvider);
          
          return Container(
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
                Icon(currentPlantInfo.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  "${currentPlantInfo.displayName} Plants: $objectCount",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlantSelector() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 16,
      right: 16,
      child: Consumer(
        builder: (context, ref, child) {
          final plants = ref.watch(plantsProvider);
          final selectedPlant = ref.watch(selectedPlantProvider);
          
          return SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: plants.map((plant) => _buildPlantButton(plant)).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlantButton(PlantInfo plant) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Consumer(
        builder: (context, ref, child) {
          final selectedPlant = ref.watch(selectedPlantProvider);
          final selectedPlantNotifier = ref.read(selectedPlantProvider.notifier);
          final statusNotifier = ref.read(statusProvider.notifier);
          
          return GestureDetector(
            onTap: () {
              selectedPlantNotifier.selectPlant(plant.id);
              statusNotifier.updateStatus("${plant.displayName} selected - tap surfaces to place plants");
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selectedPlant == plant.id
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
                    plant.icon,
                    color: selectedPlant == plant.id ? Colors.white : Colors.green,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plant.displayName,
                    style: TextStyle(
                      color: selectedPlant == plant.id ? Colors.white : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
          Consumer(
            builder: (context, ref, child) {
              final objectCount = ref.watch(objectCountProvider);
              final placedAnchors = ref.watch(placedAnchorsProvider);
              
              if (objectCount == 0) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  final arState = ref.read(arStateProvider);
                  final objectCountNotifier = ref.read(objectCountProvider.notifier);
                  final placedAnchorsNotifier = ref.read(placedAnchorsProvider.notifier);
                  final statusNotifier = ref.read(statusProvider.notifier);
                  
                  try {
                    for (ARPlaneAnchor anchor in placedAnchors) {
                      await arState.arAnchorManager?.removeAnchor(anchor);
                    }
                    placedAnchorsNotifier.clearAnchors();
                    objectCountNotifier.reset();
                    statusNotifier.updateStatus("All plants cleared - tap surfaces to place new ones");
                    print("Successfully cleared all objects");
                  } catch (e) {
                    print("Error clearing objects: $e");
                    statusNotifier.updateStatus("Error clearing objects - try restarting");
                  }
                },
                tooltip: 'Clear all plants',
              );
            },
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
          Consumer(
            builder: (context, ref, child) {
              final isInitializing = ref.watch(arStateProvider.select((state) => state.isInitializing));
              
              if (!isInitializing) return const SizedBox.shrink();
              
              return const Center(
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
              );
            },
          ),
        ],
      ),
    );
  }
}