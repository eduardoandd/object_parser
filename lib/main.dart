import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:object_parser/pages/camera_with_voice.dart';
// import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
// import 'package:just_audio/just_audio.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras =await availableCameras();
  runApp( MyApp(cameras: cameras,));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CameraWithVoiceControl(cameras: cameras,),
      ),
    );
  }
}

  