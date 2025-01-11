import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;



void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  final FlutterSoundRecorder recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer player = FlutterSoundPlayer();
  bool isRecording = false;
  String recordedFilePath = '';
  bool isPlaying = false;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    initRecorder();
    initPlayer();
  }

  Future<void> initRecorder() async {
    var status = await Permission.microphone.request();
    if(status != PermissionStatus.granted){
      throw RecordingPermissionException('Permissão para usar o microfone negada');
    }
    await recorder.openRecorder();
  }

  Future<void> initPlayer() async {
    await player.openPlayer();
  }

  Future<String> getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/audio_recording.aac';
  }


  Future<void> startRecording() async {
    final path = await getFilePath();
    final wavPath = path.replaceAll('.aac', '.wav'); // Substitua a extensão por .wav
    await recorder.startRecorder(toFile: wavPath, codec: Codec.pcm16WAV);
    setState(() {
      isRecording = true;
      recordedFilePath = wavPath;
    });
  }

  Future<void> stopRecording() async {
    await recorder.stopRecorder();
    setState(() {
      isRecording = false;
    });
  }

  Future<void> playAudio() async {
    if(recordedFilePath.isNotEmpty){
      await player.startPlayer(
        fromURI: recordedFilePath,
        whenFinished: (){
          setState(() {
            isPlaying = false;
          });
        }
      );
      setState(() {
        isPlaying = true;
      });

    }
  }

  Future<void> stopAudio() async {
    await player.stopPlayer();
    setState(() {
      isPlaying = false;
    });
  }

  Future<void> uploadAudioAndImage() async{
    if(recordedFilePath.isEmpty || _image == null){
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
        ..files.add(await http.MultipartFile.fromPath('image',_image!.path))
        ..files.add(await http.MultipartFile.fromPath('audio', recordedFilePath));

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

  Future<void> downloadAudio(String audioUrl) async {
    try {
      final response = await http.get(Uri.parse(audioUrl));
      if(response.statusCode ==200){
        final directory = await getExternalStorageDirectory();
        final downloadDirectory = Directory('${directory!.path}/Download');
        if (!await downloadDirectory.exists()) {
          await downloadDirectory.create(recursive: true);
        }
        final filePath = '${downloadDirectory.path}/ai_response.mp3';

        // salvando o arquivo no dispositivo
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Áudio baixado com sucesso! Salvo em: $filePath')),
        );

      }
      else{
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao baixar o áudio: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar o áudio: $e')),
      );
    }
  }

  Future<void> requestPermissions() async {
  PermissionStatus status = await Permission.storage.request();
  if (status.isDenied || status.isPermanentlyDenied) {
    // Se negado, peça permissão manualmente
    openAppSettings();
  }
}

  @override
  void dispose() {
    recorder.closeRecorder();
    player.closePlayer();
    super.dispose();
  }

  Future<void> openCamera()async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if(image !=null){
      _image = image;
      setState(() {
        _image = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image == null
                ?  Text('Nenhuma imagem capturada.')
                : Image.file(
                    File(_image!.path),
                    height: 300,
                  ),
            const SizedBox(height: 20,),
            ElevatedButton(onPressed: openCamera, child: const Text("Abrir camera")),

            const SizedBox(height: 20,),

            Text(
             isRecording ? 'Gravando..' : 'Gravar',
             style: TextStyle(fontSize: 20), 
            ),
            const SizedBox(height: 20,),
            ElevatedButton(
              onPressed: isRecording ? stopRecording : startRecording,
              child: Text(isRecording ? 'Parar de gravação': 'Iniciar gravação'),
            ),
            const SizedBox(height: 20,),
            
            recordedFilePath.isNotEmpty && isRecording == false 
            ?
              Column(
                children: [
                  Text("Áudio gravado:"),
                  const SizedBox(height: 10,),
                  ElevatedButton(
                    onPressed: isPlaying ? stopAudio : playAudio, 
                    child: Text(isPlaying ? 'Parar reprodução': 'Reproduzir áudio')
                  ),
                  const SizedBox(height: 10,),

                  ElevatedButton(
                    onPressed: uploadAudioAndImage, 
                    child: Text('Enviar!')
                  ),
                  ElevatedButton(
  onPressed: () async {
    const audioUrl = 'http://192.168.0.220:8000/media/ai_response/ai_response.mp3'; // Substitua pela URL correta do áudio retornado pela API.
    await downloadAudio(audioUrl);
  },
  child: Text('Baixar Áudio'),
),


                ],
              )
            :
            Container()
          ],
        ),
      ),
    );
  }

  
}
