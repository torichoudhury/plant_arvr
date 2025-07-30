class Plant {
  final String id;
  final String name;
  final String model3dPath;
  final double x;
  final double y;
  final double z;
  final double scale;
  final double rotation;
  String? medicalBenefits;

  Plant({
    required this.id,
    required this.name,
    required this.model3dPath,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.scale = 1.0,
    this.rotation = 0,
    this.medicalBenefits,
  });
}
