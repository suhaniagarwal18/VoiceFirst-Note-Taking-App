import re
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from database import get_db_connection
from services.search_service import SearchService

class TimelineService:
    @classmethod
    def query_topic_time(cls, user_id: str, topic: str) -> Dict[str, Any]:
        """
        Answers: 'Where did I note [topic]?' or 'When did I mention [topic]?'
        Returns exact real timestamp and note content.
        """
        results = SearchService.search_notes(user_id, topic)
        if not results:
            return {
                "found": False,
                "speech": f"I couldn't find any mention of {topic} in your notes."
            }

        top_note = results[0]
        # Parse created_at for human-friendly date if not today
        try:
            dt = datetime.fromisoformat(top_note["created_at"])
            is_today = dt.date() == datetime.now().date()
            date_str = "today" if is_today else dt.strftime("%A, %B %d")
        except Exception:
            date_str = "in your notes"

        timestamp = top_note["timestamp"]
        subject = top_note["subject"]
        text = top_note["text"]

        speech = f"You noted {topic} {date_str} around {timestamp} during {subject}. The note says: {text}"
        return {
            "found": True,
            "speech": speech,
            "note": top_note
        }

    @classmethod
    def query_notes_around_time(cls, user_id: str, time_query: str) -> Dict[str, Any]:
        """
        Answers: 'What did I note around 11 AM?'
        """
        conn = get_db_connection()
        cursor = conn.cursor()
        now = datetime.now()
        start_of_day = datetime(now.year, now.month, now.day).isoformat()

        cursor.execute("""
            SELECT * FROM notes 
            WHERE user_id = ? AND is_deleted = 0 AND created_at >= ?
            ORDER BY created_at ASC
        """, (user_id, start_of_day))
        rows = cursor.fetchall()
        conn.close()

        notes = [dict(r) for r in rows]
        if not notes:
            return {
                "found": False,
                "speech": f"You haven't recorded any notes today around {time_query}."
            }

        # Parse target hour from time_query e.g. "11 AM", "11:00", "2 PM"
        target_hour = None
        match = re.search(r"(\d{1,2})(?::(\d{2}))?\s*(am|pm)?", time_query, re.IGNORECASE)
        if match:
            h = int(match.group(1))
            meridiem = match.group(3)
            if meridiem:
                if meridiem.lower() == "pm" and h < 12:
                    h += 12
                elif meridiem.lower() == "am" and h == 12:
                    h = 0
            target_hour = h

        matching_notes = []
        if target_hour is not None:
            for n in notes:
                try:
                    dt = datetime.fromisoformat(n["created_at"])
                    # within +/- 1 hour
                    if abs(dt.hour - target_hour) <= 1:
                        matching_notes.append(n)
                except Exception:
                    pass
        else:
            # If couldn't parse specific hour, match substring in timestamp string
            matching_notes = [n for n in notes if time_query.lower() in n["timestamp"].lower()]

        if not matching_notes:
            return {
                "found": False,
                "speech": f"I couldn't find any notes recorded around {time_query} today."
            }

        summaries = [f"At {n['timestamp']}: {n['text']}" for n in matching_notes[:3]]
        speech = f"Around {time_query}, you noted: " + ". ".join(summaries)
        return {
            "found": True,
            "speech": speech,
            "notes": matching_notes
        }

    @classmethod
    def get_today_topics_summary(cls, user_id: str) -> Dict[str, Any]:
        """
        Answers: 'What topics did I cover today?'
        """
        now = datetime.now()
        start_of_day = datetime(now.year, now.month, now.day).isoformat()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM notes 
            WHERE user_id = ? AND is_deleted = 0 AND created_at >= ?
            ORDER BY created_at ASC
        """, (user_id, start_of_day))
        rows = cursor.fetchall()
        conn.close()

        notes = [dict(r) for r in rows]
        if not notes:
            return {
                "found": False,
                "speech": "You haven't recorded any notes today yet."
            }

        subjects = {}
        for n in notes:
            subj = n["subject"]
            subjects.setdefault(subj, []).append(n)

        parts = []
        for subj, sub_notes in subjects.items():
            count = len(sub_notes)
            key_terms = [n["text"].split()[0:4] for n in sub_notes[:2]]
            sample = ", ".join([" ".join(w) for w in key_terms])
            parts.append(f"{subj} with {count} note{'s' if count > 1 else ''}")

        speech = f"Today you recorded notes in: " + ", ".join(parts) + "."
        return {
            "found": True,
            "speech": speech,
            "subjects": list(subjects.keys()),
            "total_notes": len(notes)
        }
