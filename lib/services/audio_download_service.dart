import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioDownloadService {
  String audioUrl = 'http://192.168.0.220:8000/media/ai_response/ai_response.mp3';

  Future<String> downloadAudio() async {
    try {
      final response = await http.get(Uri.parse(audioUrl));

      if(response.statusCode == 200){
        final directory = await getExternalStorageDirectory();
        final downloadDirectory = Directory('${directory!.path}/Download');
        if(!await downloadDirectory.exists()){
          await downloadDirectory.create(recursive: true);
        }

        final filePath = '${downloadDirectory.path}/ai_response.mp3';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        print('áudio baixado com sucesso! Salvo em $filePath');

       return filePath;
      }
      else{
        print('Erro: Falha ao baixar o áudio. Código ${response.statusCode}');
        return '';
      }

    } 
    catch (e) {
      print('Erro ao baixar o áudio: $e');
      return '';
    }
  }

}