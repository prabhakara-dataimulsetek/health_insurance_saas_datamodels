-- ============================================================================
-- SCHEMA: callcenter
-- Tables: agent, queue, call, call_queue_entry, call_interaction, call_notes,
--         escalation, callback_request, ivr_session
-- Depends on: member_mgmt, appeals
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS callcenter;

CREATE TABLE callcenter.agent (
    agent_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    employee_id VARCHAR(50) UNIQUE,
    agent_type VARCHAR(20) NOT NULL DEFAULT 'Human', -- Human, AI, Hybrid
    active BOOLEAN DEFAULT TRUE,
    hire_date DATE NOT NULL,
    avg_handle_time DECIMAL(10,2), -- in seconds
    avg_csat_score DECIMAL(3,2), -- 0.00 to 5.00
    calls_handled_total INTEGER DEFAULT 0,
    skills JSONB, -- ["Claims", "Benefits", "Enrollment", "Billing"]
    languages JSONB, -- ["English", "Spanish"]
    CONSTRAINT chk_agent_type CHECK (agent_type IN ('Human', 'AI', 'Hybrid')),
    CONSTRAINT chk_csat CHECK (avg_csat_score IS NULL OR (avg_csat_score >= 0 AND avg_csat_score <= 5))
);

CREATE INDEX idx_agent_active ON callcenter.agent(active) WHERE active = TRUE;
CREATE INDEX idx_agent_type ON callcenter.agent(agent_type);

CREATE TABLE callcenter.queue (
    queue_id VARCHAR(50) PRIMARY KEY,
    queue_name VARCHAR(100) NOT NULL UNIQUE,
    queue_type VARCHAR(50) NOT NULL, -- General, Claims, Benefits, Billing, Technical
    priority INTEGER NOT NULL DEFAULT 5,
    current_wait_count INTEGER DEFAULT 0,
    avg_wait_time_seconds INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_priority CHECK (priority >= 1 AND priority <= 10)
);

CREATE TABLE callcenter.call (
    call_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) REFERENCES member_mgmt.member(member_id),
    agent_id VARCHAR(50) REFERENCES callcenter.agent(agent_id),
    call_start_time TIMESTAMP NOT NULL,
    call_end_time TIMESTAMP,
    duration_seconds INTEGER,
    call_type VARCHAR(50) NOT NULL, -- Inbound, Outbound
    call_direction VARCHAR(20) NOT NULL, -- Member to Plan, Plan to Member
    phone_number VARCHAR(20),
    disposition VARCHAR(50), -- Resolved, Transferred, Escalated, Abandoned, Voicemail
    resolution_status VARCHAR(50), -- Resolved First Call, Required Follow-up, Pending
    transferred BOOLEAN DEFAULT FALSE,
    transfer_reason TEXT,
    sentiment_score DECIMAL(3,2), -- -1.00 to 1.00
    csat_score DECIMAL(3,2), -- 0.00 to 5.00
    recording_url VARCHAR(500),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_call_type CHECK (call_type IN ('Inbound', 'Outbound')),
    CONSTRAINT chk_sentiment CHECK (sentiment_score IS NULL OR (sentiment_score >= -1 AND sentiment_score <= 1)),
    CONSTRAINT chk_call_csat CHECK (csat_score IS NULL OR (csat_score >= 0 AND csat_score <= 5)),
    CONSTRAINT chk_call_duration CHECK (
        (call_end_time IS NULL AND duration_seconds IS NULL) OR
        (call_end_time >= call_start_time)
    )
);

CREATE INDEX idx_call_member ON callcenter.call(member_id);
CREATE INDEX idx_call_agent ON callcenter.call(agent_id);
CREATE INDEX idx_call_start ON callcenter.call(call_start_time);
CREATE INDEX idx_call_disposition ON callcenter.call(disposition);

-- Add FK to grievance now that call table exists
ALTER TABLE appeals.grievance
    ADD CONSTRAINT fk_grievance_call
    FOREIGN KEY (call_id) REFERENCES callcenter.call(call_id);
CREATE INDEX idx_grievance_call ON appeals.grievance(call_id);

-- Trigger: auto-calculate call duration
CREATE OR REPLACE FUNCTION callcenter.calculate_call_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.call_end_time IS NOT NULL THEN
        NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.call_end_time - NEW.call_start_time))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_call_duration
BEFORE INSERT OR UPDATE ON callcenter.call
FOR EACH ROW
EXECUTE FUNCTION callcenter.calculate_call_duration();

CREATE TABLE callcenter.call_queue_entry (
    entry_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES callcenter.call(call_id),
    queue_id VARCHAR(50) NOT NULL REFERENCES callcenter.queue(queue_id),
    entered_queue TIMESTAMP NOT NULL,
    exited_queue TIMESTAMP,
    wait_time_seconds INTEGER,
    exit_reason VARCHAR(50), -- Answered, Abandoned, Transferred
    CONSTRAINT chk_queue_times CHECK (exited_queue IS NULL OR exited_queue >= entered_queue)
);

CREATE INDEX idx_queue_entry_call ON callcenter.call_queue_entry(call_id);
CREATE INDEX idx_queue_entry_queue ON callcenter.call_queue_entry(queue_id);

CREATE TABLE callcenter.call_interaction (
    interaction_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES callcenter.call(call_id),
    sequence_number INTEGER NOT NULL,
    interaction_type VARCHAR(50) NOT NULL, -- Question, Response, Transfer, Hold
    query_category VARCHAR(100), -- Claims, Benefits, Provider Search, etc.
    query_detail TEXT,
    resolution TEXT,
    ai_agent_used BOOLEAN DEFAULT FALSE,
    escalated_to_human BOOLEAN DEFAULT FALSE,
    transcript TEXT,
    metadata JSONB,
    CONSTRAINT chk_sequence CHECK (sequence_number > 0)
);

CREATE INDEX idx_interaction_call ON callcenter.call_interaction(call_id, sequence_number);
CREATE INDEX idx_interaction_category ON callcenter.call_interaction(query_category);

CREATE TABLE callcenter.call_notes (
    note_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES callcenter.call(call_id),
    agent_id VARCHAR(50) NOT NULL REFERENCES callcenter.agent(agent_id),
    note_content TEXT NOT NULL,
    note_type VARCHAR(50) NOT NULL, -- General, Follow-up Required, Escalation, Compliance
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notes_call ON callcenter.call_notes(call_id);
CREATE INDEX idx_notes_agent ON callcenter.call_notes(agent_id);

CREATE TABLE callcenter.escalation (
    escalation_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES callcenter.call(call_id),
    from_agent_id VARCHAR(50) REFERENCES callcenter.agent(agent_id),
    to_agent_id VARCHAR(50) REFERENCES callcenter.agent(agent_id),
    escalation_reason TEXT NOT NULL,
    escalation_type VARCHAR(50) NOT NULL, -- Tier 2, Supervisor, Specialist
    escalation_time TIMESTAMP NOT NULL,
    resolution_status VARCHAR(50),
    notes TEXT,
    CONSTRAINT chk_escalation_type CHECK (escalation_type IN ('Tier 2', 'Supervisor', 'Specialist', 'Management'))
);

CREATE INDEX idx_escalation_call ON callcenter.escalation(call_id);
CREATE INDEX idx_escalation_from ON callcenter.escalation(from_agent_id);
CREATE INDEX idx_escalation_to ON callcenter.escalation(to_agent_id);

CREATE TABLE callcenter.callback_request (
    callback_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    call_id VARCHAR(50) REFERENCES callcenter.call(call_id),
    requested_time TIMESTAMP NOT NULL,
    scheduled_time TIMESTAMP,
    completed_time TIMESTAMP,
    phone_number VARCHAR(20) NOT NULL,
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    assigned_agent_id VARCHAR(50) REFERENCES callcenter.agent(agent_id),
    CONSTRAINT chk_callback_status CHECK (status IN ('Pending', 'Scheduled', 'Completed', 'Cancelled'))
);

CREATE INDEX idx_callback_member ON callcenter.callback_request(member_id);
CREATE INDEX idx_callback_status ON callcenter.callback_request(status);
CREATE INDEX idx_callback_scheduled ON callcenter.callback_request(scheduled_time);

CREATE TABLE callcenter.ivr_session (
    session_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) REFERENCES callcenter.call(call_id),
    session_start TIMESTAMP NOT NULL,
    session_end TIMESTAMP,
    phone_number VARCHAR(20) NOT NULL,
    menu_path JSONB, -- ["Main Menu", "Claims", "Claims Status"]
    exit_reason VARCHAR(50), -- Completed, Transferred to Agent, Abandoned
    transferred_to_agent BOOLEAN DEFAULT FALSE,
    self_service_completed BOOLEAN DEFAULT FALSE,
    intent_detected VARCHAR(100)
);

CREATE INDEX idx_ivr_call ON callcenter.ivr_session(call_id);
CREATE INDEX idx_ivr_start ON callcenter.ivr_session(session_start);

-- ============================================================================
-- VIEW: call center performance metrics
-- ============================================================================

CREATE VIEW callcenter.v_call_metrics AS
SELECT
    DATE(call_start_time) AS call_date,
    agent_id,
    COUNT(*) AS total_calls,
    AVG(duration_seconds) AS avg_handle_time,
    AVG(sentiment_score) AS avg_sentiment,
    AVG(csat_score) AS avg_csat,
    SUM(CASE WHEN transferred THEN 1 ELSE 0 END) AS transfer_count,
    SUM(CASE WHEN disposition = 'Resolved' THEN 1 ELSE 0 END) AS resolved_count,
    ROUND(100.0 * SUM(CASE WHEN disposition = 'Resolved' THEN 1 ELSE 0 END) / COUNT(*), 2) AS resolution_rate
FROM callcenter.call
WHERE call_end_time IS NOT NULL
GROUP BY DATE(call_start_time), agent_id;

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

INSERT INTO callcenter.agent (agent_id, first_name, last_name, email, employee_id, agent_type, hire_date, skills, languages)
VALUES
('AGT001', 'AI', 'Assistant', 'ai.assistant@healthplan.com', 'AI-001', 'AI', CURRENT_DATE,
 '["Claims", "Benefits", "Provider Search", "Eligibility"]'::jsonb,
 '["English", "Spanish", "Mandarin"]'::jsonb);
