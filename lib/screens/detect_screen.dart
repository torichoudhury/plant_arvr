import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/plant_detector_service.dart';

class DetectScreen extends StatefulWidget {
  @override
  _DetectScreenState createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  File? _image;
  bool _isLoading = false;
  String _result = '';
  final PlantDetectorService _detector = PlantDetectorService();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    await _detector.loadModel();
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image == null) return;

      setState(() {
        _image = File(image.path);
        _isLoading = true;
        _result = '';
      });

      // Run detection
      final result = await _detector.detectPlant(_image!);
      
      setState(() {
        _result = 'Plant: ${result.label}\nConfidence: ${(result.confidence * 100).toStringAsFixed(2)}%';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _result = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _detector.disposeModel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detect Plant'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            _image == null
                ? Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.camera_alt,
                      size: 100,
                      color: Colors.grey[400],
                    ),
                  )
                : Image.file(
                    _image!,
                    height: 300,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
            SizedBox(height: 20),
            if (_isLoading)
              CircularProgressIndicator()
            else if (_result.isNotEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  _result,
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt),
              label: Text('Take Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: _pickImage,
            ),
          ],
        ),
      ),
    );
  }
}