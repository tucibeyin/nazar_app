import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/ayet.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Ayet? _ayet;
  bool _isLoading = false;
  bool _isPlaying = false;
  int _cameraIndex = 0;

  static const _green = Color(0xFF1B4B3E);
  static const _bg = Color(0xFFF5F0E8);

  @override
  void initState() {
    super.initState();
    _cameraIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;
    _initCamera(_cameraIndex);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  Future<void> _initCamera(int index) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(
      widget.cameras[index],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _initCamera(_cameraIndex);
  }

  Future<void> _exitApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış', style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
        content: const Text('Uygulamadan çıkmak istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hayır', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Evet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _audioPlayer.stop();
    await _cameraController?.dispose();
    exit(0);
  }

  Future<void> _analyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    setState(() {
      _isLoading = true;
      _ayet = null;
    });

    try {
      final photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      final digest = sha256.convert(bytes);
      final first8 = Uint8List.fromList(digest.bytes.sublist(0, 8));
      final hashInt = ByteData.sublistView(first8).getInt64(0, Endian.big).abs();

      final uri = Uri.parse(ApiConfig.nazarEndpoint(hashInt));
      final response = await http.get(uri);

      if (response.statusCode != 200) throw Exception('Sunucu hatası: ${response.statusCode}');

      final ayet = Ayet.fromJson(jsonDecode(response.body));
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(ApiConfig.audioUrl(ayet.mp3Url)));

      setState(() => _ayet = ayet);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildCameraPreview(),
              _buildButton(),
              if (_ayet != null) _buildResultPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.flip_camera_ios_rounded, color: _green, size: 26),
            tooltip: 'Kamera Değiştir',
          ),
          const Expanded(
            child: Text(
              'Nazar & Ferahlama',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _green,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: _exitApp,
            icon: const Icon(Icons.close_rounded, color: _green, size: 26),
            tooltip: 'Çıkış',
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    final ratio = _cameraController!.value.aspectRatio;
    final portraitRatio = ratio < 1 ? ratio : 1 / ratio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: portraitRatio,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _analyze,
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _green.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Nazarımı Oku / Analiz Et',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    final ayet = _ayet!;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ayet.sureIsim,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleAudio,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: _green,
                    size: 34,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ayet.arapca,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 22,
                height: 2.2,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: Color(0xFFE0D8CC)),
            ),
            Text(
              ayet.meal,
              style: const TextStyle(
                fontSize: 14,
                height: 1.7,
                color: Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
