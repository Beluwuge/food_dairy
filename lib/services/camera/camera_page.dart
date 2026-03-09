import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'dish_details_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _takingPhoto = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();

      final back = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initializing = false);
      _showError('Camera init failed');
    }
  }

  Future<void> _snap() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_takingPhoto) return;

    setState(() => _takingPhoto = true);

    try {
      final xfile = await controller.takePicture();

      final tempPath = xfile.path;

      // Persistent storage
      final docs = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(docs.path, 'dish_images'));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final filename =
          'dish_${DateTime.now().millisecondsSinceEpoch}${p.extension(tempPath)}';

      final newPath = p.join(imagesDir.path, filename);

      await File(tempPath).copy(newPath);

      // IMPORTANT: delete temp camera file
      try {
        await File(tempPath).delete();
      } catch (_) {}

      if (!mounted) return;

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DishDetailsPage(imagePath: newPath),
        ),
      );

      // If user cancels post, delete unused image
      if (saved != true) {
        try {
          final f = File(newPath);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      _showError('Failed to take photo');
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  void _showError(String msg) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: const Center(child: Text('Camera not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(controller),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: GestureDetector(
                onTap: _takingPhoto ? null : _snap,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 4, color: Colors.white),
                    color: _takingPhoto ? Colors.white24 : Colors.white10,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}