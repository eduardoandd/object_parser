import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechRecognitionService {
  late stt.SpeechToText _speech;
  bool isListening = false;
  String recognizedText = '';
  
  SpeechRecognitionService() {
    _speech = stt.SpeechToText();
  }

  Future<bool> initialize() async {
    return await _speech.initialize();
  }

  void startListening(Function(String text) onResult, Function onStop) async {
    if (isListening) return;

    bool available = await _speech.initialize();
    if (!available) {
      print("Falha ao inicializar o reconhecimento de fala.");
      return;
    }

    isListening = true;
    recognizedText = ''; 

    _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
        onResult(recognizedText);
      },
    );

    _speech.statusListener = (status) {
      if (status == 'notListening') {
        isListening = false;
        onStop();
      }
    };
  }

  void stopListening() {
    if (isListening) {
      _speech.stop();
      isListening = false;
    }
  }

  String getText() {
    return recognizedText;
  }
}