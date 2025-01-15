import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_parser/services/audio_download_service.dart';
import 'package:object_parser/services/audio_permission_service.dart';
import 'package:object_parser/services/camera_service.dart';
import 'package:object_parser/services/listener_service.dart';
import 'package:object_parser/services/screenshot_service.dart';
import 'package:object_parser/services/upload_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:screenshot/screenshot.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraWithVoiceControl extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraWithVoiceControl({super.key, required this.cameras});

  @override
  State<CameraWithVoiceControl> createState() => _CameraWithVoiceControlState();
}

class _CameraWithVoiceControlState extends State<CameraWithVoiceControl> {
  final AudioPermissionService _audioPermissionService =
      AudioPermissionService();
  final ScreenshotService _screenshotService = ScreenshotService();
  late CameraService _cameraService;
  late ListenerService _listenerService;
  late CameraDescription backCamera, frontCamera;
  String recognizedText = '';
  late AudioDownloadService _audioDownloadService;
  late UploadService _uploadService;

  late Future<void> cameraValue;

  final String accessKey =
      'A2hg2EegEJdd3N8RvgHnD36v+7jUwnbyMZrfM4f3TQfh+mAdFD2YJQ==';
  // String platform = Platform.isAndroid ? "android" : "ios";

  String keywordPath = "assets/teste_pt_android_v3_0_0.ppn";
  String contextPath = "assets/Magic-Camera_pt_android_v3_0_0.rhn";
  String porcupineModelPath = "assets/porcupine_params_pt.pv";
  String rhinoModelPath = "assets/rhino_params_pt.pv";

  File? file;
  bool isUploading = false;
  final FlutterSoundPlayer player = FlutterSoundPlayer();
  late stt.SpeechToText speech;
  bool isListening = false;
  String text = '';
  String downloadPath = '';


  @override
  void initState() {
    _initializePermission();
    _cameraService = CameraService();
    _initializeCamera();
    _listenerService = ListenerService();
    _audioDownloadService = AudioDownloadService();
    _uploadService = UploadService();
    _initializeVoiceRecognition();
    createPorcupineManager();
    speech = stt.SpeechToText();
    super.initState();
  }

  @override
  void dispose() {
    _cameraService.cameraController.dispose();
    _porcupineManager.stop();
    // _porcupineManager.dispose();
    super.dispose();
  }

  Future<void> _initializeVoiceRecognition() async {
    bool available = await _listenerService.initialize();
    if(!available){
      print("Erro ao inicializar o reconhecimento de voz.");
    }
  }

  void _startListening(){
    _listenerService.startListening((text){
      setState(() {
        recognizedText = text;
        print(recognizedText);
      _porcupineManager.start();

      });
    });
    
  }

  // void _stopListening(){
  //   _listenerService.stopListening();
  // }

  Future<void> _initializeCamera() async {
    await _cameraService.getAvailableCameras(widget.cameras);
    setState(() {});
  }

  _initializePermission() async {
    final hasAudioPermission =
        await _audioPermissionService.checkAndRequestPermission();
    if (!hasAudioPermission) {
      print("Permissão de áudio negada.");
      return;
    }
  }

  late PorcupineManager _porcupineManager;

  // void startListening() async {
  //   await Future.delayed(const Duration(seconds: 2));
  //   print("iniciaindo");
  //   bool available = await speech.initialize();
  //   if (available) {
  //     setState(() {
  //       isListening = true;
  //       text = '';
  //     });

  //     speech.listen(
  //       onResult: (result) {
  //         setState(() {
  //           text = result.recognizedWords;
  //         });
  //       },
  //     );

  //     speech.statusListener = (status) {
  //       if (status == 'notListening') {
  //         print('Parando o audio....');

  //         setState(() {
  //           isListening = false;
  //         });
  //         setState(() {
  //           text = text;
  //           print(text);
  //         });

  //       }
  //     };
  //   }
  //   await _screenCapture();
  //   await uploadAudioAndImage(file!, text);
  //   await downloadAudio(audioUrl);
  // }

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex >= 0) {
      print("palavra reconhecida!");
      _porcupineManager.stop();
      _startListening();
      _CaptureScreen();
      _uploadData();
      _donwloadAudio();
    }
  }

  Future<void> _donwloadAudio() async{
    await _audioDownloadService.downloadAudio();
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

  Future<void> _CaptureScreen() async {
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

  Future<void> downloadAudio(String audioUrl) async {
    try {
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        final downloadDirectory = Directory('${directory!.path}/Download');
        if (!await downloadDirectory.exists()) {
          await downloadDirectory.create(recursive: true);
        }
        final filePath = '${downloadDirectory.path}/ai_response.mp3';

        setState(() {
          downloadPath = filePath;
        });

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Áudio baixado com sucesso! Salvo em: $filePath')),
        );
        final player = AudioPlayer();
        await player.play(DeviceFileSource(filePath));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao baixar o áudio: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar o áudio: $e')),
      );
    }
  }

  Future<void> _uploadData() async{
    if(file == null || recognizedText.isEmpty){
      print("Imagem ou texto não disponíveis.");
      return;
    }
    _uploadService.uploadImageAndText(file!, text);
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
                          _cameraService.backCamera,
                      );
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
