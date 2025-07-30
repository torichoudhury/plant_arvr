import 'package:flutter/material.dart' hide Colors;
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../models/plant_model.dart';
import '../services/gemini_service.dart';
import 'package:flutter/material.dart' as material show Colors;

class VirtualGardenScreen extends StatefulWidget {
  const VirtualGardenScreen({Key? key}) : super(key: key);

  @override
  _VirtualGardenScreenState createState() => _VirtualGardenScreenState();
}

class _VirtualGardenScreenState extends State<VirtualGardenScreen> {
  ArCoreController? arCoreController;

  List<Plant> availablePlants = [
    Plant(id: '1', name: 'Aloe Vera', model3dPath: 'assets/3d/aloe_vera.glb'),
    Plant(id: '2', name: 'Lavender', model3dPath: 'assets/3d/lavender.glb'),
    Plant(id: '3', name: 'Mint', model3dPath: 'assets/3d/mint.glb'),
    Plant(id: '4', name: 'Tulsi', model3dPath: 'assets/3d/tulsi.glb'),
    Plant(id: '5', name: 'Chamomile', model3dPath: 'assets/3d/chamomile.glb'),
  ];

  List<Plant> placedPlants = [];
  Plant? selectedPlant;
  final GeminiService _geminiService = GeminiService('YOUR_GEMINI_API_KEY');

  @override
  void dispose() {
    arCoreController?.dispose();
    super.dispose();
  }

  void onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    arCoreController?.onPlaneTap = _handlePlaneTopTap;
    arCoreController?.onNodeTap = (name) {
      final plant = placedPlants.firstWhere(
        (p) => p.id == name,
        orElse: () => placedPlants.first,
      );
      _onPlantTap(plant);
    };
  }

  void _handlePlaneTopTap(List<ArCoreHitTestResult> hits) {
    if (hits.isEmpty || selectedPlant == null) return;
    _onPlacePlant(hits.first);
  }

  Future<void> _onPlantTap(Plant plant) async {
    try {
      if (plant.medicalBenefits == null) {
        final benefits = await _geminiService.getMedicalBenefits(plant.name);
        setState(() {
          plant.medicalBenefits = benefits;
        });
      }

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(plant.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Medical Benefits:'),
                  SizedBox(height: 8),
                  Text(plant.medicalBenefits ?? 'Loading...'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load medical benefits')),
      );
    }
  }

  void _onPlacePlant(ArCoreHitTestResult hit) {
    if (selectedPlant == null || arCoreController == null) return;

    final newPlant = Plant(
      id: DateTime.now().toString(),
      name: selectedPlant!.name,
      model3dPath: selectedPlant!.model3dPath,
      x: hit.pose.translation.x,
      y: hit.pose.translation.y,
      z: hit.pose.translation.z,
    );

    try {
      arCoreController?.addArCoreNodeWithAnchor(
        ArCoreNode(
          name: newPlant.id,
          shape: ArCoreSphere(
            materials: [
              ArCoreMaterial(
                color: material.Colors.green,
              )
            ],
            radius: 0.1,
          ),
          position: Vector3(newPlant.x, newPlant.y, newPlant.z),
          rotation: Vector4(0, 0, 0, 0),
          scale: Vector3(0.2, 0.2, 0.2),
        ),
      );

      setState(() {
        placedPlants.add(newPlant);
        selectedPlant = null;
      });
    } catch (e) {
      print('Error placing plant: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Virtual Garden'),
        backgroundColor: Color(0xFF2E7D32),
        foregroundColor: material.Colors.white,
      ),
      body: Stack(
        children: [
          ArCoreView(
            onArCoreViewCreated: onArCoreViewCreated,
            enableTapRecognizer: true,
            enableUpdateListener: true,
          ),
          if (selectedPlant != null)
            Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: material.Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tap on a surface to place ${selectedPlant!.name}',
                  style: TextStyle(
                    color: material.Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              color: material.Colors.black54,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availablePlants.length,
                padding: EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final plant = availablePlants[index];
                  return GestureDetector(
                    onTap: () => setState(() => selectedPlant = plant),
                    child: Container(
                      width: 80,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color:
                            selectedPlant?.id == plant.id
                                ? material.Colors.green.withOpacity(0.3)
                                : material.Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_florist, color: material.Colors.white),
                          SizedBox(height: 4),
                          Text(
                            plant.name,
                            style: TextStyle(color: material.Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  
  }
}
