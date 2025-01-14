// ignore_for_file: unnecessary_null_comparison, prefer_conditional_assignment

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picovoice_flutter/picovoice_error.dart';
import 'package:picovoice_flutter/picovoice_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:screenshot/screenshot.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:rhino_flutter/rhino.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:object_parser/pages/camera_with_voice.dart';
// import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CameraWithVoiceControl extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraWithVoiceControl({super.key, required this.cameras});

  @override
  State<CameraWithVoiceControl> createState() => _CameraWithVoiceControlState();
}

class _CameraWithVoiceControlState extends State<CameraWithVoiceControl> {
  late CameraController cameraController;
  late CameraDescription backCamera, frontCamera;
  late Future<void> cameraValue;

  final String accessKey =
      'A2hg2EegEJdd3N8RvgHnD36v+7jUwnbyMZrfM4f3TQfh+mAdFD2YJQ==';
  // String platform = Platform.isAndroid ? "android" : "ios";

  String keywordPath = "assets/teste_pt_android_v3_0_0.ppn";
  String contextPath = "assets/Magic-Camera_pt_android_v3_0_0.rhn";
  String porcupineModelPath = "assets/porcupine_params_pt.pv";
  String rhinoModelPath = "assets/rhino_params_pt.pv";

  bool _isRecording = false;
  final ScreenshotController _screenshotController = ScreenshotController();
  File? file;
  bool isUploading = false;
  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer player = FlutterSoundPlayer();
  String recordedFilePath = '';
  late stt.SpeechToText speech;
  bool isListening = false;
  String text = '';

  @override
  void initState() {
    _checkAudioPermission();
    cameraController =
        CameraController(widget.cameras[0], ResolutionPreset.high);
    cameraValue = cameraController.initialize();
    getAvailableCamera();
    initRecorder();
    createPorcupineManager();
    speech = stt.SpeechToText();
    super.initState();
  }

  @override
  void dispose() {
    cameraController.dispose();
    _porcupineManager.stop();
    // _porcupineManager.dispose();
    super.dispose();
  }

  late PorcupineManager _porcupineManager;

  void startListening() async {
    await Future.delayed(const Duration(seconds: 2));
    print("iniciaindo");
    bool available = await speech.initialize();
    if (available) {
      setState(() {
        isListening = true;
        text = ''; // Limpa o texto antes de começar
      });

      speech.listen(
        onResult: (result) {
          setState(() {
            text = result.recognizedWords;
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation, // Detecta pausas para finalizar
          cancelOnError: true, 
        ),
      );

      speech.statusListener = (status) {
        if (status == 'notListening') {
          print('Parando o audio....');

          setState(() {
            isListening = false;
          });
          setState(() {
            text = text;
            print(text);
          });
          
          _porcupineManager.start();
          
        }
      };
    }
    await _screenShotPage();
    await uploadAudioAndImage(file!, text);
  }

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex >= 0) {
      print("palavra reconhecida!");
      _porcupineManager.stop();
      startListening();
      
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

  Future<void> initRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException(
          'Permissão para usar o microfone negada');
    }
    await recorder.openRecorder();
  }

  Future<void> startRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/audio_recording.aac';
    final wavPath = path.replaceAll('.aac', '.wav');
    await recorder.startRecorder(toFile: wavPath, codec: Codec.pcm16WAV);

    setState(() {
      _isRecording = true;
      recordedFilePath = wavPath;
    });
  }

  

  Future<void> _screenShotPage() async {
    print("Wake word detected!");

    try {
      // Capture the screenshot
      final image = await _screenshotController.capture();
      if (image != null) {
        // Get the directory to save the file
        final directory = await getExternalStorageDirectory(); // Para Android
        // final directory = await getApplicationDocumentsDirectory(); // Para iOS

        if (directory != null) {
          final filePath =
              '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
          file = File(filePath);
          setState(() {});
          await file!.writeAsBytes(image);
          print("Screenshot salva em: $filePath");
        } else {
          print("Não foi possível acessar o diretório.");
        }
      } else {
        print("Falha ao capturar a screenshot.");
      }
    } catch (e) {
      print("Erro ao salvar a screenshot: $e");
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


  void getAvailableCamera() async {
    for (var i = 0; i < widget.cameras.length; i++) {
      var camera = widget.cameras[i];
      if (camera.lensDirection == CameraLensDirection.back) {
        backCamera = camera;
      }
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
      }
    }
    if (backCamera == null) {
      backCamera = widget.cameras.first;
    }
    if (frontCamera == null) {
      frontCamera = widget.cameras.last;
    }
    cameraController = CameraController(backCamera, ResolutionPreset.medium);

    cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!cameraController.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Screenshot(
      controller: _screenshotController,
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

                  // Calcula coordenadas normalizadas
                  final double x = localPosition.dx / size.width;
                  final double y = localPosition.dy / size.height;

                  try {
                    await cameraController.setFocusPoint(Offset(x, y));
                  } catch (e) {
                    print('Erro ao definir ponto de foco: $e');
                  }
                },
                child: RotatedBox(
                  quarterTurns: cameraController.description.lensDirection ==
                          CameraLensDirection.back
                      ? 1
                      : 3,
                  child: CameraPreview(cameraController),
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
                      if (cameraController.description.lensDirection ==
                          CameraLensDirection.back) {
                        cameraController = CameraController(
                            frontCamera, ResolutionPreset.high);
                      } else {
                        cameraController =
                            CameraController(backCamera, ResolutionPreset.high);
                      }

                      await cameraController.initialize();
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
