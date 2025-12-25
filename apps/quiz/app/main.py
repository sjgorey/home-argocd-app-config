from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import sqlite3
import os

# --- App Setup ---
app = FastAPI(title="Christmas Quiz")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

DATA_DIR = "/data"
DB_PATH = os.path.join(DATA_DIR, "quiz.db")
os.makedirs(DATA_DIR, exist_ok=True)

# Serve main page and static files
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/")
def root():
    return FileResponse(os.path.join("app/static", "index.html"))

# --- Pydantic Models ---
class JoinRequest(BaseModel):
    id: str
    name: str

class AnswerRequest(BaseModel):
    guest_id: str
    question_id: int
    option: int

# --- Helper ---
def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

# --- API Endpoints ---

@app.post("/api/join")
def join(req: JoinRequest):
    conn = get_conn()
    cur = conn.cursor()
    # Try to find an existing guest by name
    cur.execute("SELECT id FROM guests WHERE name=?", (req.name,))
    row = cur.fetchone()
    if row:
        guest_id = row[0]
    else:
        guest_id = req.id
        cur.execute("INSERT INTO guests VALUES (?,?)", (guest_id, req.name))
    # Find last answered question
    cur.execute("SELECT MAX(question_id) FROM answers WHERE guest_id=?", (guest_id,))
    row = cur.fetchone()
    last_q = row[0] if row and row[0] else 0
    conn.commit()
    conn.close()
    return {"guest_id": guest_id, "name": req.name, "last_question": last_q + 1}

@app.get("/api/question/{qid}")
def get_question(qid: int):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, question, option_a, option_b, option_c, option_d FROM questions WHERE id=?", (qid,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return {"error": "question not found"}
    return {
        "id": row["id"],
        "question": row["question"],
        "options": [row["option_a"], row["option_b"], row["option_c"], row["option_d"]]
    }

@app.post("/api/answer")
def answer(req: AnswerRequest):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT answer FROM questions WHERE id=?", (req.question_id,))
    row = cur.fetchone()
    correct = 0
    if row and req.option == row["answer"]:
        correct = 1
    cur.execute(
        "INSERT INTO answers (guest_id, question_id, option, correct) VALUES (?,?,?,?)",
        (req.guest_id, req.question_id, req.option, correct)
    )
    conn.commit()
    conn.close()
    return {"correct": bool(correct)}

@app.get("/api/leaderboard")
def leaderboard():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT g.name, SUM(a.correct) as score
        FROM guests g
        JOIN answers a ON g.id = a.guest_id
        GROUP BY g.name
        ORDER BY score DESC
    """)
    rows = cur.fetchall()
    conn.close()
    return [{"name": r["name"], "score": r["score"]} for r in rows]

@app.get("/api/dbtest")
def dbtest():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM questions")
    count = cur.fetchone()[0]
    conn.close()
    return {"questions_in_db": count}

@app.post("/api/restart")
def restart():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("DELETE FROM answers")
    cur.execute("DELETE FROM guests")
    conn.commit()
    conn.close()
    return {"status": "ok", "message": "Game restarted, all users and scores cleared."}

@app.get("/api/review/{guest_id}")
def review_answers(guest_id: str):
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT q.id, q.question, q.option_a, q.option_b, q.option_c, q.option_d,
               q.answer, a.option AS guest_option, a.correct
        FROM questions q
        LEFT JOIN answers a ON q.id = a.question_id AND a.guest_id = ?
        ORDER BY q.id
    """, (guest_id,))
    rows = cur.fetchall()
    conn.close()
    return [
        {
            "id": r[0],
            "question": r[1],
            "options": [r[2], r[3], r[4], r[5]],
            "correct_answer": r[6],
            "guest_answer": r[7],
            "is_correct": bool(r[8]) if r[8] is not None else None
        }
        for r in rows
    ]
