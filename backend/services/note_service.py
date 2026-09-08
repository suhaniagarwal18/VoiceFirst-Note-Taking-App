import uuid
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from database import get_db_connection

class NoteService:
    @staticmethod
    def classify_tag(text: str, explicit_tag: Optional[str] = None) -> str:
        if explicit_tag:
            tag_lower = explicit_tag.lower()
            if "import" in tag_lower:
                return "Important"
            elif "def" in tag_lower:
                return "Definition"
            elif "examp" in tag_lower:
                return "Example"
            elif "gen" in tag_lower:
                return "General"

        # Heuristic Auto-Tagging
        text_lower = text.lower()
        if any(w in text_lower for w in ["is defined as", "refers to", "the process of", "is the process", "is when", "means", "is a term for"]):
            return "Definition"
        if any(w in text_lower for w in ["for example", "for instance", "e.g.", "such as", "an example of"]):
            return "Example"
        if any(w in text_lower for w in ["important", "remember", "crucial", "essential", "key point", "exam point", "must know", "critical"]):
            return "Important"
        return "General"

    @classmethod
    def start_session(cls, user_id: str, subject: str) -> Dict[str, Any]:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Deactivate any previous active session
        now = datetime.now().isoformat()
        cursor.execute("UPDATE sessions SET is_active = 0, end_time = ? WHERE user_id = ? AND is_active = 1", (now, user_id))
        
        session_id = str(uuid.uuid4())
        cursor.execute("""
            INSERT INTO sessions (session_id, user_id, subject, start_time, is_active, created_at)
            VALUES (?, ?, ?, ?, 1, ?)
        """, (session_id, user_id, subject.title(), now, now))
        
        conn.commit()
        conn.close()
        
        return {
            "session_id": session_id,
            "user_id": user_id,
            "subject": subject.title(),
            "start_time": now,
            "is_active": True
        }

    @classmethod
    def get_active_session(cls, user_id: str) -> Optional[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM sessions WHERE user_id = ? AND is_active = 1 ORDER BY start_time DESC LIMIT 1", (user_id,))
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

    @classmethod
    def end_active_session(cls, user_id: str) -> Optional[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM sessions WHERE user_id = ? AND is_active = 1 ORDER BY start_time DESC LIMIT 1", (user_id,))
        row = cursor.fetchone()
        if not row:
            conn.close()
            return None
        
        session = dict(row)
        now = datetime.now().isoformat()
        cursor.execute("UPDATE sessions SET is_active = 0, end_time = ? WHERE session_id = ?", (now, session["session_id"]))
        
        cursor.execute("SELECT COUNT(*) as count FROM notes WHERE session_id = ? AND is_deleted = 0", (session["session_id"],))
        count = cursor.fetchone()["count"]
        
        conn.commit()
        conn.close()
        session["note_count"] = count
        session["end_time"] = now
        session["is_active"] = False
        return session

    @classmethod
    def create_note(cls, user_id: str, text: str, subject: Optional[str] = None, 
                    session_id: Optional[str] = None, explicit_tag: Optional[str] = None, 
                    confidence: float = 1.0) -> Dict[str, Any]:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # If subject/session_id not provided, check active session
        if not session_id or not subject:
            active = cls.get_active_session(user_id)
            if active:
                session_id = session_id or active["session_id"]
                subject = subject or active["subject"]
            else:
                subject = subject or "General"

        tag = cls.classify_tag(text, explicit_tag)
        now_dt = datetime.now()
        now_iso = now_dt.isoformat()
        timestamp_display = now_dt.strftime("%I:%M %p") # e.g. "10:42 AM"
        note_id = str(uuid.uuid4())
        
        cursor.execute("""
            INSERT INTO notes (note_id, user_id, session_id, subject, text, tag, timestamp, confidence, created_at, updated_at, is_deleted)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
        """, (note_id, user_id, session_id, subject.title(), text, tag, timestamp_display, confidence, now_iso, now_iso))
        
        conn.commit()
        conn.close()
        
        return {
            "note_id": note_id,
            "user_id": user_id,
            "session_id": session_id,
            "subject": subject.title(),
            "text": text,
            "tag": tag,
            "timestamp": timestamp_display,
            "confidence": confidence,
            "created_at": now_iso,
            "updated_at": now_iso
        }

    @classmethod
    def get_last_note(cls, user_id: str, session_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        if session_id:
            cursor.execute("""
                SELECT * FROM notes 
                WHERE user_id = ? AND session_id = ? AND is_deleted = 0 
                ORDER BY created_at DESC LIMIT 1
            """, (user_id, session_id))
        else:
            cursor.execute("""
                SELECT * FROM notes 
                WHERE user_id = ? AND is_deleted = 0 
                ORDER BY created_at DESC LIMIT 1
            """, (user_id,))
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

    @classmethod
    def update_tag(cls, note_id: str, new_tag: str) -> Optional[Dict[str, Any]]:
        normalized_tag = cls.classify_tag("", explicit_tag=new_tag)
        conn = get_db_connection()
        cursor = conn.cursor()
        now = datetime.now().isoformat()
        cursor.execute("""
            UPDATE notes 
            SET tag = ?, updated_at = ? 
            WHERE note_id = ? AND is_deleted = 0
        """, (normalized_tag, now, note_id))
        
        cursor.execute("SELECT * FROM notes WHERE note_id = ?", (note_id,))
        row = cursor.fetchone()
        conn.commit()
        conn.close()
        return dict(row) if row else None

    @classmethod
    def get_notes_by_filter(cls, user_id: str, subject: Optional[str] = None, 
                            tag: Optional[str] = None, timeframe: Optional[str] = None) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        query = "SELECT * FROM notes WHERE user_id = ? AND is_deleted = 0"
        params = [user_id]
        
        if subject and subject.lower() != "all":
            query += " AND LOWER(subject) = ?"
            params.append(subject.lower())
            
        if tag and tag.lower() != "all":
            # Can be multiple tags e.g. "important and definition"
            tags_to_check = []
            for t in ["Definition", "Example", "Important", "General"]:
                if t.lower() in tag.lower():
                    tags_to_check.append(t)
            if tags_to_check:
                placeholders = ",".join("?" for _ in tags_to_check)
                query += f" AND tag IN ({placeholders})"
                params.extend(tags_to_check)
                
        if timeframe:
            tf = timeframe.lower()
            now = datetime.now()
            if "today" in tf:
                start_of_day = datetime(now.year, now.month, now.day).isoformat()
                query += " AND created_at >= ?"
                params.append(start_of_day)
            elif "week" in tf:
                start_of_week = (now - timedelta(days=7)).isoformat()
                query += " AND created_at >= ?"
                params.append(start_of_week)
                
        query += " ORDER BY created_at ASC"
        cursor.execute(query, params)
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]

    @classmethod
    def get_notes_by_topic_or_subject(cls, user_id: str, topic: Optional[str] = None) -> List[Dict[str, Any]]:
        conn = get_db_connection()
        cursor = conn.cursor()

        if not topic or topic.strip().lower() in ["all", "everything", "my notes", "notes"]:
            active = cls.get_active_session(user_id)
            if active:
                cursor.execute("""
                    SELECT * FROM notes 
                    WHERE user_id = ? AND session_id = ? AND is_deleted = 0 
                    ORDER BY created_at ASC
                """, (user_id, active["session_id"]))
                rows = cursor.fetchall()
                if rows:
                    conn.close()
                    return [dict(r) for r in rows]

            cursor.execute("""
                SELECT * FROM notes 
                WHERE user_id = ? AND is_deleted = 0 
                ORDER BY created_at ASC
            """, (user_id,))
            rows = cursor.fetchall()
            conn.close()
            return [dict(r) for r in rows]

        clean_topic = topic.strip().lower()
        clean_topic = clean_topic.replace("my ", "").replace(" notes", "").strip()

        cursor.execute("""
            SELECT * FROM notes 
            WHERE user_id = ? AND is_deleted = 0 AND (
                LOWER(subject) = ? OR 
                LOWER(subject) LIKE ? OR 
                LOWER(text) LIKE ?
            )
            ORDER BY created_at ASC
        """, (user_id, clean_topic, f"%{clean_topic}%", f"%{clean_topic}%"))
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]
