import uuid
import re
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple
from database import get_db_connection
from services.note_service import NoteService
from services.flashcard_service import FlashcardService

class QuizService:
    @classmethod
    def generate_quiz(cls, user_id: str, filter_text: Optional[str] = None, 
                      timeframe: Optional[str] = None, weak_topics_only: bool = False) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()

        if weak_topics_only:
            cursor.execute("""
                SELECT topic, subject FROM weak_topics 
                WHERE user_id = ? AND is_resolved = 0 
                ORDER BY error_count DESC, last_error_at DESC
            """, (user_id,))
            weaks = cursor.fetchall()
            if weaks:
                weak_notes = []
                for w in weaks:
                    cursor.execute("""
                        SELECT * FROM notes 
                        WHERE user_id = ? AND is_deleted = 0 AND (text LIKE ? OR subject LIKE ?)
                        LIMIT 2
                    """, (user_id, f"%{w['topic']}%", f"%{w['subject']}%"))
                    weak_notes.extend([dict(r) for r in cursor.fetchall()])
                if weak_notes:
                    notes = weak_notes
                else:
                    notes = NoteService.get_notes_by_filter(user_id, timeframe=timeframe)
            else:
                notes = NoteService.get_notes_by_filter(user_id, timeframe=timeframe)
        else:
            # Parse filter_text for tag or subject
            subject = None
            tag = None
            if filter_text:
                fl = filter_text.lower()
                if "important" in fl:
                    tag = "Important"
                elif "definition" in fl:
                    tag = "Definition"
                elif "example" in fl:
                    tag = "Example"
                else:
                    subject = filter_text

            notes = NoteService.get_notes_by_filter(user_id, subject=subject, tag=tag, timeframe=timeframe)

        conn.close()

        if not notes:
            return []

        quiz_questions = []
        for idx, note in enumerate(notes[:10]): # Cap at 10 questions per quiz session
            question, answer = FlashcardService._extract_qa_from_note(note)
            quiz_questions.append({
                "question_id": str(uuid.uuid4()),
                "source_note_id": note["note_id"],
                "subject": note["subject"],
                "tag": note["tag"],
                "question": question,
                "expected_answer": answer,
                "original_note": note["text"]
            })

        return quiz_questions

    @classmethod
    def generate_mcq_quiz_from_topic(cls, user_id: str, topic: Optional[str] = None, 
                                     gemini_service=None) -> Optional[Dict[str, Any]]:
        """
        Retrieves user notes by topic/subject and generates 5 MCQs via Gemini (with deterministic fallback).
        Returns structured dict: {"type": "quiz", "topic": str, "questions": [...]} or None if no notes.
        """
        notes = NoteService.get_notes_by_topic_or_subject(user_id, topic)
        if not notes:
            return None

        clean_topic = topic.strip().title() if topic else (notes[0].get("subject", "General"))

        # 1. Attempt Gemini Generation
        if gemini_service and gemini_service.is_available():
            gemini_res = gemini_service.generate_mcq_quiz(clean_topic, notes)
            if gemini_res and "questions" in gemini_res and len(gemini_res["questions"]) > 0:
                return gemini_res

        # 2. Deterministic Fallback (Generates 5 questions based on available notes)
        questions = []
        target_count = 5
        
        # Build answer pool for distractor generation
        answers_pool = []
        for n in notes:
            _, ans = FlashcardService._extract_qa_from_note(n)
            answers_pool.append(ans)

        for i in range(target_count):
            note = notes[i % len(notes)]
            q_text, correct_ans = FlashcardService._extract_qa_from_note(note)
            
            # Distractors
            distractors = [a for a in answers_pool if a != correct_ans]
            if len(distractors) < 3:
                distractors.extend([
                    f"Alternative mechanism in {note.get('subject', 'General')}",
                    f"Opposite biological process",
                    f"Standard general condition"
                ])
            distractors = distractors[:3]

            # Place correct answer in option B or A/C/D
            correct_letter = ["A", "B", "C", "D"][i % 4]
            options = []
            d_idx = 0
            for letter in ["A", "B", "C", "D"]:
                if letter == correct_letter:
                    options.append(f"{letter}: {correct_ans}")
                else:
                    options.append(f"{letter}: {distractors[d_idx % len(distractors)]}")
                    d_idx += 1

            questions.append({
                "question_id": str(uuid.uuid4()),
                "source_note_id": note["note_id"],
                "subject": note.get("subject", "General"),
                "question": q_text,
                "options": options,
                "correct_answer": correct_letter,
                "explanation": correct_ans
            })

        return {
            "type": "quiz",
            "topic": clean_topic,
            "questions": questions
        }

    @classmethod
    def evaluate_spoken_answer(cls, question_dict: Dict[str, Any], user_spoken_answer: str, 
                               gemini_service=None) -> Dict[str, Any]:
        """
        Evaluates the user's spoken answer against expected answer/note content.
        Returns: {
            "result": "Correct" | "Partially correct" | "Incorrect",
            "score": float,
            "feedback": str,
            "spoken_feedback": str
        }
        """
        expected = question_dict.get("expected_answer") or question_dict.get("original_note", "")
        clean_user = user_spoken_answer.strip().lower()
        clean_expected = expected.strip().lower()

        # Check for skip or "I don't know"
        if any(w in clean_user for w in ["i don't know", "i dont know", "dont know", "pass", "skip", "no idea"]):
            return {
                "result": "Incorrect",
                "score": 0.0,
                "feedback": f"The answer is: {expected}",
                "spoken_feedback": f"No problem. The answer is: {expected}"
            }

        # If Gemini is available, use Gemini for semantic reasoning
        if gemini_service and gemini_service.is_available():
            gemini_eval = gemini_service.evaluate_quiz_answer(
                question=question_dict["question"],
                expected_answer=expected,
                user_answer=user_spoken_answer
            )
            if gemini_eval:
                return gemini_eval

        # Fallback Deterministic Evaluation based on token overlap & key concepts
        user_words = set(re.findall(r"\w+", clean_user))
        expected_words = set(re.findall(r"\w+", clean_expected))
        # Filter stopwords
        stopwords = {"the", "a", "an", "is", "are", "was", "were", "in", "on", "at", "to", "for", "of", "and", "or", "it", "that", "this", "by", "with"}
        key_expected = expected_words - stopwords
        if not key_expected:
            key_expected = expected_words

        matched = user_words.intersection(key_expected)
        overlap_ratio = len(matched) / max(len(key_expected), 1)

        if overlap_ratio >= 0.5 or (len(matched) >= 3 and overlap_ratio >= 0.35):
            result = "Correct"
            score = 1.0
            spoken = f"Correct. {expected}"
        elif overlap_ratio >= 0.2 or len(matched) >= 1:
            result = "Partially correct"
            score = 0.5
            spoken = f"Partially correct. Note that: {expected}"
        else:
            result = "Incorrect"
            score = 0.0
            spoken = f"Incorrect. The note states: {expected}"

        return {
            "result": result,
            "score": score,
            "feedback": expected,
            "spoken_feedback": spoken
        }

    @classmethod
    def record_quiz_answer(cls, user_id: str, question_dict: Dict[str, Any], 
                           user_answer: str, eval_result: Dict[str, Any], session_id: Optional[str] = None):
        conn = get_db_connection()
        cursor = conn.cursor()
        
        hist_id = str(uuid.uuid4())
        now = datetime.now().isoformat()
        is_weak = 1 if eval_result["result"] in ["Incorrect", "Partially correct"] else 0

        cursor.execute("""
            INSERT INTO quiz_history (id, user_id, session_id, subject, question, user_spoken_answer, evaluation_result, feedback, score, timestamp, weakness_flag)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (hist_id, user_id, session_id, question_dict.get("subject", "General"), 
              question_dict["question"], user_answer, eval_result["result"], 
              eval_result["feedback"], eval_result["score"], now, is_weak))

        # Track in weak topics if incorrect
        if is_weak:
            topic = question_dict.get("subject", "General")
            # Extract key concept from question if possible
            match = re.search(r"What is (.+?)\?", question_dict["question"])
            if match:
                topic = match.group(1).strip()

            cursor.execute("""
                SELECT * FROM weak_topics WHERE user_id = ? AND LOWER(topic) = ?
            """, (user_id, topic.lower()))
            existing_weak = cursor.fetchone()
            if existing_weak:
                cursor.execute("""
                    UPDATE weak_topics 
                    SET error_count = error_count + 1, last_error_at = ?, is_resolved = 0
                    WHERE id = ?
                """, (now, existing_weak["id"]))
            else:
                weak_id = str(uuid.uuid4())
                cursor.execute("""
                    INSERT INTO weak_topics (id, user_id, topic, subject, error_count, last_error_at, is_resolved)
                    VALUES (?, ?, ?, ?, 1, ?, 0)
                """, (weak_id, user_id, topic, question_dict.get("subject", "General"), now))

        conn.commit()
        conn.close()

    @classmethod
    def get_weak_topics(cls, user_id: str) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM weak_topics 
            WHERE user_id = ? AND is_resolved = 0 
            ORDER BY error_count DESC, last_error_at DESC
        """, (user_id,))
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]
