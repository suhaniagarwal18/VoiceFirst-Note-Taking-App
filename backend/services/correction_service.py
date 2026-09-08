import re
from datetime import datetime
from typing import Dict, Any, Optional, Tuple
from database import get_db_connection
from services.note_service import NoteService

class CorrectionService:
    @classmethod
    def correct_word_replacement(cls, user_id: str, target: str, replacement: str, 
                                 note_id: Optional[str] = None) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
        """
        Corrects a note by replacing 'target' with 'replacement'.
        If note_id is not given, applies to the user's most recent note.
        Returns: (success, spoken_response, updated_note_dict)
        """
        conn = get_db_connection()
        cursor = conn.cursor()

        if not note_id:
            last_note = NoteService.get_last_note(user_id)
            if not last_note:
                conn.close()
                return False, "You don't have any notes to correct yet.", None
            note_id = last_note["note_id"]
        
        cursor.execute("SELECT * FROM notes WHERE note_id = ? AND is_deleted = 0", (note_id,))
        row = cursor.fetchone()
        if not row:
            conn.close()
            return False, "I couldn't find that note to correct.", None

        current_note = dict(row)
        original_text = current_note["text"]

        # Case-insensitive replacement
        pattern = re.compile(re.escape(target), re.IGNORECASE)
        if not pattern.search(original_text):
            conn.close()
            return False, f"I couldn't find {target} in your last note. Your last note says: {original_text}", current_note

        corrected_text = pattern.sub(replacement, original_text)
        now_iso = datetime.now().isoformat()

        # Update note
        cursor.execute("""
            UPDATE notes 
            SET text = ?, updated_at = ?
            WHERE note_id = ?
        """, (corrected_text, now_iso, note_id))

        # Log correction history
        cursor.execute("""
            INSERT INTO correction_history (note_id, original_text, corrected_text, correction_timestamp, change_reason)
            VALUES (?, ?, ?, ?, ?)
        """, (note_id, original_text, corrected_text, now_iso, f"Replaced '{target}' with '{replacement}'"))

        conn.commit()
        
        # Fetch updated note
        cursor.execute("SELECT * FROM notes WHERE note_id = ?", (note_id,))
        updated_note = dict(cursor.fetchone())
        conn.close()

        spoken_msg = f"Corrected. The note now says: {corrected_text}"
        return True, spoken_msg, updated_note

    @classmethod
    def correct_full_text(cls, user_id: str, new_text: str, 
                          note_id: Optional[str] = None) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
        """
        Replaces the entire note text.
        """
        conn = get_db_connection()
        cursor = conn.cursor()

        if not note_id:
            last_note = NoteService.get_last_note(user_id)
            if not last_note:
                conn.close()
                return False, "You don't have any notes to correct yet.", None
            note_id = last_note["note_id"]
            original_text = last_note["text"]
        else:
            cursor.execute("SELECT * FROM notes WHERE note_id = ?", (note_id,))
            row = cursor.fetchone()
            if not row:
                conn.close()
                return False, "I couldn't find that note to correct.", None
            original_text = dict(row)["text"]

        now_iso = datetime.now().isoformat()

        cursor.execute("""
            UPDATE notes 
            SET text = ?, updated_at = ?
            WHERE note_id = ?
        """, (new_text, now_iso, note_id))

        cursor.execute("""
            INSERT INTO correction_history (note_id, original_text, corrected_text, correction_timestamp, change_reason)
            VALUES (?, ?, ?, ?, ?)
        """, (note_id, original_text, new_text, now_iso, "Full note replacement"))

        conn.commit()
        
        cursor.execute("SELECT * FROM notes WHERE note_id = ?", (note_id,))
        updated_note = dict(cursor.fetchone())
        conn.close()

        spoken_msg = f"Corrected. The note now says: {new_text}"
        return True, spoken_msg, updated_note

    @classmethod
    def get_correction_history(cls, note_id: str) -> list:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM correction_history 
            WHERE note_id = ? 
            ORDER BY correction_timestamp DESC
        """, (note_id,))
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]
