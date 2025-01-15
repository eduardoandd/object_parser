import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';

class ScreenshotService {
  // Print há ser analisada
  final ScreenshotController _screenshotController = ScreenshotController();
  
  Future<File?> captureAndSaveScreenshot() async {

    try {
      final image = await _screenshotController.capture();

      if(image == null){
        debugPrint("Falha ao capturar a screenshot");
        return null;
      }

      final dir = await getExternalStorageDirectory();
      if(dir == null){
        debugPrint("Não foi possível acessar o diretório.");
        return null;
      }
      
      final filePath = '${dir.path}/screenshot.png';
      final file = File(filePath);
      await file.writeAsBytes(image);
      debugPrint("Screenshot salva em: $filePath");

      return file;
      
    } catch (e) {
      debugPrint("Erro ao capturar e salvar a screenshot: $e");
      return null;
    }
  }

  ScreenshotController get screenshotController => _screenshotController;

}