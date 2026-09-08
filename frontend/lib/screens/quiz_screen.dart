import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/theme.dart';
import '../core/services/voice_commander.dart';
import '../providers/notes_provider.dart';
import '../widgets/accessible_widgets.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final voiceCommander = context.watch<VoiceCommander>();

    final quizItems = notesProvider.quizItems;
    final currentIndex = notesProvider.quizIndex;
    final currentQ = notesProvider.currentQuizItem;
    final score = notesProvider.quizScore;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Quiz & Exam Mode",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AccessibleTheme.primaryGold),
        ),
        backgroundColor: AccessibleTheme.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quiz progress header
            Container(
              padding: const EdgeInsets.all(16),
              color: AccessibleTheme.surfaceElevated,
              child: Row(
                children: [
                  const Icon(Icons.quiz, color: AccessibleTheme.primaryGold, size: 36),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentQ != null ? "SUBJECT: ${currentQ.subject.toUpperCase()}" : "QUIZ MODE",
                          style: const TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          quizItems.isEmpty
                              ? "No active quiz session."
                              : "Question ${currentIndex + 1} of ${quizItems.length} • Score: ${score.toInt()}/${quizItems.length}",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Question & Options Container
            Expanded(
              child: currentQ == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.psychology, size: 64, color: AccessibleTheme.primaryGold),
                            const SizedBox(height: 16),
                            const Text(
                              "No active quiz questions.",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Say \"Quiz me on Biology\" or \"Test me on my notes\" to generate questions.",
                              style: TextStyle(fontSize: 16, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            container: true,
                            label: "Question ${currentIndex + 1} of ${quizItems.length}. ${currentQ.question}.",
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AccessibleTheme.primaryGold, width: 2.5),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TagBadge(tag: currentQ.tag),
                                        Text(
                                          "Question ${currentIndex + 1} / ${quizItems.length}",
                                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      "QUESTION:",
                                      style: TextStyle(color: AccessibleTheme.accentBlue, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      currentQ.question,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Multiple Choice Options (if present)
                          if (currentQ.options.isNotEmpty) ...[
                            Semantics(
                              header: true,
                              child: const Text(
                                "CHOOSE AN OPTION (TAP OR SAY OPTION LETTER):",
                                style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(currentQ.options.length, (optIdx) {
                              final optionText = currentQ.options[optIdx];
                              final optionLetter = ["A", "B", "C", "D"][optIdx % 4];
                              final isSelected = currentQ.selectedOption == optionLetter;
                              final isCorrect = currentQ.correctAnswer == optionLetter;
                              final hasAnswered = currentQ.selectedOption != null;

                              Color bgColor = AccessibleTheme.surfaceElevated;
                              Color borderColor = Colors.white24;
                              IconData? statusIcon;

                              if (hasAnswered) {
                                if (isCorrect) {
                                  bgColor = Colors.green.shade900.withOpacity(0.4);
                                  borderColor = Colors.greenAccent;
                                  statusIcon = Icons.check_circle;
                                } else if (isSelected) {
                                  bgColor = Colors.red.shade900.withOpacity(0.4);
                                  borderColor = Colors.redAccent;
                                  statusIcon = Icons.cancel;
                                }
                              }

                              return Semantics(
                                button: true,
                                label: "Option $optionLetter: $optionText. ${isSelected ? (isCorrect ? 'Correct' : 'Incorrect') : ''}",
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: hasAnswered
                                        ? null
                                        : () {
                                            notesProvider.selectQuizOption(optionLetter);
                                            voiceCommander.processUtterance("Option $optionLetter");
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isSelected ? borderColor : Colors.white30, width: isSelected ? 2.5 : 1.5),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: isSelected ? borderColor : AccessibleTheme.surface,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white70),
                                            ),
                                            child: Text(
                                              optionLetter,
                                              style: TextStyle(
                                                color: isSelected ? Colors.black : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              optionText,
                                              style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.3),
                                            ),
                                          ),
                                          if (statusIcon != null) ...[
                                            const SizedBox(width: 8),
                                            Icon(statusIcon, color: borderColor, size: 28),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ] else ...[
                            // Open Spoken QA Display
                            Semantics(
                              container: true,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "EXPECTED ANSWER (FROM NOTE):",
                                        style: TextStyle(color: AccessibleTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        currentQ.expectedAnswer,
                                        style: const TextStyle(fontSize: 17, color: Colors.white70, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),

            // Navigation Controls
            if (currentQ != null)
              Container(
                padding: const EdgeInsets.all(16),
                color: AccessibleTheme.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AccessibleButton(
                      label: "Previous",
                      icon: Icons.arrow_back,
                      isPrimary: false,
                      onPressed: currentIndex > 0 ? () => notesProvider.previousQuizQuestion() : null,
                    ),
                    AccessibleButton(
                      label: "Next",
                      icon: Icons.arrow_forward,
                      onPressed: currentIndex + 1 < quizItems.length
                          ? () => notesProvider.nextQuizQuestion()
                          : () => Navigator.pushNamed(context, '/home'),
                    ),
                    AccessibleButton(
                      label: "End Quiz",
                      icon: Icons.stop,
                      isDestructive: true,
                      onPressed: () => Navigator.pushNamed(context, '/home'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
