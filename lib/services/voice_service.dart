import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';

class VoiceService {
  late PorcupineManager _porcupineManager;
  String keywordPath = "assets/teste_pt_android_v3_0_0.ppn";
  String contextPath = "assets/Magic-Camera_pt_android_v3_0_0.rhn";
  String porcupineModelPath = "assets/porcupine_params_pt.pv";
  String rhinoModelPath = "assets/rhino_params_pt.pv";
  final String accessKey =
      'A2hg2EegEJdd3N8RvgHnD36v+7jUwnbyMZrfM4f3TQfh+mAdFD2YJQ==';

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex >= 0) {
      print("palavra reconhecida!");
      _porcupineManager.stop();
      // startListening();
    }
  }

  void initialize() async {
    try {
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
          accessKey, [keywordPath], _wakeWordCallback,
          modelPath: porcupineModelPath);

      await _porcupineManager.start();
    } on PorcupineException catch (err) {
      print(err.message);
    }
  }
}