import 'package:permission_handler/permission_handler.dart';

class AudioPermissionService {
  // Verifica e solicita permissão para usar o microfone

  Future<bool> checkAndRequestPermission() async{
    var status = await Permission.microphone.status;

    if(!status.isGranted){
      status = await Permission.microphone.request();
    }

    return status.isGranted;
  }
}