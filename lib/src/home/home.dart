
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:translator/translator.dart';
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
  final _apiKey = dotenv.env['GOOGLE_API_KEY'];
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
      _createFaceDetectionFeature(),
      _createTextRecognitionFeature(), // Add this line
      _compareImage(),
      // Add other features here
    ];
  }

  Map<String, dynamic> _createBarcodeFeature() {
    return {
      'title': 'Barcode Scanning',
      'icon': Icons.qr_code,
      'action': () => _processBarcodeScanning(), // Now returns Future<Map>
    };
  }

  Map<String, dynamic> _createFaceDetectionFeature() {
    return {
      'title': 'Face Detection',
      'icon': Icons.face,
      'action': () => _processFaceDetection(),
    };
  }

  Map<String, dynamic> _createTextRecognitionFeature() {
    return {
      'title': 'Text Recognition',
      'icon': Icons.text_fields,
      'action': _processTextRecognitionWithTranslation,
    };
  }

  Map<String, dynamic> _compareImage() {
    return {
      'title': 'Image Compare',
      'icon': Icons.image,
      'action': () => Navigator.pushReplacementNamed(context, ROUT_DASHBOARD),
    };
  }

  Future<Map<String, dynamic>?> _processBarcodeScanning() async {
    try {
      final inputImage = await _selectImageSource();
      if (inputImage == null) return null;

      final barcodeScanner = BarcodeScanner();
      final barcodes = await barcodeScanner.processImage(inputImage);
      await barcodeScanner.close();

      return {
        'type': 'barcode',
        'results': barcodes.map((barcode) => barcode.displayValue ?? 'No value').toList(),
      };
    } catch (e) {
      debugPrint('Barcode scanning error: $e');
      return {
        'type': 'barcode',
        'error': e.toString(),
      };
    }
  }


  Future<Map<String, dynamic>?> _processFaceDetection() async {
    try {
      final inputImage = await _selectImageSource();
      if (inputImage == null) return null;

      final options = FaceDetectorOptions(performanceMode: FaceDetectorMode.fast);
      final faceDetector = FaceDetector(options: options);
      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      return {
        'type': 'face',
        'results': faces.map((face) {
          return {
            'boundingBox': face.boundingBox,
            'landmarks': face.landmarks.entries.map((entry) {
              return {
                'type': entry.key.toString(),
                'position': {
                  'x': entry.value?.position.x,
                  'y': entry.value?.position.y,
                }
              };
            }).toList(),
            'headEulerAngleY': face.headEulerAngleY,
            'headEulerAngleZ': face.headEulerAngleZ,
          };
        }).toList(),
      };
    }catch (e) {
      debugPrint('Face detection error: $e');
      return {
        'type': 'face',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>?> _processTextRecognitionWithTranslation() async {
    try {
      final inputImage = await _selectImageSource();
      if (inputImage == null) return null;

      setState(() => _currentDetection = 'Processing text...');

      // Recognize text from image
      final textBlocks = await recognizeText(XFile(inputImage.filePath!));
      final fullText = textBlocks.map((block) => block['text']).join('\n');

      if (fullText.isEmpty) {
        return {
          'type': 'text',
          'error': 'No text detected in the image',
        };
      }

      // Detect language and translate to Marathi
      setState(() => _currentDetection = 'Translating to Marathi...');
      final detectedLanguage = await _detectLanguage(fullText);
      final translatedText = await _translateToMarathi(fullText);

      return {
        'type': 'text',
        'fullText': fullText,
        'translatedText': translatedText,
        'detectedLanguage': detectedLanguage,
        'results': textBlocks,
      };
    } catch (e) {
      debugPrint('Text recognition with translation error: $e');
      return {
        'type': 'text',
        'error': e.toString(),
      };
    }
  }

  Future<String> _detectLanguage(String text) async {
    try {
      // Simple language detection based on character ranges
      if (text.contains(RegExp(r'[ऀ-ॿ]'))) {
        return 'Marathi';
      } else if (text.contains(RegExp(r'[अ-ह]'))) {
        return 'Hindi';
      } else if (text.contains(RegExp(r'[a-zA-Z]'))) {
        return 'English';
      }

      // Fallback to Google Translate language detection
      return await _detectLanguageWithAPI(text);
    } catch (e) {
      debugPrint('Language detection error: $e');
      return 'Unknown';
    }
  }


  Future<String> _detectLanguageWithAPI(String text) async {
    try {
      final response = await http.post(
        Uri.parse('https://translation.googleapis.com/language/translate/v2/detect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'key': _apiKey,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final languageCode = data['data']['detections'][0][0]['language'];
        return _getLanguageName(languageCode);
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getLanguageName(String languageCode) {
    final languageMap = {
      'en': 'English',
      'mr': 'Marathi',
      'hi': 'Hindi',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
    };
    return languageMap[languageCode] ?? languageCode;
  }

  Future<String> _translateToMarathi(String text) async {
    try {
      final translation = await GoogleTranslator().translate(
        text,
        to: 'mr', // Marathi
      );
      return translation.text;
    } catch (e) {
      debugPrint('Translation error: $e');
      throw Exception('Failed to translate text: $e');
    }
  }

  Future<List<Map<String, dynamic>>> recognizeText(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin); // For Latin scripts

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final List<Map<String, dynamic>> textBlocks = [];

      for (TextBlock block in recognizedText.blocks) {
        textBlocks.add({
          'text': block.text,
          'language': block.recognizedLanguages.isNotEmpty
              ? block.recognizedLanguages.first
              : 'Unknown',
          'boundingBox': block.boundingBox,
        });
      }

      await textRecognizer.close();
      return textBlocks;
    } catch (e) {
      await textRecognizer.close();
      debugPrint('Text recognition error: $e');
      rethrow;
    }
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

  void _showResultsDialog(Map<String, dynamic> results) {
    final type = results['type'];
    final resultData = results['results'];

    if (type == 'barcode') {
      _showBarcodeResults(resultData as List<String>);
    } else if (type == 'face') {
      _showFaceResults(resultData as List<dynamic>);
    } else if(type == 'text') {
      _showTextResults(results);
    }
  }

  void _showBarcodeResults(List<String> barcodes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Barcode Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (barcodes.isEmpty)
              const Text('No barcodes detected')
            else
              ...barcodes.map((code) => Text(code)),
          ],
        ),
      ),
    );
  }

  void _showFaceResults(List<dynamic> faces) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${faces.length} Face(s) Detected'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              for (final face in faces)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildFaceInfo(face),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTextResults(Map<String, dynamic> results) {
    if (results.containsKey('error')) {
      _showErrorDialog(results['error']);
      return;
    }

    final fullText = results['fullText']?.toString() ?? 'No text detected';
    final translatedText = results['translatedText']?.toString() ?? 'Translation not available';
    final detectedLanguage = results['detectedLanguage']?.toString() ?? 'Unknown';
    final textBlocks = results['results'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Text Recognition Results'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detected Language
              Row(
                children: [
                  const Icon(Icons.language, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Detected Language: $detectedLanguage',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Original Text
              const Text('Original Text:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(fullText),
              const SizedBox(height: 16),

              // Marathi Translation
              const Text('Marathi Translation:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                translatedText,
                style: const TextStyle(fontSize: 16, color: Colors.green),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        actions: [
          // Copy Original Text
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy original text',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Original text copied')),
              );
            },
          ),

          // Copy Translation
          IconButton(
            icon: const Icon(Icons.translate, size: 20),
            tooltip: 'Copy translation',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: translatedText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Translation copied')),
              );
            },
          ),

          // OK Button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                        _showResultsDialog(results);
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

Widget _buildFaceInfo(Map<String, dynamic> face) {
  // Convert angles to human-readable directions
  String getHeadDirection(double? yAngle, double? zAngle) {
    if (yAngle == null || zAngle == null) return 'Facing forward';

    if (yAngle.abs() > 30) {
      return yAngle > 0 ? 'Looking right' : 'Looking left';
    } else if (zAngle.abs() > 15) {
      return zAngle > 0 ? 'Looking up' : 'Looking down';
    }
    return 'Facing forward';
  }

  // Count visible landmarks
  final landmarkCount = face['landmarks']?.length ?? 0;
  final hasSmile = face['smilingProbability'] != null
      && face['smilingProbability'] > 0.7;
  final leftEyeOpen = face['leftEyeOpenProbability'] != null
      && face['leftEyeOpenProbability'] > 0.7;
  final rightEyeOpen = face['rightEyeOpenProbability'] != null
      && face['rightEyeOpenProbability'] > 0.7;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Face detected', style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 4),
      Text('• ${getHeadDirection(face['headEulerAngleY'], face['headEulerAngleZ'])}'),
      Text('• ${landmarkCount} facial features detected'),
      if (hasSmile) Text('• Person is smiling'),
      if (leftEyeOpen && rightEyeOpen)
        Text('• Eyes are open'),
      if (!leftEyeOpen || !rightEyeOpen)
        Text('• Eyes are ${!leftEyeOpen && !rightEyeOpen ? 'closed' : 'partially open'}'),
      SizedBox(height: 8),
    ],
  );
}

