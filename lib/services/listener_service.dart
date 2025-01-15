import 'package:speech_to_text/speech_to_text.dart' as stt;

class ListenerService {
  late stt.SpeechToText _speech;
  bool isListening = false;
  String recognizedText = '';

  ListenerService(){
    _speech = stt.SpeechToText();
  }

  Future<bool> initialize() async {
    bool available = await _speech.initialize();
    return available;
  }

  void startListening(void Function(String) onResult){
    isListening = true;

    _speech.listen(onResult: (result){
      recognizedText = result.recognizedWords;
      onResult(recognizedText);
    });
  }

  void stopListening(){
    isListening = false;
    _speech.stop();
  }
  bool get isListeningStatus => isListening;
  String get recognizedTextStatus => recognizedText;
  
}