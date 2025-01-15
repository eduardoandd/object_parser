import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraService {
  late CameraController _cameraController;
  late CameraDescription frontCamera;
  late CameraDescription backCamera;



  Future<void> switchCamera(CameraDescription currentCamera,CameraDescription frontCamera, CameraDescription backCamera) async {
    CameraDescription newCamera =
        currentCamera.lensDirection == CameraLensDirection.back
            ? frontCamera
            : backCamera;
    await initializeCamera(newCamera);
  }

  Future<void> setFocusPoint(Offset point) async {
    await _cameraController.setFocusPoint(point);
  }

  Future<void> getAvailableCameras(List<CameraDescription> cameras) async {
    for (var i = 0; i< cameras.length; i++){
      var camera = cameras[i];
      if(camera.lensDirection == CameraLensDirection.back){
        backCamera= camera;
      }
      if(camera.lensDirection == CameraLensDirection.front){
        frontCamera = camera;
      }
    }
    backCamera ??= cameras.first;
    frontCamera ??= cameras.last;

    await initializeCamera(backCamera);
  }

  Future<void> initializeCamera(CameraDescription camera) async {
    _cameraController = CameraController(camera, ResolutionPreset.ultraHigh);
    await _cameraController.initialize();
  }

  CameraController get cameraController => _cameraController;
}
