import re
import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple
from database import get_db_connection
from services.note_service import NoteService

class FlashcardService:
    @staticmethod
    def _extract_qa_from_note(note: Dict[str, Any]) -> Tuple[str, str]:
        """
        Extracts high quality Q&A from note content without hallucinating.
        """
        text = note["text"].strip()
        tag = note.get("tag", "General")
        subject = note.get("subject", "General")

        # Pattern 1: "[Term] is defined as [Definition]" or "[Term] is the process of [Definition]"
        match = re.match(r"^(.+?)\s+(?:is defined as|is the process of|refers to|is a term for|is when)\s+(.+)$", text, re.IGNORECASE)
        if match:
            term = match.group(1).strip()
            rest = match.group(2).strip()
            return f"What is {term}?", f"{term} is {rest}"

        # Pattern 2: "For example, [Example]"
        if tag == "Example" or "for example" in text.lower():
            return f"What is an example mentioned in {subject}?", text

        # Pattern 3: Important concept
        if tag == "Important":
            words = text.split()
            preview = " ".join(words[:4])
            return f"What is the important concept regarding {preview}?", text

        # Default definition style if starts with noun phrase
        return f"Regarding {subject}: {text.split('.')[0]}?", text

    @classmethod
    def generate_flashcards_from_notes(cls, user_id: str, subject: Optional[str] = None, 
                                       tag: Optional[str] = None, timeframe: Optional[str] = None) -> List[Dict[str, Any]]:
        notes = NoteService.get_notes_by_filter(user_id, subject=subject, tag=tag, timeframe=timeframe)
        if not notes:
            return []

        conn = get_db_connection()
        cursor = conn.cursor()
        created_cards = []

        for note in notes:
            # Check if card already exists for this note
            cursor.execute("SELECT * FROM flashcards WHERE source_note_id = ?", (note["note_id"],))
            existing = cursor.fetchone()
            if existing:
                created_cards.append(dict(existing))
                continue

            question, answer = cls._extract_qa_from_note(note)
            card_id = str(uuid.uuid4())
            cursor.execute("""
                INSERT INTO flashcards (id, source_note_id, user_id, subject, tag, question, answer, difficulty, review_count, correct_count)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'Medium', 0, 0)
            """, (card_id, note["note_id"], user_id, note["subject"], note["tag"], question, answer))
            
            created_cards.append({
                "id": card_id,
                "source_note_id": note["note_id"],
                "user_id": user_id,
                "subject": note["subject"],
                "tag": note["tag"],
                "question": question,
                "answer": answer,
                "difficulty": "Medium",
                "review_count": 0,
                "correct_count": 0
            })

        conn.commit()
        conn.close()
        return created_cards

    @classmethod
    def get_flashcards(cls, user_id: str, subject: Optional[str] = None) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        if subject and subject.lower() != "all":
            cursor.execute("""
                SELECT * FROM flashcards 
                WHERE user_id = ? AND LOWER(subject) = ?
                ORDER BY review_count ASC, id ASC
            """, (user_id, subject.lower()))
        else:
            cursor.execute("""
                SELECT * FROM flashcards 
                WHERE user_id = ?
                ORDER BY review_count ASC, id ASC
            """, (user_id,))
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]

    @classmethod
    def record_review(cls, card_id: str, is_correct: bool, difficulty: Optional[str] = None):
        conn = get_db_connection()
        cursor = conn.cursor()
        now = datetime.now().isoformat()

        if difficulty:
            cursor.execute("""
                UPDATE flashcards 
                SET review_count = review_count + 1,
                    correct_count = correct_count + ?,
                    difficulty = ?,
                    last_reviewed_at = ?
                WHERE id = ?
            """, (1 if is_correct else 0, difficulty.capitalize(), now, card_id))
        else:
            cursor.execute("""
                UPDATE flashcards 
                SET review_count = review_count + 1,
                    correct_count = correct_count + ?,
                    last_reviewed_at = ?
                WHERE id = ?
            """, (1 if is_correct else 0, now, card_id))

        conn.commit()
        conn.close()

    @classmethod
    def generate_flashcards_from_topic(cls, user_id: str, topic: Optional[str] = None, 
                                       gemini_service=None) -> Optional[Dict[str, Any]]:
        """
        Retrieves user notes by topic/subject and generates 8-10 flashcards via Gemini (with deterministic fallback).
        Returns structured dict: {"type": "flashcards", "topic": str, "cards": [...]} or None if no notes.
        """
        notes = NoteService.get_notes_by_topic_or_subject(user_id, topic)
        if not notes:
            return None

        clean_topic = topic.strip().title() if topic else (notes[0].get("subject", "General"))

        # 1. Attempt Gemini Generation
        if gemini_service and gemini_service.is_available():
            gemini_res = gemini_service.generate_flashcards(clean_topic, notes)
            if gemini_res and "cards" in gemini_res and len(gemini_res["cards"]) > 0:
                return gemini_res

        # 2. Deterministic Fallback (Generates 8-10 cards or matches note count)
        cards = []
        target_count = min(10, max(len(notes), 8))

        for i in range(target_count):
            note = notes[i % len(notes)]
            q_text, ans_text = cls._extract_qa_from_note(note)
            
            # For multiple variations on the same note if notes < 8
            if i >= len(notes):
                front = f"Concept: {note.get('subject', 'General')} Point {i + 1}"
                back = note["text"]
            else:
                front = q_text
                back = ans_text

            cards.append({
                "id": str(uuid.uuid4()),
                "source_note_id": note["note_id"],
                "subject": note.get("subject", "General"),
                "tag": note.get("tag", "General"),
                "front": front,
                "back": back,
                "question": front,
                "answer": back,
                "difficulty": "Medium"
            })

        return {
            "type": "flashcards",
            "topic": clean_topic,
            "cards": cards
        }
