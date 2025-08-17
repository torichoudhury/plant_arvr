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
import 'package:plant_arvr/services/gemini_service.dart';
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
    final placedPlantsNotifier = ref.read(placedPlantsProvider.notifier);
    final plantDetailsNotifier = ref.read(plantDetailsProvider.notifier);
    final showPlantDetailsNotifier = ref.read(
      showPlantDetailsProvider.notifier,
    );

    if (arState.arObjectManager != null && arState.arAnchorManager != null) {
      for (final anchor in placedAnchors) {
        await arState.arAnchorManager!.removeAnchor(anchor);
      }
    }
    placedAnchorsNotifier.clearAnchors();
    placedPlantsNotifier.clearPlacedPlants();
    plantDetailsNotifier.clearDetails();
    showPlantDetailsNotifier.hide();
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
      arObjectManager.onNodeTap = onNodeTap;

      await Future.delayed(const Duration(seconds: 2));

      arStateNotifier.setARReady(true);
      arStateNotifier.setInitializing(false);

      final selectedPlant = ref.read(selectedPlantProvider);
      final plants = ref.read(plantsProvider);
      final plantInfo = plants.firstWhere((p) => p.id == selectedPlant);
      statusNotifier.updateStatus(
        "AR Ready! Tap to place a ${plantInfo.displayName} plant",
      );

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
    final placedPlantsNotifier = ref.read(placedPlantsProvider.notifier);

    if (!arState.isARReady) {
      statusNotifier.updateStatus("AR is still initializing, please wait...");
      return;
    }

    if (hitTestResults.isEmpty) {
      statusNotifier.updateStatus(
        "No surface found - try pointing at a flat, textured surface",
      );
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          statusNotifier.updateStatus(
            "Point at flat surfaces and tap to place plants",
          );
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
        final nodeName = "${selectedPlant}_$objectCount";

        var node = await _loadModel(
          plantInfo.modelUrl,
          nodeName,
          plantInfo.scale,
        );

        bool? didAddNode = await arState.arObjectManager!.addNode(
          node!,
          planeAnchor: anchor,
        );

        if (didAddNode == true) {
          // Track the placed plant
          final placedPlant = PlacedPlant(
            id: "${selectedPlant}_$objectCount",
            plantType: selectedPlant,
            nodeName: nodeName,
            anchor: anchor,
            position: vector_math.Vector3(
              hitResult.worldTransform[12],
              hitResult.worldTransform[13],
              hitResult.worldTransform[14],
            ),
            plantInfo: plantInfo,
          );

          placedAnchorsNotifier.addAnchor(anchor);
          placedPlantsNotifier.addPlacedPlant(placedPlant);
          objectCountNotifier.increment();
          final newCount = ref.read(objectCountProvider);
          statusNotifier.updateStatus(
            "Success! ${plantInfo.displayName} #$newCount placed. Tap on plants to see details.",
          );

          Timer(const Duration(seconds: 3), () {
            if (mounted) {
              statusNotifier.updateStatus(
                "Tap on surfaces to place more plants, or tap plants for details",
              );
            }
          });
        } else {
          statusNotifier.updateStatus("Failed to place object - try again");
        }
      } else {
        statusNotifier.updateStatus(
          "Could not anchor to surface - try a different spot",
        );
      }
    } catch (e) {
      print("Error in onPlaneTap: $e");
      statusNotifier.updateStatus("Error placing object: ${e.toString()}");
    }
  }

  Future<void> onNodeTap(List<dynamic> nodes) async {
    if (nodes.isEmpty) return;

    final tappedNode = nodes.first;
    final nodeName = tappedNode.name;

    print("Node tapped: $nodeName");

    final placedPlantsNotifier = ref.read(placedPlantsProvider.notifier);
    final plantDetailsNotifier = ref.read(plantDetailsProvider.notifier);
    final showPlantDetailsNotifier = ref.read(
      showPlantDetailsProvider.notifier,
    );
    final statusNotifier = ref.read(statusProvider.notifier);

    // Find the tapped plant
    final tappedPlant = placedPlantsNotifier.findPlantByNodeName(nodeName);

    if (tappedPlant != null) {
      statusNotifier.updateStatus(
        "Loading ${tappedPlant.plantInfo.displayName} details...",
      );
      showPlantDetailsNotifier.show();

      // Set loading state
      plantDetailsNotifier.setPlantDetails(
        PlantDetails(
          name: tappedPlant.plantInfo.displayName,
          benefits: '',
          usage: '',
          description: '',
          isLoading: true,
        ),
      );

      try {
        // Get plant details from Gemini - using a dummy API key for now
        //const geminiApiKey = "AIzaSyCoC1J_-dYZkQYlR-DQ-IUd2xRcyCBhBFU"; // You'll need to replace this
        final geminiService = GeminiService();

        final plantDetailsResponse = await geminiService.getPlantDetails(
          tappedPlant.plantInfo.displayName,
        );

        plantDetailsNotifier.setPlantDetails(
          PlantDetails(
            name: tappedPlant.plantInfo.displayName,
            benefits: plantDetailsResponse.benefits,
            usage: plantDetailsResponse.usage,
            description: plantDetailsResponse.description,
            isLoading: false,
          ),
        );

        statusNotifier.updateStatus(
          "${tappedPlant.plantInfo.displayName} details loaded!",
        );

        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            statusNotifier.updateStatus(
              "Tap plants for details or surfaces to place more",
            );
          }
        });
      } catch (e) {
        print("Error loading plant details: $e");
        plantDetailsNotifier.setPlantDetails(
          PlantDetails(
            name: tappedPlant.plantInfo.displayName,
            benefits: "Unable to load benefits information",
            usage: "Unable to load usage information",
            description: "Unable to load description",
            isLoading: false,
            error: e.toString(),
          ),
        );
        statusNotifier.updateStatus("Error loading plant details");
      }
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
          final isARReady = ref.watch(
            arStateProvider.select((state) => state.isARReady),
          );

          return Container(
            padding: const EdgeInsets.all(12),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isARReady ? Icons.check_circle : Icons.hourglass_empty,
                      color: isARReady ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isARReady) ...[
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text(
                      "Tips for better detection",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white,
                    tilePadding: EdgeInsets.zero,
                    dense: true,
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          "• Ensure good lighting\n• Use textured surfaces\n• Move device slowly to scan\n• Try tables, floors, or books",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
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
      bottom: 140, // Fixed position to avoid overlap with plant selector
      left: 16,
      right: 16,
      child: Consumer(
        builder: (context, ref, child) {
          final objectCount = ref.watch(objectCountProvider);
          final currentPlantInfo = ref.watch(currentPlantInfoProvider);

          return Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.green,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(currentPlantInfo.icon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "${currentPlantInfo.displayName}: $objectCount",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildPlantSelector() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 0,
      right: 0,
      child: Consumer(
        builder: (context, ref, child) {
          final plants = ref.watch(plantsProvider);
          return Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: plants.length,
              itemBuilder: (context, index) {
                final plant = plants[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildPlantButton(plant),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlantButton(PlantInfo plant) {
    return Consumer(
      builder: (context, ref, child) {
        final selectedPlant = ref.watch(selectedPlantProvider);
        final selectedPlantNotifier = ref.read(selectedPlantProvider.notifier);
        final statusNotifier = ref.read(statusProvider.notifier);

        return GestureDetector(
          onTap: () {
            selectedPlantNotifier.selectPlant(plant.id);
            statusNotifier.updateStatus(
              "${plant.displayName} selected - tap surfaces to place plants",
            );
          },
          child: Container(
            width: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selectedPlant == plant.id
                  ? Colors.green
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(15),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  plant.icon,
                  color: selectedPlant == plant.id
                      ? Colors.white
                      : Colors.green,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    plant.displayName,
                    style: TextStyle(
                      color: selectedPlant == plant.id
                          ? Colors.white
                          : Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlantDetailsOverlay() {
    return Consumer(
      builder: (context, ref, child) {
        final showPlantDetails = ref.watch(showPlantDetailsProvider);
        final plantDetails = ref.watch(plantDetailsProvider);

        if (!showPlantDetails || plantDetails == null) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.black.withOpacity(0.7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          plantDetails.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ref.read(showPlantDetailsProvider.notifier).hide();
                          ref
                              .read(plantDetailsProvider.notifier)
                              .clearDetails();
                        },
                        icon: const Icon(Icons.close),
                        color: Colors.grey,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (plantDetails.isLoading) ...[
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            "Loading plant information...",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ] else if (plantDetails.error != null) ...[
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Unable to load plant information",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            plantDetails.error!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Content in scrollable container
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Benefits section
                            _buildDetailSection(
                              "Medical Benefits",
                              plantDetails.benefits,
                              Icons.healing,
                            ),

                            const SizedBox(height: 16),

                            // Usage section
                            _buildDetailSection(
                              "Usage & Application",
                              plantDetails.usage,
                              Icons.info,
                            ),

                            const SizedBox(height: 16),

                            // Description section
                            _buildDetailSection(
                              "Description",
                              plantDetails.description,
                              Icons.description,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('AR Garden', style: TextStyle(fontSize: 18)),
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
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () async {
                  final arState = ref.read(arStateProvider);
                  final objectCountNotifier = ref.read(
                    objectCountProvider.notifier,
                  );
                  final placedAnchorsNotifier = ref.read(
                    placedAnchorsProvider.notifier,
                  );
                  final placedPlantsNotifier = ref.read(
                    placedPlantsProvider.notifier,
                  );
                  final plantDetailsNotifier = ref.read(
                    plantDetailsProvider.notifier,
                  );
                  final showPlantDetailsNotifier = ref.read(
                    showPlantDetailsProvider.notifier,
                  );
                  final statusNotifier = ref.read(statusProvider.notifier);

                  try {
                    for (ARPlaneAnchor anchor in placedAnchors) {
                      await arState.arAnchorManager?.removeAnchor(anchor);
                    }
                    placedAnchorsNotifier.clearAnchors();
                    placedPlantsNotifier.clearPlacedPlants();
                    plantDetailsNotifier.clearDetails();
                    showPlantDetailsNotifier.hide();
                    objectCountNotifier.reset();
                    statusNotifier.updateStatus(
                      "All plants cleared - tap surfaces to place new ones",
                    );
                    print("Successfully cleared all objects");
                  } catch (e) {
                    print("Error clearing objects: $e");
                    statusNotifier.updateStatus(
                      "Error clearing objects - try restarting",
                    );
                  }
                },
                tooltip: 'Clear all plants',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
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

            // Plant details overlay
            _buildPlantDetailsOverlay(),

            // Loading indicator during initialization
            Consumer(
              builder: (context, ref, child) {
                final isInitializing = ref.watch(
                  arStateProvider.select((state) => state.isInitializing),
                );

                if (!isInitializing) return const SizedBox.shrink();

                return Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Initializing AR...",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
