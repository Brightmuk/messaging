import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playSent() async {
    try {
      await _player.play(AssetSource('audio/sent.mp3'));
    } catch (_) {}
  }

  Future<void> playReceived() async {
    try {
      await _player.play(AssetSource('audio/received.mp3'));
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}