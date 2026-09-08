import 'package:flutter/material.dart';
import '../core/constants/theme.dart';
import '../core/services/voice_commander.dart';

class AccessibleButton extends StatelessWidget {
  final String label;
  final String? semanticHint;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isDestructive;

  const AccessibleButton({
    super.key,
    required this.label,
    this.semanticHint,
    this.onPressed,
    this.icon,
    this.isPrimary = true,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final bgColor = !isEnabled
        ? Colors.grey.shade900
        : (isDestructive
            ? AccessibleTheme.errorRed
            : (isPrimary ? AccessibleTheme.primaryGold : AccessibleTheme.surfaceElevated));
    final fgColor = !isEnabled
        ? Colors.white38
        : (isDestructive ? Colors.white : (isPrimary ? Colors.black : Colors.white));
    final borderColor = !isEnabled
        ? Colors.white24
        : (isDestructive
            ? Colors.white
            : (isPrimary ? Colors.white : AccessibleTheme.primaryGold));

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: label,
      hint: semanticHint,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 100),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 2.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fgColor, size: 24),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TagBadge extends StatelessWidget {
  final String tag;

  const TagBadge({super.key, required this.tag});

  Color get _color {
    switch (tag.toLowerCase()) {
      case 'definition':
        return AccessibleTheme.tagDefinition;
      case 'example':
        return AccessibleTheme.tagExample;
      case 'important':
        return AccessibleTheme.tagImportant;
      default:
        return AccessibleTheme.tagGeneral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Tag: $tag",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color, width: 2),
        ),
        child: Text(
          tag.toUpperCase(),
          style: TextStyle(
            color: _color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class VoiceWaveformIndicator extends StatelessWidget {
  final VoiceState state;
  final VoidCallback? onMicTap;

  const VoiceWaveformIndicator({
    super.key,
    required this.state,
    this.onMicTap,
  });

  String get _stateDescription {
    switch (state) {
      case VoiceState.listening:
        return "Listening... Speak your command or note.";
      case VoiceState.speaking:
        return "Speaking. Say Stop to interrupt.";
      case VoiceState.processing:
        return "Processing voice input...";
      case VoiceState.idle:
        return "Voice-First Ready. Say a command.";
    }
  }

  Color get _indicatorColor {
    switch (state) {
      case VoiceState.listening:
        return AccessibleTheme.successGreen;
      case VoiceState.speaking:
        return AccessibleTheme.accentBlue;
      case VoiceState.processing:
        return AccessibleTheme.primaryGold;
      case VoiceState.idle:
        return AccessibleTheme.primaryGold;
    }
  }

  IconData get _icon {
    switch (state) {
      case VoiceState.listening:
        return Icons.mic;
      case VoiceState.speaking:
        return Icons.volume_up;
      case VoiceState.processing:
        return Icons.hourglass_top;
      case VoiceState.idle:
        return Icons.mic_none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: "Voice status: $_stateDescription",
      child: Column(
        children: [
          GestureDetector(
            onTap: onMicTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _indicatorColor.withOpacity(0.2),
                border: Border.all(color: _indicatorColor, width: 4),
                boxShadow: state == VoiceState.listening
                    ? [
                        BoxShadow(
                          color: _indicatorColor.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 4,
                        )
                      ]
                    : [],
              ),
              child: Icon(_icon, color: _indicatorColor, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AccessibleTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _indicatorColor, width: 1.5),
            ),
            child: Text(
              _stateDescription,
              style: TextStyle(
                color: _indicatorColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveRegionAnnouncer extends StatelessWidget {
  final String message;

  const LiveRegionAnnouncer({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: const SizedBox.shrink(),
    );
  }
}
