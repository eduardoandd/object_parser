// ignore_for_file: unnecessary_null_comparison, prefer_conditional_assignment

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_parser/pages/ai_response_page.dart';
import 'package:object_parser/services/audio_download_service.dart';
import 'package:object_parser/services/camera_service.dart';
import 'package:object_parser/services/screenshot_service.dart';
import 'package:object_parser/services/speech_to_text_service.dart';
import 'package:object_parser/services/upload_service.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:screenshot/screenshot.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class CameraWithVoiceControl extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraWithVoiceControl({super.key, required this.cameras});

  @override
  State<CameraWithVoiceControl> createState() => _CameraWithVoiceControlState();
}

class _CameraWithVoiceControlState extends State<CameraWithVoiceControl> {
  late CameraDescription backCamera, frontCamera;
  late AudioDownloadService _audioDownloadService = AudioDownloadService();
  late UploadService _uploadService = UploadService();
  late ScreenshotService _screenshotService = ScreenshotService();
  final CameraService _cameraService = CameraService();
  late PorcupineManager _porcupineManager;
  late SpeechRecognitionService _speechRecognitionService;

  final String accessKey =
      'A2hg2EegEJdd3N8RvgHnD36v+7jUwnbyMZrfM4f3TQfh+mAdFD2YJQ==';
  String keywordPath = "assets/teste_pt_android_v3_0_0.ppn";
  String contextPath = "assets/Magic-Camera_pt_android_v3_0_0.rhn";
  String porcupineModelPath = "assets/porcupine_params_pt.pv";

  File? file;
  bool isUploading = false;
  String recordedFilePath = '';
  late stt.SpeechToText speech;
  bool isListening = false;
  String text = '';

  @override
  void initState() {
    _speechRecognitionService = SpeechRecognitionService();
    _audioDownloadService = AudioDownloadService();
    _uploadService = UploadService();
    _screenshotService = ScreenshotService();
    _checkAudioPermission();
    createPorcupineManager();
    speech = stt.SpeechToText();
    _initializeCamera();
    super.initState();
  }

  @override
  void dispose() {
    _porcupineManager.stop();
    _speechRecognitionService.stopListening();
    // _porcupineManager.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    await _cameraService.getAvailableCameras(widget.cameras);
    setState(() {});
  }

   void startListening() async {
    await Future.delayed(const Duration(seconds: 2));
    bool initialized = await _speechRecognitionService.initialize();
    if (!initialized) {
      print("Falha ao inicializar o reconhecimento de fala.");
      return;
    }

    setState(() {
      isListening = true;
      text = ''; // Limpa o texto antes de começar
    });

    _speechRecognitionService.startListening(
      (recognizedText) {
        setState(() {
          text = recognizedText;
        });
      },
      () async {
        print('Parando o áudio...');
        await _porcupineManager.start();
        await _screenCapture();
        await _uploadService.uploadImageAndText(file!, text);
        await _audioDownloadService.downloadAudio();
        final String downloadedFilePath = await _audioDownloadService.downloadAudio();
        _goToAiResponse(downloadedFilePath);
      },
    );
  }

  _goToAiResponse(String downloadedFilePath) {
    _porcupineManager.stop();
    if (downloadedFilePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("imagem ou audio não reconhecidos!")));
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AiResponsePage(audioFilePath: downloadedFilePath),
        ),
      ).then((_){
        _porcupineManager.start();
        setState(() {
          isListening = false;
        });
      });
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex >= 0) {
      print("palavra reconhecida!");
      _porcupineManager.stop();

      if (!isListening) {
        startListening();
      } else {
        print("Audio em escuta");
      }
    }
  }

  void createPorcupineManager() async {
    try {
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
          accessKey, [keywordPath], _wakeWordCallback,
          modelPath: porcupineModelPath);

      await _porcupineManager.start();
    } on PorcupineException catch (err) {
      print(err.message);
    }
  }

  Future<bool> _checkAudioPermission() async {
    bool permissionGranted = await Permission.microphone.isGranted;
    if (!permissionGranted) {
      await Permission.microphone.request();
    }
    permissionGranted = await Permission.microphone.isGranted;
    return permissionGranted;
  }

  Future<void> _screenCapture() async {
    final capturedFile = await _screenshotService.captureAndSaveScreenshot();
    if (capturedFile != null) {
      setState(() {
        file = capturedFile;
      });
    } else {
      print("Erro ao capturar a screenshot.");
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_cameraService.cameraController.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Screenshot(
      controller: _screenshotService.screenshotController,
      child: Scaffold(
        appBar: AppBar(
          title: Center(child: Text('Magic Camera')),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (TapDownDetails details) async {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final Offset localPosition =
                      box.globalToLocal(details.globalPosition);
                  final Size size = box.size;

                  final double x = localPosition.dx / size.width;
                  final double y = localPosition.dy / size.height;

                  try {
                    await _cameraService.setFocusPoint(Offset(x, y));
                  } catch (e) {
                    print('Erro ao definir ponto de foco: $e');
                  }
                },
                child: RotatedBox(
                  quarterTurns: _cameraService
                              .cameraController.description.lensDirection ==
                          CameraLensDirection.back
                      ? 1
                      : 3,
                  child: CameraPreview(_cameraService.cameraController),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await _cameraService.switchCamera(
                          _cameraService.cameraController.description,
                          _cameraService.frontCamera,
                          _cameraService.backCamera);
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      shape: CircleBorder(),
                      padding: EdgeInsets.all(16),
                    ),
                    child: Icon(Icons.flip_camera_android, color: Colors.white),
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