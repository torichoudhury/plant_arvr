// providers/ar_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart' as vector_math;

// Models
class ARState {
  final ARSessionManager? arSessionManager;
  final ARObjectManager? arObjectManager;
  final ARAnchorManager? arAnchorManager;
  final ARLocationManager? arLocationManager;
  final bool isARReady;
  final bool isInitializing;

  const ARState({
    this.arSessionManager,
    this.arObjectManager,
    this.arAnchorManager,
    this.arLocationManager,
    this.isARReady = false,
    this.isInitializing = true,
  });

  ARState copyWith({
    ARSessionManager? arSessionManager,
    ARObjectManager? arObjectManager,
    ARAnchorManager? arAnchorManager,
    ARLocationManager? arLocationManager,
    bool? isARReady,
    bool? isInitializing,
  }) {
    return ARState(
      arSessionManager: arSessionManager ?? this.arSessionManager,
      arObjectManager: arObjectManager ?? this.arObjectManager,
      arAnchorManager: arAnchorManager ?? this.arAnchorManager,
      arLocationManager: arLocationManager ?? this.arLocationManager,
      isARReady: isARReady ?? this.isARReady,
      isInitializing: isInitializing ?? this.isInitializing,
    );
  }
}

class PlantInfo {
  final String id;
  final String name;
  final String displayName;
  final String modelUrl;
  final IconData icon;
  final vector_math.Vector3 scale;

  const PlantInfo({
    required this.id,
    required this.name,
    required this.displayName,
    required this.modelUrl,
    required this.icon,
    required this.scale,
  });
}

// Providers
final arStateProvider = StateNotifierProvider<ARStateNotifier, ARState>((ref) {
  return ARStateNotifier();
});

final statusProvider = StateNotifierProvider<StatusNotifier, String>((ref) {
  return StatusNotifier();
});

final selectedPlantProvider = StateNotifierProvider<SelectedPlantNotifier, String>((ref) {
  return SelectedPlantNotifier();
});

final objectCountProvider = StateNotifierProvider<ObjectCountNotifier, int>((ref) {
  return ObjectCountNotifier();
});

final placedAnchorsProvider = StateNotifierProvider<PlacedAnchorsNotifier, List<ARPlaneAnchor>>((ref) {
  return PlacedAnchorsNotifier();
});

final modelCacheProvider = StateNotifierProvider<ModelCacheNotifier, Map<String, ARNode>>((ref) {
  return ModelCacheNotifier();
});

final plantsProvider = Provider<List<PlantInfo>>((ref) {
  return [
    PlantInfo(
      id: "neem",
      name: "neem",
      displayName: "Neem",
      modelUrl: "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/neem.glb",
      icon: Icons.park,
      scale: vector_math.Vector3(0.8, 0.15, 0.15),
    ),
    PlantInfo(
      id: "tulsi",
      name: "tulsi",
      displayName: "Tulsi",
      modelUrl: "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/basil.glb",
      icon: Icons.local_florist,
      scale: vector_math.Vector3(0.4, 0.1, 0.1),
    ),
    PlantInfo(
      id: "rosemary",
      name: "rosemary",
      displayName: "Rosemary",
      modelUrl: "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/rosemary.glb",
      icon: Icons.spa,
      scale: vector_math.Vector3(0.3, 0.1, 0.1),
    ),
    PlantInfo(
      id: "eucalyptus",
      name: "eucalyptus",
      displayName: "Eucalyptus",
      modelUrl: "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/eucalyptus.glb",
      icon: Icons.nature,
      scale: vector_math.Vector3(0.4, 0.15, 0.15),
    ),
    PlantInfo(
      id: "aloe_vera",
      name: "aloe_vera",
      displayName: "Aloe Vera",
      modelUrl: "https://raw.githubusercontent.com/torichoudhury/plant_arvr/master/assets/aloe_vera.glb",
      icon: Icons.eco,
      scale: vector_math.Vector3(0.3, 0.08, 0.08),
    ),
  ];
});

final currentPlantInfoProvider = Provider<PlantInfo>((ref) {
  final selectedPlant = ref.watch(selectedPlantProvider);
  final plants = ref.watch(plantsProvider);
  return plants.firstWhere(
    (plant) => plant.id == selectedPlant,
    orElse: () => plants.first,
  );
});

// State Notifiers
class ARStateNotifier extends StateNotifier<ARState> {
  Timer? _statusTimer;

  ARStateNotifier() : super(const ARState());

  void setManagers({
    required ARSessionManager arSessionManager,
    required ARObjectManager arObjectManager,
    required ARAnchorManager arAnchorManager,
    required ARLocationManager arLocationManager,
  }) {
    state = state.copyWith(
      arSessionManager: arSessionManager,
      arObjectManager: arObjectManager,
      arAnchorManager: arAnchorManager,
      arLocationManager: arLocationManager,
    );
  }

  void setARReady(bool isReady) {
    state = state.copyWith(isARReady: isReady);
  }

  void setInitializing(bool isInitializing) {
    state = state.copyWith(isInitializing: isInitializing);
  }

  void startStatusTimer(StatusNotifier statusNotifier) {
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state.isInitializing) {
        final currentStatus = statusNotifier.state;
        if (currentStatus.contains("Starting")) {
          statusNotifier.updateStatus("Initializing camera and sensors...");
        } else if (currentStatus.contains("Initializing")) {
          statusNotifier.updateStatus("Detecting environment...");
        } else {
          statusNotifier.updateStatus("Point camera at textured flat surfaces");
        }
      } else {
        timer.cancel();
      }
    });
  }

  void dispose() {
    super.dispose();
    _statusTimer?.cancel();
  }
}

class StatusNotifier extends StateNotifier<String> {
  StatusNotifier() : super("Starting AR session...");

  void updateStatus(String status) {
    state = status;
  }
}

class SelectedPlantNotifier extends StateNotifier<String> {
  SelectedPlantNotifier() : super("neem");

  void selectPlant(String plantId) {
    state = plantId;
  }
}

class ObjectCountNotifier extends StateNotifier<int> {
  ObjectCountNotifier() : super(0);

  void increment() {
    state++;
  }

  void reset() {
    state = 0;
  }
}

class PlacedAnchorsNotifier extends StateNotifier<List<ARPlaneAnchor>> {
  PlacedAnchorsNotifier() : super([]);

  void addAnchor(ARPlaneAnchor anchor) {
    state = [...state, anchor];
  }

  void clearAnchors() {
    state = [];
  }
}

class ModelCacheNotifier extends StateNotifier<Map<String, ARNode>> {
  ModelCacheNotifier() : super({});

  void cacheModel(String url, ARNode node) {
    state = {...state, url: node};
  }

  ARNode? getCachedModel(String url) {
    return state[url];
  }
}