import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional
from database import get_db_connection
from services.note_service import NoteService

class BookmarkService:
    @classmethod
    def add_bookmark(cls, user_id: str, note_id: Optional[str] = None, label: Optional[str] = None) -> Dict[str, Any]:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if not note_id:
            last_note = NoteService.get_last_note(user_id)
            if not last_note:
                conn.close()
                return {"success": False, "message": "You don't have any notes to bookmark yet."}
            note_id = last_note["note_id"]
            note_text = last_note["text"]
            subject = last_note["subject"]
        else:
            cursor.execute("SELECT * FROM notes WHERE note_id = ?", (note_id,))
            row = cursor.fetchone()
            if not row:
                conn.close()
                return {"success": False, "message": "Note not found."}
            note_text = dict(row)["text"]
            subject = dict(row)["subject"]

        # Check if already bookmarked
        cursor.execute("SELECT * FROM bookmarks WHERE note_id = ? AND user_id = ?", (note_id, user_id))
        existing = cursor.fetchone()
        if existing:
            conn.close()
            return {"success": True, "message": f"This note is already bookmarked: {note_text}", "bookmark": dict(existing)}

        bm_id = str(uuid.uuid4())
        now = datetime.now().isoformat()
        cursor.execute("""
            INSERT INTO bookmarks (id, note_id, user_id, label, created_at)
            VALUES (?, ?, ?, ?, ?)
        """, (bm_id, note_id, user_id, label or "Exam Bookmark", now))

        conn.commit()
        conn.close()
        
        return {
            "success": True,
            "message": f"Bookmarked {subject} note: {note_text}",
            "bookmark": {
                "id": bm_id,
                "note_id": note_id,
                "user_id": user_id,
                "label": label or "Exam Bookmark",
                "text": note_text,
                "subject": subject,
                "created_at": now
            }
        }

    @classmethod
    def get_bookmarks(cls, user_id: str) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT b.id, b.note_id, b.label, b.created_at as bookmarked_at,
                   n.subject, n.text, n.tag, n.timestamp
            FROM bookmarks b
            JOIN notes n ON b.note_id = n.note_id
            WHERE b.user_id = ? AND n.is_deleted = 0
            ORDER BY b.created_at DESC
        """, (user_id,))
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]
