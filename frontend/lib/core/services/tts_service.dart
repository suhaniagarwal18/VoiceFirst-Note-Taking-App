import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TTSState { playing, stopped, paused, error }

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  TTSState _state = TTSState.stopped;
  double _speechRate = 0.5; // Default normal speech rate
  double _pitch = 1.0;
  double _volume = 1.0;

  VoidCallback? onSpeechStart;
  VoidCallback? onSpeechComplete;
  VoidCallback? onSpeechError;

  bool get isSpeaking => _state == TTSState.playing;

  Future<void> init() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);

      _flutterTts.setStartHandler(() {
        _state = TTSState.playing;
        onSpeechStart?.call();
      });

      _flutterTts.setCompletionHandler(() {
        _state = TTSState.stopped;
        onSpeechComplete?.call();
      });

      _flutterTts.setCancelHandler(() {
        _state = TTSState.stopped;
      });

      _flutterTts.setErrorHandler((msg) {
        _state = TTSState.error;
        onSpeechError?.call();
      });
    } catch (e) {
      debugPrint("[TTSService] Init error (mock fallback available): $e");
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _flutterTts.stop(); // Stop any previous speech
      _state = TTSState.playing;
      onSpeechStart?.call();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("[TTSService] Speak error: $e");
      _state = TTSState.stopped;
      onSpeechComplete?.call();
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _state = TTSState.stopped;
    } catch (e) {
      debugPrint("[TTSService] Stop error: $e");
    }
  }

  Future<void> setRate(double rate) async {
    _speechRate = rate;
    try {
      await _flutterTts.setSpeechRate(rate);
    } catch (e) {}
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    try {
      await _flutterTts.setPitch(pitch);
    } catch (e) {}
  }

  Future<void> setVolume(double volume) async {
    _volume = volume;
    try {
      await _flutterTts.setVolume(volume);
    } catch (e) {}
  }
}
