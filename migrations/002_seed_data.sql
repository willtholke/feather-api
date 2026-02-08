-- 002_seed_data.sql
-- Seed data for Feather API
-- ~65 code review tasks + ~75 RLHF tasks, with submissions and quality reviews

DO $$
DECLARE
    v_task_id TEXT;
    v_sub_id TEXT;
    v_rev_id TEXT;
    v_assigned_to TEXT;
    v_task_status TEXT;
    v_sub_status TEXT;
    v_created_at TIMESTAMP;
    v_submitted_at TIMESTAMP;
    v_reviewed_at TIMESTAMP;
    v_time_spent INTEGER;
    v_score REAL;
    v_rating TEXT;
    v_feedback TEXT;
    v_rand FLOAT;
    v_title TEXT;
    v_reviewer TEXT;
    i INTEGER;

    -- Code review taskers
    code_taskers TEXT[] := ARRAY['usr_3j8n5r2q', 'usr_7p4w9x1m'];

    -- RLHF taskers
    rlhf_taskers TEXT[] := ARRAY['usr_2k6t8v3n', 'usr_9k2m4p7w', 'usr_5m1q7w4j', 'usr_7p4w9x1m'];

    -- Code review titles
    code_titles TEXT[] := ARRAY[
        'Review PR: Fix authentication middleware',
        'Review PR: Add rate limiting to API endpoints',
        'Review PR: Refactor database connection pooling',
        'Review PR: Update user serialization logic',
        'Review PR: Implement caching layer for queries',
        'Review PR: Fix SQL injection vulnerability',
        'Review PR: Add input validation to endpoints',
        'Review PR: Migrate to async database driver',
        'Review PR: Optimize N+1 query in user listing',
        'Review PR: Add pagination to search results',
        'Review PR: Fix CORS configuration',
        'Review PR: Implement webhook retry logic',
        'Review PR: Add health check endpoint',
        'Review PR: Refactor error handling middleware',
        'Review PR: Update logging configuration',
        'Review PR: Fix race condition in queue processor',
        'Review PR: Add database migration scripts',
        'Review PR: Implement soft delete for resources',
        'Review PR: Fix memory leak in WebSocket handler',
        'Review PR: Add API versioning support',
        'Review PR: Update dependency versions',
        'Review PR: Fix timezone handling in timestamps',
        'Review PR: Add retry logic for external calls',
        'Review PR: Refactor configuration management',
        'Review PR: Implement request tracing'
    ];

    -- RLHF titles
    rlhf_titles TEXT[] := ARRAY[
        'Rank these two responses about Python best practices',
        'Compare responses: explain quantum computing',
        'Rank responses about machine learning fundamentals',
        'Compare code explanations for sorting algorithms',
        'Rank these two responses about data structures',
        'Compare responses: explain neural networks',
        'Rank responses about web development frameworks',
        'Compare explanations of database normalization',
        'Rank these two responses about API design',
        'Compare responses: explain cloud architecture',
        'Rank responses about cybersecurity principles',
        'Compare code solutions for string manipulation',
        'Rank these two responses about DevOps practices',
        'Compare explanations of distributed systems',
        'Rank responses about software testing strategies',
        'Compare responses: explain containerization',
        'Rank these two responses about functional programming',
        'Compare code reviews for error handling',
        'Rank responses about system design patterns',
        'Compare explanations of authentication methods',
        'Rank responses about concurrency models',
        'Compare responses: explain microservices',
        'Rank these two responses about type systems',
        'Compare explanations of caching strategies',
        'Rank responses about monitoring and observability'
    ];

    -- Feedback options
    feedback_opts TEXT[] := ARRAY[
        'Good attention to detail in the analysis',
        'Consider edge cases more carefully next time',
        'Well-structured reasoning with clear justification',
        'Could improve thoroughness of the evaluation',
        'Excellent identification of potential issues',
        'Needs more detailed commentary on quality differences',
        'Strong understanding of the subject matter demonstrated',
        'Missing some critical considerations in the comparison',
        'Thorough evaluation with actionable insights',
        'Adequate but could benefit from deeper analysis',
        'Very precise and well-calibrated ranking',
        'Good work overall, minor improvements possible'
    ];

BEGIN
    -- =====================================================
    -- PROJECT 1: Code Review (proj_f_code_h2) — 65 tasks
    -- =====================================================
    FOR i IN 1..65 LOOP
        v_task_id := 'task_f_' || substr(md5('code_task_' || i::text), 1, 12);
        v_assigned_to := code_taskers[1 + (i % 2)];
        v_title := code_titles[1 + (i % array_length(code_titles, 1))];

        -- Spread created_at from Jan 2025 to Jan 2026
        v_created_at := '2025-01-01'::timestamp
            + ((i - 1) * interval '365 days' / 65)
            + (random() * interval '3 days');

        -- Status distribution: 10% pending, 15% in_progress, 30% submitted, 35% approved, 10% rejected
        v_rand := random();
        IF v_rand < 0.10 THEN
            v_task_status := 'pending';
        ELSIF v_rand < 0.25 THEN
            v_task_status := 'in_progress';
        ELSIF v_rand < 0.55 THEN
            v_task_status := 'submitted';
        ELSIF v_rand < 0.90 THEN
            v_task_status := 'approved';
        ELSE
            v_task_status := 'rejected';
        END IF;

        INSERT INTO tasks (task_id, project_id, title, type, assigned_to, status, created_at)
        VALUES (v_task_id, 'proj_f_code_h2', v_title, 'code_review', v_assigned_to, v_task_status, v_created_at);

        -- Generate submissions for tasks that are submitted/approved/rejected
        IF v_task_status IN ('submitted', 'approved', 'rejected') THEN
            v_sub_id := 'sub_f_' || substr(md5('code_sub_' || i::text), 1, 12);
            v_submitted_at := v_created_at + interval '1 day' * (1 + floor(random() * 5)::int);
            -- Code review: 10-60 minutes (600-3600 seconds)
            v_time_spent := 600 + floor(random() * 3000)::int;

            IF v_task_status = 'approved' THEN
                v_sub_status := 'approved';
            ELSIF v_task_status = 'rejected' THEN
                v_sub_status := 'rejected';
            ELSE
                -- submitted tasks: mix of pending_review and revision_requested
                IF random() < 0.75 THEN
                    v_sub_status := 'pending_review';
                ELSE
                    v_sub_status := 'revision_requested';
                END IF;
            END IF;

            INSERT INTO submissions (submission_id, task_id, submitted_by, submitted_at, time_spent_seconds, status)
            VALUES (v_sub_id, v_task_id, v_assigned_to, v_submitted_at, v_time_spent, v_sub_status);

            -- 65% chance of quality review
            IF random() < 0.65 THEN
                v_rev_id := 'rev_f_' || substr(md5('code_rev_' || i::text), 1, 12);
                v_reviewed_at := v_submitted_at + interval '1 day' * (1 + floor(random() * 4)::int);

                -- Reviewer is the other code review tasker
                IF v_assigned_to = 'usr_3j8n5r2q' THEN
                    v_reviewer := 'usr_7p4w9x1m';
                ELSE
                    v_reviewer := 'usr_3j8n5r2q';
                END IF;

                -- Score distribution: skewed toward 0.7-0.9
                v_rand := random();
                IF v_rand < 0.12 THEN
                    v_score := round((0.3 + random() * 0.35)::numeric, 2);
                ELSIF v_rand < 0.82 THEN
                    v_score := round((0.7 + random() * 0.2)::numeric, 2);
                ELSE
                    v_score := round((0.9 + random() * 0.1)::numeric, 2);
                END IF;

                IF v_score >= 0.85 THEN v_rating := 'excellent';
                ELSIF v_score >= 0.65 THEN v_rating := 'acceptable';
                ELSIF v_score >= 0.4 THEN v_rating := 'needs_improvement';
                ELSE v_rating := 'unacceptable';
                END IF;

                -- 70% chance of feedback text
                IF random() < 0.70 THEN
                    v_feedback := feedback_opts[1 + floor(random() * array_length(feedback_opts, 1))::int];
                ELSE
                    v_feedback := NULL;
                END IF;

                INSERT INTO quality_reviews (review_id, submission_id, reviewer_id, score, rating, feedback, reviewed_at)
                VALUES (v_rev_id, v_sub_id, v_reviewer, v_score, v_rating, v_feedback, v_reviewed_at);
            END IF;

            -- 20% chance of a second submission (revision)
            IF random() < 0.20 THEN
                v_sub_id := 'sub_f_' || substr(md5('code_sub2_' || i::text), 1, 12);
                v_submitted_at := v_submitted_at + interval '1 day' * (2 + floor(random() * 3)::int);
                v_time_spent := 300 + floor(random() * 2000)::int;

                IF v_task_status = 'approved' THEN
                    v_sub_status := 'approved';
                ELSE
                    v_sub_status := 'pending_review';
                END IF;

                INSERT INTO submissions (submission_id, task_id, submitted_by, submitted_at, time_spent_seconds, status)
                VALUES (v_sub_id, v_task_id, v_assigned_to, v_submitted_at, v_time_spent, v_sub_status);
            END IF;
        END IF;
    END LOOP;

    -- =====================================================
    -- PROJECT 2: RLHF Ranking (proj_f_rlhf_h3) — 75 tasks
    -- =====================================================
    FOR i IN 1..75 LOOP
        v_task_id := 'task_f_' || substr(md5('rlhf_task_' || i::text), 1, 12);
        v_assigned_to := rlhf_taskers[1 + (i % array_length(rlhf_taskers, 1))];
        v_title := rlhf_titles[1 + (i % array_length(rlhf_titles, 1))];

        -- Spread created_at from Jan 2025 to Jan 2026
        v_created_at := '2025-01-01'::timestamp
            + ((i - 1) * interval '365 days' / 75)
            + (random() * interval '3 days');

        -- Status distribution
        v_rand := random();
        IF v_rand < 0.08 THEN
            v_task_status := 'pending';
        ELSIF v_rand < 0.20 THEN
            v_task_status := 'in_progress';
        ELSIF v_rand < 0.50 THEN
            v_task_status := 'submitted';
        ELSIF v_rand < 0.88 THEN
            v_task_status := 'approved';
        ELSE
            v_task_status := 'rejected';
        END IF;

        INSERT INTO tasks (task_id, project_id, title, type, assigned_to, status, created_at)
        VALUES (v_task_id, 'proj_f_rlhf_h3', v_title, 'rlhf_ranking', v_assigned_to, v_task_status, v_created_at);

        -- Generate submissions
        IF v_task_status IN ('submitted', 'approved', 'rejected') THEN
            v_sub_id := 'sub_f_' || substr(md5('rlhf_sub_' || i::text), 1, 12);
            v_submitted_at := v_created_at + interval '1 hour' * (1 + floor(random() * 48)::int);
            -- RLHF: 2-15 minutes (120-900 seconds)
            v_time_spent := 120 + floor(random() * 780)::int;

            IF v_task_status = 'approved' THEN
                v_sub_status := 'approved';
            ELSIF v_task_status = 'rejected' THEN
                v_sub_status := 'rejected';
            ELSE
                IF random() < 0.80 THEN
                    v_sub_status := 'pending_review';
                ELSE
                    v_sub_status := 'revision_requested';
                END IF;
            END IF;

            INSERT INTO submissions (submission_id, task_id, submitted_by, submitted_at, time_spent_seconds, status)
            VALUES (v_sub_id, v_task_id, v_assigned_to, v_submitted_at, v_time_spent, v_sub_status);

            -- 65% chance of quality review
            IF random() < 0.65 THEN
                v_rev_id := 'rev_f_' || substr(md5('rlhf_rev_' || i::text), 1, 12);
                v_reviewed_at := v_submitted_at + interval '1 day' * (1 + floor(random() * 3)::int);

                -- Pick a different tasker as reviewer
                LOOP
                    v_reviewer := rlhf_taskers[1 + floor(random() * array_length(rlhf_taskers, 1))::int];
                    EXIT WHEN v_reviewer <> v_assigned_to;
                END LOOP;

                -- Score distribution: skewed toward 0.7-0.9
                v_rand := random();
                IF v_rand < 0.10 THEN
                    v_score := round((0.25 + random() * 0.4)::numeric, 2);
                ELSIF v_rand < 0.80 THEN
                    v_score := round((0.7 + random() * 0.2)::numeric, 2);
                ELSE
                    v_score := round((0.9 + random() * 0.1)::numeric, 2);
                END IF;

                IF v_score >= 0.85 THEN v_rating := 'excellent';
                ELSIF v_score >= 0.65 THEN v_rating := 'acceptable';
                ELSIF v_score >= 0.4 THEN v_rating := 'needs_improvement';
                ELSE v_rating := 'unacceptable';
                END IF;

                IF random() < 0.70 THEN
                    v_feedback := feedback_opts[1 + floor(random() * array_length(feedback_opts, 1))::int];
                ELSE
                    v_feedback := NULL;
                END IF;

                INSERT INTO quality_reviews (review_id, submission_id, reviewer_id, score, rating, feedback, reviewed_at)
                VALUES (v_rev_id, v_sub_id, v_reviewer, v_score, v_rating, v_feedback, v_reviewed_at);
            END IF;

            -- 25% chance of second submission
            IF random() < 0.25 THEN
                v_sub_id := 'sub_f_' || substr(md5('rlhf_sub2_' || i::text), 1, 12);
                v_submitted_at := v_submitted_at + interval '1 hour' * (2 + floor(random() * 24)::int);
                v_time_spent := 90 + floor(random() * 600)::int;

                IF v_task_status = 'approved' THEN
                    v_sub_status := 'approved';
                ELSE
                    v_sub_status := 'pending_review';
                END IF;

                INSERT INTO submissions (submission_id, task_id, submitted_by, submitted_at, time_spent_seconds, status)
                VALUES (v_sub_id, v_task_id, v_assigned_to, v_submitted_at, v_time_spent, v_sub_status);
            END IF;
        END IF;
    END LOOP;
END $$;
