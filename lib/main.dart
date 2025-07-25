import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(PlantARApp());

class PlantARApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plant AR Detector',
      theme: ThemeData(primarySwatch: Colors.green),
      home: HomeScreen(),
    );
  }
}
