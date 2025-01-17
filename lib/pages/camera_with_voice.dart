// ignore_for_file: unnecessary_null_comparison, prefer_conditional_assignment

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_parser/pages/ai_response_page.dart';
import 'package:object_parser/services/audio_download_service.dart';
import 'package:object_parser/services/camera_service.dart';
import 'package:object_parser/services/screenshot_service.dart';
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
    // _porcupineManager.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    await _cameraService.getAvailableCameras(widget.cameras);
    setState(() {});
  }

  void startListening() async {
    await Future.delayed(const Duration(seconds: 2));
    print("Iniciando...");

    bool available = await speech.initialize();
    if (!available) {
      print("Falha ao inicializar o reconhecimento de fala.");
      return;
    }

    setState(() {
      isListening = true;
      text = ''; // Limpa o texto antes de começar
    });

    speech.statusListener = (status) async {
      if (status == 'notListening') {
        print('Parando o áudio...');
        setState(() {
          isListening = false;
        });

        // Aguarde o término antes de prosseguir
        await speech.stop();
        print('Texto reconhecido: $text');

        _porcupineManager.start();
        await _screenCapture();
        await _uploadService.uploadImageAndText(file!, text);
        await _audioDownloadService.downloadAudio();
        final String downloadedFilePath =
            await _audioDownloadService.downloadAudio();
        _goToAiResponse(downloadedFilePath);
      }
    };

    speech.listen(
      onResult: (result) {
        setState(() {
          text = result.recognizedWords;
        });
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  _goToAiResponse(String downloadedFilePath) {
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
      );
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

  Future<void> uploadAudioAndImage(File file, String text) async {
    if (text.isEmpty || file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("imagem ou audio não reconhecidos!")));
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      final uri = Uri.parse('http://192.168.0.220:8000/object_img/');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      request.fields['text'] = text;
      final response = await request.send();
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload realizado com sucesso!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro no upload: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar: $e")),
      );
      print(e);
    } finally {
      setState(() {
        isUploading = false;
      });
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
