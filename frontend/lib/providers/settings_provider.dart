import 'package:flutter/foundation.dart';
import '../core/constants/constants.dart';

class SettingsProvider extends ChangeNotifier {
  String _backendUrl = AppConstants.defaultBackendUrl;
  double _speechRate = 0.5;
  double _speechPitch = 1.0;
  bool _spokenConfirmation = true;
  bool _autoListen = true;

  String get backendUrl => _backendUrl;
  double get speechRate => _speechRate;
  double get speechPitch => _speechPitch;
  bool get spokenConfirmation => _spokenConfirmation;
  bool get autoListen => _autoListen;

  void updateBackendUrl(String url) {
    _backendUrl = url;
    notifyListeners();
  }

  void updateSpeechRate(double rate) {
    _speechRate = rate;
    notifyListeners();
  }

  void updateSpeechPitch(double pitch) {
    _speechPitch = pitch;
    notifyListeners();
  }

  void toggleSpokenConfirmation(bool val) {
    _spokenConfirmation = val;
    notifyListeners();
  }

  void toggleAutoListen(bool val) {
    _autoListen = val;
    notifyListeners();
  }
}
