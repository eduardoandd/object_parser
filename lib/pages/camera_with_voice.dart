// ignore_for_file: unnecessary_null_comparison, prefer_conditional_assignment

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:picovoice_flutter/picovoice_error.dart';
import 'package:picovoice_flutter/picovoice_manager.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:rhino_flutter/rhino.dart';

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

  
  PicovoiceManager? _picovoiceManager;

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



    // start audio processing
    _picovoiceManager!.start();        
  } on PicovoiceException catch (ex) {
    print(ex.message);
  }
}

void _wakeWordCallback() {
  print("wake word detected!");
}

void _inferenceCallback(RhinoInference inference) {
  if (inference.isUnderstood == true){
    print("Comando reconhecido: ${inference.intent}");
     print("Slots: ${inference.slots}");

  }
  else{
    print("Comando não reconhecido.");
  }
  
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

  return Scaffold(
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
  );
}

}
