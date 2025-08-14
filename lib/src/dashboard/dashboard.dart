import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/vision_service.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  File? _beforeImage;
  File? _afterImage;
  bool _isLoading = false;
  String _cleanlinessStatus = '';
  bool _permissionGranted = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    setState(() {
      _permissionGranted = status.isGranted;
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _permissionGranted = status.isGranted;
    });

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required')),
      );
    }
  }

  Future<void> _captureImage(bool isBeforeImage) async {
    if (!_permissionGranted) {
      await _requestCameraPermission();
      if (!_permissionGranted) return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        setState(() {
          if (isBeforeImage) {
            _beforeImage = File(pickedFile.path);
          } else {
            _afterImage = File(pickedFile.path);
          }
          _cleanlinessStatus = ''; // Reset status when new image is taken
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    }
  }

  Future<void> _checkCleanliness() async {
    if (_beforeImage == null || _afterImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture both before and after images'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _cleanlinessStatus = '';
    });

    try {
      // Call your actual AI API here with both images
      final bool isClean = await _callAICleanlinessAPI(
        _beforeImage!,
        _afterImage!,
      );

      setState(() {
        _cleanlinessStatus = isClean ? 'Room is clean' : 'Room Not Clean';
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error checking cleanliness: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Replace this with your actual API call
  Future<bool> _callAICleanlinessAPI(File beforeImageFile, File afterImageFile) async {
    setState(() {
      _isLoading = true;
      _cleanlinessStatus = 'Analyzing images...'; // Provide feedback
    });

    try {
      // Convert File objects to XFile objects for analyzeImage
      final XFile beforeXFile = XFile(beforeImageFile.path);
      final XFile afterXFile = XFile(afterImageFile.path);

      // Analyze both images
      // You might want to run these in parallel for better performance
      final beforeLabelsFuture = analyzeImage(beforeXFile);
      final afterLabelsFuture = analyzeImage(afterXFile);

      final List<dynamic> beforeLabels = await beforeLabelsFuture;
      final List<dynamic> afterLabels = await afterLabelsFuture;

      // --- Your Logic to Determine Cleanliness ---
      // This is the core part you need to define.
      // How do you compare 'beforeLabels' and 'afterLabels' to decide if the room is clean?
      //
      // Example simple logic:
      // - Look for "clutter", "mess", "dirty" in 'beforeLabels'
      // - Check if these labels are absent or have significantly lower scores in 'afterLabels'
      // - Look for "clean", "tidy" in 'afterLabels'

      print("Before Image Labels: $beforeLabels");
      print("After Image Labels: $afterLabels");

      bool isClean = determineCleanliness(beforeLabels, afterLabels);

      return isClean;

    } catch (e) {
      print("Error in _callAICleanlinessAPI: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analyzing images: ${e.toString()}')),
      );
      return false; // Or throw the error to be caught by _checkCleanliness
    } finally {
      // _isLoading will be set to false in the _checkCleanliness method's finally block
    }
  }

  bool determineCleanliness(List<dynamic> beforeLabels, List<dynamic> afterLabels) {
    // --- Strategy 1: Disappearance of potential clutter ---
    List<String> potentialClutterKeywords = ['plastic', 'trash', 'box', 'paper']; // Expand this list

    bool clutterPresentBefore = false;
    for (var labelMap in beforeLabels) {
      String description = labelMap['description'].toString().toLowerCase();
      double score = labelMap['score'] as double;
      if (potentialClutterKeywords.any((keyword) => description.contains(keyword)) && score > 0.6) { // Adjust score threshold
        clutterPresentBefore = true;
        print("Potential clutter found in BEFORE: $description (Score: $score)");
        break;
      }
    }

    bool clutterStillPresentAfter = false;
    if (clutterPresentBefore) { // Only check 'after' if clutter was seen 'before'
      for (var labelMap in afterLabels) {
        String description = labelMap['description'].toString().toLowerCase();
        double score = labelMap['score'] as double;
        if (potentialClutterKeywords.any((keyword) => description.contains(keyword)) && score > 0.6) {
          clutterStillPresentAfter = true;
          print("Potential clutter STILL found in AFTER: $description (Score: $score)");
          break;
        }
      }
    }

    if (clutterPresentBefore && !clutterStillPresentAfter) {
      print("Verdict: CLEAN (Potential clutter removed)");
      return true; // Clutter was present and is now gone.
    }

    // --- Strategy 2: Appearance of "Clean" indicators (less reliable with current labels) ---
    // List<String> cleanKeywords = ['tidy', 'organized', 'clear surface'];
    // bool looksCleanAfter = afterLabels.any((labelMap) {
    //     String description = labelMap['description'].toString().toLowerCase();
    //     double score = labelMap['score'] as double;
    //     return cleanKeywords.any((keyword) => description.contains(keyword)) && score > 0.7;
    // });

    // if (looksCleanAfter) {
    //     print("Verdict: CLEAN (Positive clean indicators found in AFTER)");
    //     return true;
    // }


    // --- Strategy 3: Significant change in floor visibility/description (more advanced) ---
    // This is harder. You might look for an increase in the "score" or "topicality"
    // of labels like "Floor", "Flooring", "Tile" if you assume a cleaner floor is more visible.
    // Or, if new, more specific floor descriptors appear (like "Marble" or "Tile Flooring"
    // appearing with high scores in 'after' when they weren't prominent in 'before').

    double getScoreForLabel(List<dynamic> labels, String targetDescription) {
      for (var labelMap in labels) {
        if (labelMap['description'].toString().toLowerCase() == targetDescription.toLowerCase()) {
          return labelMap['score'] as double;
        }
      }
      return 0.0; // Label not found
    }

    double beforeFloorScore = getScoreForLabel(beforeLabels, 'floor');
    double afterFloorScore = getScoreForLabel(afterLabels, 'floor');
    // Example: If floor score significantly increases, it might imply it's clearer
    // if (afterFloorScore > beforeFloorScore + 0.15 && afterFloorScore > 0.85) {
    //     print("Verdict: CLEAN (Floor visibility/prominence increased)");
    //     return true;
    // }


    print("Verdict: NOT CLEAN (No clear indicators of cleaning detected based on current logic)");
    return false; // Default to not clean
  }

  Widget _buildImageComparison() {
    if (_beforeImage == null && _afterImage == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text('No images captured'),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Before Image
        Expanded(
          child: Column(
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    _beforeImage == null
                        ? const Center(child: Text('No before image'))
                        : Image.file(_beforeImage!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 4),
              const Text(
                'BEFORE',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // After Image
        Expanded(
          child: Column(
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    _afterImage == null
                        ? const Center(child: Text('No after image'))
                        : Image.file(_afterImage!, fit: BoxFit.cover),
              ),
              const SizedBox(height: 4),
              const Text(
                'AFTER',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cleanliness Comparison'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.white54,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image display section
            _buildImageComparison(),
            const SizedBox(height: 24),

            // Before Image Button
            ElevatedButton.icon(
              onPressed: () => _captureImage(true),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Before Image'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),

            // After Image Button
            ElevatedButton.icon(
              onPressed: () => _captureImage(false),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture After Image'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            // Check Cleanliness Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _checkCleanliness,
              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Icon(Icons.compare),
              label: Text(_isLoading ? 'Comparing...' : 'Compare Cleanliness'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),

            if (_cleanlinessStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _cleanlinessStatus == 'Room is clean'
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _cleanlinessStatus == 'Room is clean'
                            ? Colors.green
                            : Colors.red,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _cleanlinessStatus == 'Room is clean'
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _cleanlinessStatus == 'Room is clean'
                              ? Colors.green
                              : Colors.red,
                      size: 30,
                    ),
                    Expanded(
                      child: Text(
                        _cleanlinessStatus,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              _cleanlinessStatus == 'Room is clean'
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
