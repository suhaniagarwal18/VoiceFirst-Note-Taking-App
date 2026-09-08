import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class STTService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  bool _shouldKeepListening = false;
  bool _isRestarting = false;
  double _confidence = 1.0;
  String _lastRecognizedWords = "";

  Timer? _silenceDebounceTimer;
  Timer? _restartTimer;
  static const Duration silenceThreshold = Duration(milliseconds: 1800);

  // Separate partial and final callbacks
  Function(String text)? onPartialResult;
  Function(String text, double confidence)? onFinalResult;
  Function(String text, double confidence)? onResult; // Backwards-compatible alias
  Function(bool isListening)? onStatusChanged;
  Function(String error)? onError;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  double get confidence => _confidence;

  Future<bool> init() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint("[STTService] Status update: $status (shouldKeepListening: $_shouldKeepListening)");
          
          if (status == 'listening') {
            _isListening = true;
            _isRestarting = false;
            onStatusChanged?.call(true);
          } else if (status == 'notListening' || status == 'done') {
            _checkAndFinalizeRemainingWords();
            
            // In continuous listening mode, automatically and silently restart
            if (_shouldKeepListening) {
              _scheduleSilentRestart();
            } else {
              _isListening = false;
              onStatusChanged?.call(false);
            }
          }
        },
        onError: (errorNotification) {
          debugPrint("[STTService] Error: ${errorNotification.errorMsg} (permanent: ${errorNotification.permanent})");
          _cancelSilenceTimer();
          
          final errorMsg = errorNotification.errorMsg.toLowerCase();
          final isTransient = errorNotification.permanent == false ||
              errorMsg.contains("no_speech") ||
              errorMsg.contains("no-speech") ||
              errorMsg.contains("timeout") ||
              errorMsg.contains("aborted") ||
              errorMsg.contains("network");

          if (_shouldKeepListening && isTransient) {
            // Transient / browser timeout error: silently recover without notifying UI
            _checkAndFinalizeRemainingWords();
            _scheduleSilentRestart();
          } else if (!_shouldKeepListening) {
            _isListening = false;
            onStatusChanged?.call(false);
            onError?.call(errorNotification.errorMsg);
          } else {
            // Non-recoverable fatal error (e.g. mic permission revoked)
            _isListening = false;
            _shouldKeepListening = false;
            onStatusChanged?.call(false);
            onError?.call(errorNotification.errorMsg);
          }
        },
      );
      return _isAvailable;
    } catch (e) {
      debugPrint("[STTService] Init error: $e");
      _isAvailable = false;
      return false;
    }
  }

  void _scheduleSilentRestart() {
    if (!_shouldKeepListening || _isRestarting) return;
    _isRestarting = true;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 120), () async {
      if (_shouldKeepListening) {
        _isRestarting = false;
        await _startListeningInternal();
      }
    });
  }

  Future<void> startListening() async {
    _shouldKeepListening = true;
    _isRestarting = false;
    _restartTimer?.cancel();

    if (!_isAvailable) {
      final initialized = await init();
      if (!initialized) {
        debugPrint("[STTService] Speech recognition not available on this device.");
        return;
      }
    }

    await _startListeningInternal();
  }

  Future<void> _startListeningInternal() async {
    if (!_isAvailable) return;

    try {
      _lastRecognizedWords = "";
      _cancelSilenceTimer();

      await _speech.listen(
        onResult: (result) {
          _confidence = result.confidence > 0 ? result.confidence : 1.0;
          final words = result.recognizedWords.trim();

          if (words.isEmpty) return;
          _lastRecognizedWords = words;

          // Emit partial result for live UI updates
          onPartialResult?.call(words);

          // If final result emitted by speech engine, dispatch immediately
          if (result.finalResult) {
            _cancelSilenceTimer();
            _dispatchFinal(words, _confidence);
          } else {
            // Otherwise, reset silence debounce timer (1.8s of silence finalizes utterance)
            _resetSilenceDebounceTimer();
          }
        },
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );

      _isListening = true;
      onStatusChanged?.call(true);
    } catch (e) {
      debugPrint("[STTService] Listen error: $e");
      if (_shouldKeepListening) {
        _scheduleSilentRestart();
      } else {
        _isListening = false;
        onStatusChanged?.call(false);
        onError?.call(e.toString());
      }
    }
  }

  void _resetSilenceDebounceTimer() {
    _cancelSilenceTimer();
    _silenceDebounceTimer = Timer(silenceThreshold, () {
      if (_lastRecognizedWords.isNotEmpty) {
        final wordsToFinalize = _lastRecognizedWords;
        _lastRecognizedWords = "";
        _dispatchFinal(wordsToFinalize, _confidence);
      }
    });
  }

  void _cancelSilenceTimer() {
    _silenceDebounceTimer?.cancel();
    _silenceDebounceTimer = null;
  }

  void cancelPendingSilenceTimer() {
    _cancelSilenceTimer();
  }

  void _checkAndFinalizeRemainingWords() {
    if (_lastRecognizedWords.isNotEmpty) {
      final wordsToFinalize = _lastRecognizedWords;
      _lastRecognizedWords = "";
      _cancelSilenceTimer();
      _dispatchFinal(wordsToFinalize, _confidence);
    }
  }

  void _dispatchFinal(String text, double confidence) {
    if (text.trim().isEmpty) return;
    onFinalResult?.call(text, confidence);
    onResult?.call(text, confidence);
  }

  Future<void> stopListening() async {
    _shouldKeepListening = false;
    _isRestarting = false;
    _restartTimer?.cancel();
    _cancelSilenceTimer();
    _lastRecognizedWords = "";
    
    if (!_isListening) return;
    try {
      await _speech.stop();
      _isListening = false;
      onStatusChanged?.call(false);
    } catch (e) {
      debugPrint("[STTService] Stop error: $e");
    }
  }

  // Simulated voice input for testing, desktop execution, or screen-reader keyboard fallback
  void simulateSpeechInput(String text, {double confidence = 1.0}) {
    _confidence = confidence;
    _lastRecognizedWords = text;
    onPartialResult?.call(text);
    _dispatchFinal(text, confidence);
  }
}
