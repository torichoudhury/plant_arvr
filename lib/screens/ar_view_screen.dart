import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  _ARScreenState createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  @override
  void dispose() {
    arSessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AR Plant Viewer'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => arSessionManager.onInitialize(),
          ),
        ],
      ),
      body: ARView(onARViewCreated: onARViewCreated),
    );
  }

  void onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;
    arAnchorManager = anchorManager;

    arSessionManager.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      customPlaneTexturePath: "assets/triangle.png",
      showWorldOrigin: true,
      handleTaps: true,
    );
    arSessionManager.onPlaneOrPointTap =
        (hitTestResults) => onPlaneOrPointTapped(hitTestResults);
    arObjectManager.onNodeTap = onNodeTapped;
  }

  Future<void> onPlaneOrPointTapped(List<dynamic> hitTestResults) async {
    if (hitTestResults.isEmpty) return;

    final hit = hitTestResults.first;
    final anchor = ARPlaneAnchor(
      transformation: Matrix4.fromList(
        List<double>.from(hit['transformation']),
      ),
    );

    try {
      final didAddAnchor = await arAnchorManager.addAnchor(anchor);
      if (didAddAnchor == null || !didAddAnchor) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add anchor')));
        return;
      }

      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: "assets/models/plant.gltf",
        scale: vector.Vector3(0.2, 0.2, 0.2),
        position: vector.Vector3(0.0, 0.0, 0.0),
        rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
      );

      final didAddNode = await arObjectManager.addNode(
        node,
        planeAnchor: anchor,
      );
      if (didAddNode == null || !didAddNode) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add 3D model')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void onNodeTapped(List<String> nodes) {
    if (nodes.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Plant model tapped')));
    }
  }
}
