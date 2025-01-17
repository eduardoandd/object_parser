import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class AiResponsePage extends StatefulWidget {
  final String audioFilePath;
  const AiResponsePage({super.key, required this.audioFilePath});

  @override
  State<AiResponsePage> createState() => _AiResponsePageState();
}

class _AiResponsePageState extends State<AiResponsePage>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _audioPosition;

  final double _speedFactor = 0.004;

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioPlayer();

    // Controlador de animação
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
      upperBound: 2 * pi, // Um ciclo completo
    )..repeat();

    // Animação controlada
    _animation =
        Tween<double>(begin: 0.0, end: 2 * pi).animate(_controller);

    _audioPosition = 0.0;

    // Reproduzir o áudio automaticamente
    _playAudio();

    // Ouvir a posição do áudio para atualizar a animação da onda
    _audioPlayer.onPositionChanged.listen((Duration duration) {
      setState(() {
        _audioPosition = duration.inMilliseconds.toDouble();
      });
    });
  }

  Future<void> _playAudio() async {
    await _audioPlayer.play(DeviceFileSource(widget.audioFilePath));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.grey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Linha azul animada
              Center(
                child: CustomPaint(
                  size: Size(double.infinity, 100),
                  painter: WavePainter(_audioPosition, _speedFactor),
                ),
              ),
              SizedBox(height: 20,),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () async {
                      await _audioPlayer.play(DeviceFileSource(widget.audioFilePath));
                    },
                    icon: Icon(Icons.replay),
                    color: Colors.white,
                    iconSize: 50,
                  ),
                  SizedBox(width: 20),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.play_arrow),
                    color: Colors.white,
                    iconSize: 50,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

class WavePainter extends CustomPainter {
  final double audioPosition;
  final double speedFactor;

  WavePainter(this.audioPosition, this.speedFactor)
      : super(repaint: Listenable.merge([ValueNotifier(audioPosition)]));

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 0, 89, 243)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    final path = Path();

    double waveWidth = size.width;
    double amplitude = 30.0;

    // Desenhando a onda com base na animação
    for (double x = 0.0; x < waveWidth; x++) {
      // A fórmula da onda agora leva em consideração a posição do áudio e o fator de velocidade
      double y = amplitude *
          (1 + sin((audioPosition * speedFactor + x / waveWidth * 2 * pi)));
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
