-- 001_create_tables.sql
-- Feather API schema: tasks, submissions, quality_reviews

DROP TABLE IF EXISTS quality_reviews CASCADE;
DROP TABLE IF EXISTS submissions CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;

CREATE TABLE tasks (
    task_id     VARCHAR PRIMARY KEY,
    project_id  VARCHAR NOT NULL,
    title       VARCHAR NOT NULL,
    type        VARCHAR NOT NULL,
    assigned_to VARCHAR NOT NULL,
    status      VARCHAR NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE submissions (
    submission_id      VARCHAR PRIMARY KEY,
    task_id            VARCHAR NOT NULL REFERENCES tasks(task_id),
    submitted_by       VARCHAR NOT NULL,
    submitted_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    time_spent_seconds INTEGER NOT NULL,
    status             VARCHAR NOT NULL
);

CREATE TABLE quality_reviews (
    review_id     VARCHAR PRIMARY KEY,
    submission_id VARCHAR NOT NULL REFERENCES submissions(submission_id),
    reviewer_id   VARCHAR NOT NULL,
    score         REAL NOT NULL,
    rating        VARCHAR NOT NULL,
    feedback      TEXT,
    reviewed_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX idx_submissions_task_id ON submissions(task_id);
CREATE INDEX idx_submissions_submitted_by ON submissions(submitted_by);
CREATE INDEX idx_quality_reviews_submission_id ON quality_reviews(submission_id);
CREATE INDEX idx_quality_reviews_reviewer_id ON quality_reviews(reviewer_id);
