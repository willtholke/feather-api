import os
from typing import Optional

import psycopg2
import psycopg2.extras
from fastapi import Depends, FastAPI, Header, HTTPException, Query

app = FastAPI(title="Feather API")

API_KEY = os.environ.get("API_KEY")


def verify_api_key(x_api_key: str = Header()):
    if not API_KEY:
        raise HTTPException(status_code=500, detail="API key not configured")
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")


def get_conn():
    return psycopg2.connect(os.environ["DATABASE_URL"])


def rows_to_dicts(rows):
    """Convert RealDictRow objects to plain dicts with serializable values."""
    result = []
    for row in rows:
        d = {}
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                d[k] = v.isoformat()
            else:
                d[k] = v
        result.append(d)
    return result


@app.get("/healthcheck")
def healthcheck():
    return "API is working perfectly fine. Bleep bloop. Thanks for checking."


@app.get("/tasks", dependencies=[Depends(verify_api_key)])
def list_tasks(
    project_id: Optional[str] = None,
    status: Optional[str] = None,
    assigned_to: Optional[str] = None,
    created_after: Optional[str] = None,
    created_before: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    query = "SELECT * FROM tasks WHERE 1=1"
    params = []

    if project_id:
        query += " AND project_id = %s"
        params.append(project_id)
    if status:
        query += " AND status = %s"
        params.append(status)
    if assigned_to:
        query += " AND assigned_to = %s"
        params.append(assigned_to)
    if created_after:
        query += " AND created_at >= %s"
        params.append(created_after)
    if created_before:
        query += " AND created_at <= %s"
        params.append(created_before)

    query += " ORDER BY created_at DESC LIMIT %s OFFSET %s"
    params.extend([limit, offset])

    cur.execute(query, params)
    rows = rows_to_dicts(cur.fetchall())
    cur.close()
    conn.close()
    return rows


@app.get("/submissions", dependencies=[Depends(verify_api_key)])
def list_submissions(
    task_id: Optional[str] = None,
    submitted_by: Optional[str] = None,
    project_id: Optional[str] = None,
    submitted_after: Optional[str] = None,
    submitted_before: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    if project_id:
        query = """
            SELECT s.* FROM submissions s
            JOIN tasks t ON s.task_id = t.task_id
            WHERE 1=1
        """
    else:
        query = "SELECT * FROM submissions s WHERE 1=1"
    params = []

    if task_id:
        query += " AND s.task_id = %s"
        params.append(task_id)
    if submitted_by:
        query += " AND s.submitted_by = %s"
        params.append(submitted_by)
    if project_id:
        query += " AND t.project_id = %s"
        params.append(project_id)
    if submitted_after:
        query += " AND s.submitted_at >= %s"
        params.append(submitted_after)
    if submitted_before:
        query += " AND s.submitted_at <= %s"
        params.append(submitted_before)

    query += " ORDER BY s.submitted_at DESC LIMIT %s OFFSET %s"
    params.extend([limit, offset])

    cur.execute(query, params)
    rows = rows_to_dicts(cur.fetchall())
    cur.close()
    conn.close()
    return rows


@app.get("/submissions/enriched", dependencies=[Depends(verify_api_key)])
def list_submissions_enriched(
    submitted_by: Optional[str] = None,
    project_id: Optional[str] = None,
    submitted_after: Optional[str] = None,
    submitted_before: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    query = """
        SELECT
            s.submission_id,
            s.task_id,
            s.submitted_by,
            s.submitted_at,
            s.time_spent_seconds,
            s.status AS submission_status,
            t.title AS task_title,
            t.type AS task_type,
            t.status AS task_status,
            t.project_id,
            COALESCE(r.review_count, 0) AS review_count,
            COALESCE(r.avg_score, 0) AS avg_review_score,
            COALESCE(r.median_score, 0) AS median_review_score,
            COALESCE(r.min_score, 0) AS min_review_score,
            COALESCE(r.max_score, 0) AS max_review_score
        FROM submissions s
        JOIN tasks t ON s.task_id = t.task_id
        LEFT JOIN LATERAL (
            SELECT
                COUNT(*)::int AS review_count,
                ROUND(AVG(qr.score)::numeric, 4) AS avg_score,
                ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY qr.score)::numeric, 4) AS median_score,
                ROUND(MIN(qr.score)::numeric, 4) AS min_score,
                ROUND(MAX(qr.score)::numeric, 4) AS max_score
            FROM quality_reviews qr
            WHERE qr.submission_id = s.submission_id
        ) r ON true
        WHERE 1=1
    """
    params = []

    if submitted_by:
        query += " AND s.submitted_by = %s"
        params.append(submitted_by)
    if project_id:
        query += " AND t.project_id = %s"
        params.append(project_id)
    if submitted_after:
        query += " AND s.submitted_at >= %s"
        params.append(submitted_after)
    if submitted_before:
        query += " AND s.submitted_at <= %s"
        params.append(submitted_before)

    query += " ORDER BY s.submitted_at DESC LIMIT %s OFFSET %s"
    params.extend([limit, offset])

    cur.execute(query, params)
    rows = rows_to_dicts(cur.fetchall())
    cur.close()
    conn.close()
    return rows


@app.get("/quality_reviews", dependencies=[Depends(verify_api_key)])
def list_quality_reviews(
    submission_id: Optional[str] = None,
    reviewer_id: Optional[str] = None,
    project_id: Optional[str] = None,
    reviewed_after: Optional[str] = None,
    reviewed_before: Optional[str] = None,
    limit: int = Query(default=50, le=200),
    offset: int = Query(default=0, ge=0),
):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    if project_id:
        query = """
            SELECT qr.* FROM quality_reviews qr
            JOIN submissions s ON qr.submission_id = s.submission_id
            JOIN tasks t ON s.task_id = t.task_id
            WHERE 1=1
        """
    else:
        query = "SELECT * FROM quality_reviews qr WHERE 1=1"
    params = []

    if submission_id:
        query += " AND qr.submission_id = %s"
        params.append(submission_id)
    if reviewer_id:
        query += " AND qr.reviewer_id = %s"
        params.append(reviewer_id)
    if project_id:
        query += " AND t.project_id = %s"
        params.append(project_id)
    if reviewed_after:
        query += " AND qr.reviewed_at >= %s"
        params.append(reviewed_after)
    if reviewed_before:
        query += " AND qr.reviewed_at <= %s"
        params.append(reviewed_before)

    query += " ORDER BY qr.reviewed_at DESC LIMIT %s OFFSET %s"
    params.extend([limit, offset])

    cur.execute(query, params)
    rows = rows_to_dicts(cur.fetchall())
    cur.close()
    conn.close()
    return rows
