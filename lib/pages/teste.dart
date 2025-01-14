import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class TestePage extends StatefulWidget {
  const TestePage({super.key});

  @override
  State<TestePage> createState() => _TestePageState();
}

class _TestePageState extends State<TestePage> {
  late stt.SpeechToText speech;
  bool isListening = false;
  String text = '';

  @override
  void initState() {
    speech = stt.SpeechToText();
    super.initState();
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() {
        isListening = true;
        text = ''; // Limpa o texto antes de começar
      });

      
      speech.listen(
        pauseFor: Duration(seconds: 4),
        onResult: (result) {
          setState(() {
            text = result.recognizedWords;
          });
        },
      );

      speech.statusListener = (status) {
        if (status == 'notListening') {
          print('Parando o audio....');
          
          
          setState(() {
            isListening = false;
          });
          checkVoiceCommand(text); 
        }
      };
    }
  }

  void checkVoiceCommand(String command) {
    print('Comando detectado: $command');
    // Adicione sua lógica para tratar o comando aqui
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teste"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Gravar',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isListening ? null : startListening,
              child: const Text('Começar a Ouvir'),
            ),
            const SizedBox(height: 20),
            Text(
              'Texto detectado: $text',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
