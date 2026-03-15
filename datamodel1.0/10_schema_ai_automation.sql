-- ============================================================================
-- SCHEMA: ai_automation
-- Tables: knowledge_base, ai_automation_log
-- Depends on: callcenter
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS ai_automation;

CREATE TABLE ai_automation.knowledge_base (
    kb_id VARCHAR(50) PRIMARY KEY,
    category VARCHAR(100) NOT NULL,
    subcategory VARCHAR(100),
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    related_cpt_codes JSONB,
    related_icd_codes JSONB,
    usage_count INTEGER DEFAULT 0,
    helpfulness_score DECIMAL(3,2), -- 0.00 to 5.00
    active BOOLEAN DEFAULT TRUE,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_kb_helpfulness CHECK (helpfulness_score IS NULL OR (helpfulness_score >= 0 AND helpfulness_score <= 5))
);

CREATE INDEX idx_kb_category ON ai_automation.knowledge_base(category, subcategory);
CREATE INDEX idx_kb_active ON ai_automation.knowledge_base(active) WHERE active = TRUE;
CREATE INDEX idx_kb_search ON ai_automation.knowledge_base USING GIN (to_tsvector('english', question || ' ' || answer));

CREATE TABLE ai_automation.ai_automation_log (
    log_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) REFERENCES callcenter.call(call_id),
    interaction_id VARCHAR(50) REFERENCES callcenter.call_interaction(interaction_id),
    ai_model_used VARCHAR(100) NOT NULL, -- GPT-4o, Claude Sonnet 4, Deepgram, ElevenLabs
    intent_detected VARCHAR(100),
    confidence_score DECIMAL(5,4), -- 0.0000 to 1.0000
    automation_successful BOOLEAN NOT NULL,
    fallback_reason TEXT,
    api_calls_made JSONB, -- Array of API calls with timestamps
    response_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_confidence CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 1))
);

CREATE INDEX idx_ai_log_call ON ai_automation.ai_automation_log(call_id);
CREATE INDEX idx_ai_log_interaction ON ai_automation.ai_automation_log(interaction_id);
CREATE INDEX idx_ai_log_success ON ai_automation.ai_automation_log(automation_successful);
CREATE INDEX idx_ai_log_created ON ai_automation.ai_automation_log(created_at);

-- ============================================================================
-- VIEW: AI automation performance metrics
-- ============================================================================

CREATE VIEW ai_automation.v_ai_automation_metrics AS
SELECT
    DATE(created_at) AS metric_date,
    ai_model_used,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN automation_successful THEN 1 ELSE 0 END) AS successful_automations,
    ROUND(100.0 * SUM(CASE WHEN automation_successful THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate,
    AVG(confidence_score) AS avg_confidence,
    AVG(response_time_ms) AS avg_response_time_ms
FROM ai_automation.ai_automation_log
GROUP BY DATE(created_at), ai_model_used;

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

INSERT INTO ai_automation.knowledge_base (kb_id, category, subcategory, question, answer, active)
VALUES
('KB001', 'Benefits', 'Deductible', 'What is a deductible?',
 'A deductible is the amount you pay for covered health care services before your insurance plan starts to pay. For example, if your deductible is $1,000, you pay the first $1,000 of covered services yourself.',
 TRUE),
('KB002', 'Claims', 'Status', 'How do I check my claim status?',
 'You can check your claim status by calling us, logging into your member portal, or our AI assistant can look it up for you right now if you provide your claim number or date of service.',
 TRUE);
