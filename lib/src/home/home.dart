
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:google_ml_kit/google_ml_kit.dart';

import '../../utils/route.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  String _currentDetection = 'Select a feature';
  late String _errorMessage;
  String _detectionResults = '';  // To store ML results
  List<Map<String, dynamic>> _lastResults = []; // For structured results
  Uint8List? _processedImage; // To show processed images
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  // Initialize _mlFeatures in initState
  late final List<Map<String, dynamic>> _mlFeatures;

  // Get image from camera
  Future<InputImage> _getImageFromCamera() async {
    try {
      final image = await _cameraController.takePicture();
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _processedImage = bytes;
      });
      return InputImage.fromFilePath(image.path);
    } catch (e) {
      throw Exception('Error getting image from camera: $e');
    }
  }

  // Get image from gallery
  Future<InputImage> _getImageFromGallery() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) throw Exception('No image selected');

      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _processedImage = bytes;
      });

      return InputImage.fromFilePath(image.path);
    } catch (e) {
      throw Exception('Error getting image from gallery: $e');
    }
  }

  // Show source selection dialog
  Future<InputImage?> _selectImageSource() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return null;

    return source == ImageSource.camera
        ? await _getImageFromCamera()
        : await _getImageFromGallery();
  }

// Define action methods separately
  Future<Map<String, dynamic>?> _scanBarcode() async {
    final inputImage = await _selectImageSource();
    if (inputImage == null) return null;

    final barcodeScanner = BarcodeScanner();
    final barcodes = await barcodeScanner.processImage(inputImage);
    await barcodeScanner.close();

    return {
      'type': 'barcode',
      'results': barcodes.map((barcode) => barcode.displayValue ?? 'No value').toList(),
    };
  }

  Future<Map<String, dynamic>?> _detectFaces() async {
    final inputImage = await _selectImageSource();
    if (inputImage == null) return null;

    final options = FaceDetectorOptions(performanceMode: FaceDetectorMode.fast);
    final faceDetector = FaceDetector(options: options);
    final faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();

    return {
      'type': 'face',
      'results': faces.map((face) => face.boundingBox).toList(),
    };
  }

  @override
  void initState() {
    super.initState();
    _initCameraWithPermissions();
    _requestPermissions();
    _initializeFeatures();
  }

  void _initializeFeatures() {
    _mlFeatures = [
      _createBarcodeFeature(),
      //_createFaceDetectionFeature(),
      _compareImage(),
      // Add other features here
    ];
  }

  Map<String, dynamic> _createBarcodeFeature() {
    return {
      'title': 'Barcode Scanning',
      'icon': Icons.qr_code,
      'action': () => _executeBarcodeScanning(),
    };
  }

  Map<String, dynamic> _compareImage() {
    return {
      'title': 'Image Compare',
      'icon': Icons.image,
      'action': () => Navigator.pushReplacementNamed(context, ROUT_DASHBOARD),
    };
  }

  Future<Map<String, dynamic>?> _executeBarcodeScanning() async {
    final inputImage = await _selectImageSource();
    if (inputImage == null) return null;

    final barcodeScanner = BarcodeScanner();
    final barcodes = await barcodeScanner.processImage(inputImage);
    await barcodeScanner.close();

    return {
      'type': 'barcode',
      'results': barcodes.map((barcode) => barcode.displayValue ?? 'No value').toList(),
    };
  }
  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.photos].request();
  }
  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  Future<void> _initCameraWithPermissions() async {
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) {
      if (mounted) {
        setState(() => _errorMessage = 'Camera permission denied');
      }
      return;
    }
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get list of available cameras
      final cameras = await availableCameras();

      // Check if any cameras are available
      if (cameras.isEmpty) {
        throw Exception('No cameras found on this device');
      }

      // Initialize controller with first camera
      _cameraController = CameraController(
        cameras.first, // Safely get first camera
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize camera
      await _cameraController.initialize();

      // Update state if widget is still mounted
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      // Handle errors appropriately
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _errorMessage = 'Failed to initialize camera: ${e.toString()}';
        });
      }
      debugPrint('Camera initialization error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ML Vision Features')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _selectedImage != null
                ? FutureBuilder<Uint8List>(
              future: _selectedImage!.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(snapshot.data!);
                }
                return const Center(child: CircularProgressIndicator());
              },
            )
                : _isCameraInitialized
                ? CameraPreview(_cameraController)
                : _errorMessage.isNotEmpty
                ? Center(child: Text(_errorMessage))
                : const Center(child: CircularProgressIndicator()),
          ),
          Text(
            _currentDetection,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: _mlFeatures.length,
              itemBuilder: (context, index) {
                final feature = _mlFeatures[index];
                return ListTile(
                  title: Text(feature['title']),
                  leading: Icon(feature['icon']),
                  onTap: () async {
                    setState(() => _currentDetection = 'Processing ${feature['title']}...');
                    final results = await feature['action']();
                    setState(() {
                      if (results != null) {
                        _lastResults.add(results);
                        _currentDetection = '${feature['title']} completed';
                      } else {
                        _currentDetection = '${feature['title']} canceled';
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _selectedImage = null;
            _processedImage = null;
          });
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
