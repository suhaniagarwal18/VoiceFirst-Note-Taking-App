import 'package:flutter/foundation.dart';
import 'tts_service.dart';
import 'stt_service.dart';
import 'dialogue_manager.dart';
import '../network/api_client.dart';

enum VoiceState { idle, listening, processing, speaking }

class VoiceCommander extends ChangeNotifier {
  final TTSService ttsService;
  final STTService sttService;
  final ApiClient apiClient;
  final DialogueManager dialogueManager = DialogueManager();

  VoiceState _state = VoiceState.idle;
  String _lastRecognizedText = "";
  String _lastSpokenText = "";
  bool _autoListenEnabled = true;

  Function(String action, Map<String, dynamic> data)? onActionTriggered;

  VoiceState get state => _state;
  String get lastRecognizedText => _lastRecognizedText;
  String get lastSpokenText => _lastSpokenText;
  bool get isListening => _state == VoiceState.listening;
  bool get isSpeaking => _state == VoiceState.speaking;
  bool get isProcessing => _state == VoiceState.processing;

  VoiceCommander({
    required this.ttsService,
    required this.sttService,
    required this.apiClient,
  }) {
    _initListeners();
  }

  void _initListeners() {
    // STT Partial Transcription Callback (Live UI Updates without cutting off)
    sttService.onPartialResult = (text) {
      if (text.trim().isNotEmpty) {
        _lastRecognizedText = text;
        notifyListeners();
        // If user says "Stop" at any point, interrupt immediately
        final norm = text.trim().toLowerCase();
        if (norm == "stop" || norm == "stop." || norm == "pause") {
          sttService.cancelPendingSilenceTimer();
          interruptSpeech();
        }
      }
    };

    // STT Final Sentence Callback (Dispatched only when full sentence is finished)
    sttService.onFinalResult = (text, confidence) {
      if (text.trim().isNotEmpty && _state != VoiceState.processing && _state != VoiceState.speaking) {
        _lastRecognizedText = text;
        notifyListeners();
        final norm = text.trim().toLowerCase();
        if (norm == "stop" || norm == "stop." || norm == "pause") {
          interruptSpeech();
          return;
        }
        processUtterance(text, confidence: confidence);
      }
    };

    sttService.onStatusChanged = (isListening) {
      if (isListening && _state != VoiceState.speaking && _state != VoiceState.processing) {
        _state = VoiceState.listening;
        notifyListeners();
      } else if (!isListening && _state == VoiceState.listening) {
        _state = VoiceState.idle;
        notifyListeners();
      }
    };

    // TTS Callbacks
    ttsService.onSpeechStart = () {
      _state = VoiceState.speaking;
      sttService.stopListening();
      notifyListeners();
    };

    ttsService.onSpeechComplete = () {
      _state = VoiceState.idle;
      notifyListeners();
      // Auto resume listening for hands-free loop if enabled
      if (_autoListenEnabled) {
        Future.delayed(const Duration(milliseconds: 400), () {
          startListening();
        });
      }
    };
  }

  Future<void> startListening() async {
    if (_state == VoiceState.speaking) return;
    _state = VoiceState.listening;
    notifyListeners();
    await sttService.startListening();
  }

  Future<void> stopListening() async {
    await sttService.stopListening();
    _state = VoiceState.idle;
    notifyListeners();
  }

  Future<void> interruptSpeech() async {
    await ttsService.stop();
    _state = VoiceState.idle;
    notifyListeners();
    if (_autoListenEnabled) {
      startListening();
    }
  }

  Future<void> speakGreeting(String text) async {
    _lastSpokenText = text;
    notifyListeners();
    await ttsService.speak(text);
  }

  Future<void> processUtterance(String text, {double confidence = 1.0}) async {
    _lastRecognizedText = text;

    final contextMap = dialogueManager.toContextMap();
    final result = await apiClient.processVoice(
      text: text,
      context: contextMap,
      confidence: confidence,
    );

    final spokenResponse = result['spoken_response'] ?? "";
    final action = result['action'] ?? "none";
    final data = result['data'] ?? <String, dynamic>{};
    final nextContext = result['context'] ?? <String, dynamic>{};

    dialogueManager.updateFromBackend(nextContext);

    // Trigger action callbacks for UI screen navigation / state updates
    onActionTriggered?.call(action, Map<String, dynamic>.from(data));

    // If spokenResponse is empty (silent note capture during active lecture), do NOT speak or stop mic
    if (spokenResponse.trim().isEmpty) {
      _lastSpokenText = "";
      _state = VoiceState.listening;
      notifyListeners();
      if (!sttService.isListening) {
        await sttService.startListening();
      }
    } else {
      // Explicit command produced spoken output: stop STT temporarily to prevent TTS feedback loop
      await sttService.stopListening();
      _lastSpokenText = spokenResponse;
      _state = VoiceState.speaking;
      notifyListeners();

      // Speak response
      await ttsService.speak(spokenResponse);
    }
  }

  void setAutoListen(bool enabled) {
    _autoListenEnabled = enabled;
  }
}
