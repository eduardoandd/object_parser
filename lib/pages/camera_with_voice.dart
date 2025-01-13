// ignore_for_file: unnecessary_null_comparison, prefer_conditional_assignment

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:picovoice_flutter/picovoice_error.dart';
import 'package:picovoice_flutter/picovoice_manager.dart';
import 'package:screenshot/screenshot.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:rhino_flutter/rhino.dart';
import 'package:http/http.dart' as http;


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

  final String accessKey = 'A2hg2EegEJdd3N8RvgHnD36v+7jUwnbyMZrfM4f3TQfh+mAdFD2YJQ==';
  // String platform = Platform.isAndroid ? "android" : "ios";

  String keywordPath = "assets/Glauco_pt_android_v3_0_0.ppn";
  String contextPath = "assets/Magic-Camera_pt_android_v3_0_0.rhn"; 
  String porcupineModelPath = "assets/porcupine_params_pt.pv"; 
  String rhinoModelPath = "assets/rhino_params_pt.pv";
  FlutterSoundRecorder? _audioRecorder; 
  bool _isRecording = false;
  final ScreenshotController _screenshotController = ScreenshotController();
  File? file;
  bool isUploading = false;



  PicovoiceManager? _picovoiceManager;

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
        final filePath = '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
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

Future<void> uploadAudioAndImage(File file) async{
    if(file == null){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("imagem ou audio não reconhecidos!"))
      );
      return;
    }
   
    setState(() {
      isUploading = true;
    });

    try {
      final uri = Uri.parse('http://192.168.0.220:8000/object_img/');
      var request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image',file.path));
        // ..files.add(await http.MultipartFile.fromPath('audio', recordedFilePath));

        final response = await request.send();
        if(response.statusCode == 201){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload realizado com sucesso!")),
          );
        }
        else{
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erro no upload: ${response.statusCode}")),
          );
        }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao enviar: $e")),
      );
      print(e);
    }
    finally {
      setState(() {
        isUploading = false;
      });
    }
  }



  void _initPicovoice() async {
  try {
    _picovoiceManager = await PicovoiceManager.create(
        accessKey,
        keywordPath, 
        _wakeWordCallback, 
        contextPath, 
        _inferenceCallback, 
        porcupineModelPath: porcupineModelPath,
        rhinoModelPath: rhinoModelPath
      );
      _audioRecorder = FlutterSoundRecorder();

    // start audio processing
    _picovoiceManager!.start();        
  } on PicovoiceException catch (ex) {
    print(ex.message);
  }
}

Future<void> _wakeWordCallback() async  {
    await _screenShotPage();
    await uploadAudioAndImage(file!);
}

void _inferenceCallback(RhinoInference inference) {
  print(inference);
  
}
  
  @override
  void initState() {
    cameraController =
        CameraController(widget.cameras[0], ResolutionPreset.high);
    cameraValue = cameraController.initialize();
    _initPicovoice();

    getAvailableCamera();
    super.initState();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
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
                final Offset localPosition = box.globalToLocal(details.globalPosition);
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
                quarterTurns: cameraController.description.lensDirection == CameraLensDirection.back ? 1 : 3,
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
                    if (cameraController.description.lensDirection == CameraLensDirection.back) {
                      cameraController = CameraController(frontCamera, ResolutionPreset.high);
                    } else {
                      cameraController = CameraController(backCamera, ResolutionPreset.high);
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
