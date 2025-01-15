import 'dart:io';
import 'package:http/http.dart' as http;


class UploadService {
  String uploadUrl = 'http://192.168.0.220:8000/object_img/';

  Future<void> uploadImageAndText(File imageFile, String text) async {
    if(imageFile == null || text.isEmpty){
      print('Erro: Imagem ou texto não podem estar vazios');
      return;
    }

    try {
      final uri = Uri.parse(uploadUrl);
      var request = http.MultipartRequest('POST', uri);

      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      request.fields['text'] = text;

      final response = await request.send();

      if(response.statusCode == 201){
        print("Upload realizado com sucesso");
      }
      else{
        print("Erro no upload");
      }
    } catch (e) {
      print("Erro ao enviar:");
      
    }
  }
}