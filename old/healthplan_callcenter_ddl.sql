-- Health Plan Call Center Database Schema
-- PostgreSQL DDL with HIPAA compliance considerations
-- Created: 2026-03-14

-- ============================================================================
-- MEMBER MANAGEMENT
-- ============================================================================

CREATE TABLE member (
    member_id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    ssn_last4 VARCHAR(4),
    email VARCHAR(255),
    phone_primary VARCHAR(20),
    phone_secondary VARCHAR(20),
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    language_preference VARCHAR(50) DEFAULT 'English',
    accessible_format_required BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_state CHECK (state ~ '^[A-Z]{2}$')
);

CREATE INDEX idx_member_dob ON member(date_of_birth);
CREATE INDEX idx_member_name ON member(last_name, first_name);
CREATE INDEX idx_member_phone ON member(phone_primary);

COMMENT ON TABLE member IS 'PHI - Protected Health Information. Encrypt at rest.';
COMMENT ON COLUMN member.ssn_last4 IS 'Last 4 digits only for member identification';

-- ============================================================================
-- PLAN & GROUP MANAGEMENT
-- ============================================================================

CREATE TABLE plan (
    plan_id VARCHAR(50) PRIMARY KEY,
    plan_name VARCHAR(255) NOT NULL,
    plan_type VARCHAR(50) NOT NULL, -- PPO, HMO, EPO, HDHP
    network_type VARCHAR(50) NOT NULL, -- In-Network, Out-of-Network, Both
    individual_deductible DECIMAL(10,2) NOT NULL,
    family_deductible DECIMAL(10,2) NOT NULL,
    individual_oop_max DECIMAL(10,2) NOT NULL,
    family_oop_max DECIMAL(10,2) NOT NULL,
    requires_referrals BOOLEAN DEFAULT FALSE,
    requires_prior_auth BOOLEAN DEFAULT FALSE,
    effective_date DATE NOT NULL,
    termination_date DATE,
    CONSTRAINT chk_plan_type CHECK (plan_type IN ('PPO', 'HMO', 'EPO', 'HDHP', 'POS')),
    CONSTRAINT chk_deductible CHECK (individual_deductible >= 0 AND family_deductible >= individual_deductible),
    CONSTRAINT chk_oop_max CHECK (individual_oop_max >= individual_deductible AND family_oop_max >= family_deductible)
);

CREATE INDEX idx_plan_active ON plan(effective_date, termination_date) WHERE termination_date IS NULL;

CREATE TABLE "group" (
    group_id VARCHAR(50) PRIMARY KEY,
    group_name VARCHAR(255) NOT NULL,
    employer_name VARCHAR(255),
    group_type VARCHAR(50) NOT NULL, -- Commercial, Medicare, Medicaid, Individual
    member_count INTEGER DEFAULT 0,
    effective_date DATE NOT NULL,
    contact_name VARCHAR(200),
    contact_email VARCHAR(255),
    contact_phone VARCHAR(20),
    CONSTRAINT chk_member_count CHECK (member_count >= 0)
);

CREATE TABLE enrollment (
    enrollment_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    plan_id VARCHAR(50) NOT NULL REFERENCES plan(plan_id),
    group_id VARCHAR(50) REFERENCES "group"(group_id),
    effective_date DATE NOT NULL,
    termination_date DATE,
    enrollment_status VARCHAR(20) NOT NULL DEFAULT 'Active',
    subscriber_relationship VARCHAR(20) NOT NULL, -- Self, Spouse, Child, Other
    is_subscriber BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_enrollment_status CHECK (enrollment_status IN ('Active', 'Terminated', 'Suspended', 'Pending')),
    CONSTRAINT chk_dates CHECK (termination_date IS NULL OR termination_date >= effective_date)
);

CREATE INDEX idx_enrollment_member ON enrollment(member_id);
CREATE INDEX idx_enrollment_plan ON enrollment(plan_id);
CREATE INDEX idx_enrollment_active ON enrollment(enrollment_status) WHERE enrollment_status = 'Active';

-- ============================================================================
-- BENEFITS & COVERAGE
-- ============================================================================

CREATE TABLE benefit_coverage (
    coverage_id VARCHAR(50) PRIMARY KEY,
    plan_id VARCHAR(50) NOT NULL REFERENCES plan(plan_id),
    service_category VARCHAR(100) NOT NULL, -- Primary Care, Specialist, Emergency, etc.
    cpt_code_range VARCHAR(100), -- e.g., "99201-99215" or specific code
    covered BOOLEAN DEFAULT TRUE,
    copay DECIMAL(10,2) DEFAULT 0,
    coinsurance DECIMAL(5,2) DEFAULT 0, -- Percentage (e.g., 20.00 for 20%)
    deductible_applies BOOLEAN DEFAULT TRUE,
    requires_prior_auth BOOLEAN DEFAULT FALSE,
    requires_referral BOOLEAN DEFAULT FALSE,
    visit_limit INTEGER,
    visit_limit_period VARCHAR(20), -- Annual, Per Condition, Lifetime
    notes TEXT,
    CONSTRAINT chk_coinsurance CHECK (coinsurance >= 0 AND coinsurance <= 100)
);

CREATE INDEX idx_coverage_plan ON benefit_coverage(plan_id);
CREATE INDEX idx_coverage_service ON benefit_coverage(service_category);

CREATE TABLE accumulator (
    accumulator_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    plan_id VARCHAR(50) NOT NULL REFERENCES plan(plan_id),
    calendar_year INTEGER NOT NULL,
    individual_deductible_met DECIMAL(10,2) DEFAULT 0,
    family_deductible_met DECIMAL(10,2) DEFAULT 0,
    individual_oop_met DECIMAL(10,2) DEFAULT 0,
    family_oop_met DECIMAL(10,2) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_year CHECK (calendar_year >= 2000 AND calendar_year <= 2100),
    CONSTRAINT chk_amounts CHECK (
        individual_deductible_met >= 0 AND
        family_deductible_met >= 0 AND
        individual_oop_met >= 0 AND
        family_oop_met >= 0
    ),
    UNIQUE(member_id, plan_id, calendar_year)
);

CREATE INDEX idx_accumulator_member_year ON accumulator(member_id, calendar_year);

-- ============================================================================
-- PROVIDER NETWORK
-- ============================================================================

CREATE TABLE provider (
    provider_id VARCHAR(50) PRIMARY KEY,
    npi VARCHAR(10) UNIQUE NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    practice_name VARCHAR(255),
    specialty VARCHAR(100) NOT NULL,
    provider_type VARCHAR(50) NOT NULL, -- Individual, Group, Facility
    accepting_new_patients BOOLEAN DEFAULT TRUE,
    network_status VARCHAR(20) NOT NULL DEFAULT 'In-Network',
    effective_date DATE NOT NULL,
    termination_date DATE,
    rating DECIMAL(3,2), -- e.g., 4.75
    review_count INTEGER DEFAULT 0,
    CONSTRAINT chk_npi CHECK (npi ~ '^\d{10}$'),
    CONSTRAINT chk_network_status CHECK (network_status IN ('In-Network', 'Out-of-Network', 'Pending')),
    CONSTRAINT chk_rating CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5))
);

CREATE INDEX idx_provider_npi ON provider(npi);
CREATE INDEX idx_provider_specialty ON provider(specialty);
CREATE INDEX idx_provider_network ON provider(network_status) WHERE network_status = 'In-Network';

CREATE TABLE provider_location (
    location_id VARCHAR(50) PRIMARY KEY,
    provider_id VARCHAR(50) NOT NULL REFERENCES provider(provider_id),
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(2) NOT NULL,
    zip_code VARCHAR(10) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    fax VARCHAR(20),
    office_hours JSONB, -- {"monday": "8:00 AM - 5:00 PM", ...}
    languages_spoken JSONB, -- ["English", "Spanish", "Mandarin"]
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    CONSTRAINT chk_state_loc CHECK (state ~ '^[A-Z]{2}$')
);

CREATE INDEX idx_location_provider ON provider_location(provider_id);
CREATE INDEX idx_location_zip ON provider_location(zip_code);
CREATE INDEX idx_location_geo ON provider_location USING GIST (
    ll_to_earth(latitude, longitude)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- ============================================================================
-- CLAIMS & AUTHORIZATIONS
-- ============================================================================

CREATE TABLE claim (
    claim_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    provider_id VARCHAR(50) REFERENCES provider(provider_id),
    date_of_service DATE NOT NULL,
    received_date DATE NOT NULL,
    processed_date DATE,
    claim_status VARCHAR(20) NOT NULL DEFAULT 'Received',
    total_charged DECIMAL(10,2) NOT NULL,
    allowed_amount DECIMAL(10,2),
    plan_paid DECIMAL(10,2) DEFAULT 0,
    member_responsibility DECIMAL(10,2) DEFAULT 0,
    deductible DECIMAL(10,2) DEFAULT 0,
    copay DECIMAL(10,2) DEFAULT 0,
    coinsurance DECIMAL(10,2) DEFAULT 0,
    denial_reason TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_claim_status CHECK (claim_status IN ('Received', 'Processing', 'Pending', 'Processed', 'Paid', 'Denied', 'Appealed')),
    CONSTRAINT chk_claim_amounts CHECK (
        total_charged >= 0 AND
        (allowed_amount IS NULL OR allowed_amount >= 0) AND
        plan_paid >= 0 AND
        member_responsibility >= 0 AND
        deductible >= 0 AND
        copay >= 0 AND
        coinsurance >= 0
    )
);

CREATE INDEX idx_claim_member ON claim(member_id);
CREATE INDEX idx_claim_provider ON claim(provider_id);
CREATE INDEX idx_claim_status ON claim(claim_status);
CREATE INDEX idx_claim_dos ON claim(date_of_service);

CREATE TABLE prior_authorization (
    auth_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    provider_id VARCHAR(50) REFERENCES provider(provider_id),
    service_type VARCHAR(100) NOT NULL,
    cpt_code VARCHAR(10),
    requested_date DATE NOT NULL,
    decision_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    approval_number VARCHAR(50),
    valid_from DATE,
    valid_through DATE,
    units_approved INTEGER,
    units_used INTEGER DEFAULT 0,
    denial_reason TEXT,
    appeal_status VARCHAR(20),
    CONSTRAINT chk_pa_status CHECK (status IN ('Pending', 'Approved', 'Denied', 'Expired', 'In Review')),
    CONSTRAINT chk_pa_dates CHECK (valid_through IS NULL OR valid_through >= valid_from),
    CONSTRAINT chk_units CHECK (units_used IS NULL OR units_approved IS NULL OR units_used <= units_approved)
);

CREATE INDEX idx_pa_member ON prior_authorization(member_id);
CREATE INDEX idx_pa_status ON prior_authorization(status);
CREATE INDEX idx_pa_valid ON prior_authorization(valid_from, valid_through);

CREATE TABLE referral (
    referral_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    from_provider_id VARCHAR(50) REFERENCES provider(provider_id),
    to_provider_id VARCHAR(50) REFERENCES provider(provider_id),
    specialty_needed VARCHAR(100) NOT NULL,
    referral_date DATE NOT NULL,
    expiration_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Active',
    visits_authorized INTEGER,
    visits_used INTEGER DEFAULT 0,
    CONSTRAINT chk_referral_status CHECK (status IN ('Active', 'Expired', 'Completed', 'Cancelled')),
    CONSTRAINT chk_referral_visits CHECK (visits_used IS NULL OR visits_authorized IS NULL OR visits_used <= visits_authorized)
);

CREATE INDEX idx_referral_member ON referral(member_id);
CREATE INDEX idx_referral_to_provider ON referral(to_provider_id);

-- ============================================================================
-- APPEALS & GRIEVANCES
-- ============================================================================

CREATE TABLE appeal (
    appeal_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    claim_id VARCHAR(50) REFERENCES claim(claim_id),
    auth_id VARCHAR(50) REFERENCES prior_authorization(auth_id),
    appeal_type VARCHAR(50) NOT NULL, -- Claim Denial, Prior Auth Denial, Coverage Decision
    filed_date DATE NOT NULL,
    decision_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Submitted',
    outcome VARCHAR(20),
    reason TEXT NOT NULL,
    decision_rationale TEXT,
    CONSTRAINT chk_appeal_status CHECK (status IN ('Submitted', 'Under Review', 'Pending Information', 'Decided', 'Withdrawn')),
    CONSTRAINT chk_appeal_outcome CHECK (outcome IS NULL OR outcome IN ('Upheld', 'Overturned', 'Partially Approved')),
    CONSTRAINT chk_appeal_reference CHECK (claim_id IS NOT NULL OR auth_id IS NOT NULL)
);

CREATE INDEX idx_appeal_member ON appeal(member_id);
CREATE INDEX idx_appeal_claim ON appeal(claim_id);
CREATE INDEX idx_appeal_status ON appeal(status);

CREATE TABLE grievance (
    grievance_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    call_id VARCHAR(50), -- FK added after call table created
    filed_date DATE NOT NULL,
    grievance_type VARCHAR(50) NOT NULL, -- Service Quality, Access to Care, Billing, Other
    category VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'Open',
    resolution_date DATE,
    resolution TEXT,
    assigned_to VARCHAR(100),
    CONSTRAINT chk_grievance_status CHECK (status IN ('Open', 'In Progress', 'Resolved', 'Closed')),
    CONSTRAINT chk_grievance_resolution CHECK (
        (status IN ('Resolved', 'Closed') AND resolution_date IS NOT NULL) OR
        (status NOT IN ('Resolved', 'Closed'))
    )
);

CREATE INDEX idx_grievance_member ON grievance(member_id);
CREATE INDEX idx_grievance_status ON grievance(status);

-- ============================================================================
-- BILLING & PAYMENTS
-- ============================================================================

CREATE TABLE premium (
    premium_id VARCHAR(50) PRIMARY KEY,
    enrollment_id VARCHAR(50) NOT NULL REFERENCES enrollment(enrollment_id),
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    billing_month INTEGER NOT NULL,
    billing_year INTEGER NOT NULL,
    premium_amount DECIMAL(10,2) NOT NULL,
    due_date DATE NOT NULL,
    paid_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Unpaid',
    balance DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_premium_month CHECK (billing_month >= 1 AND billing_month <= 12),
    CONSTRAINT chk_premium_year CHECK (billing_year >= 2000 AND billing_year <= 2100),
    CONSTRAINT chk_premium_status CHECK (status IN ('Unpaid', 'Paid', 'Partial', 'Past Due', 'Waived')),
    CONSTRAINT chk_premium_amount CHECK (premium_amount >= 0 AND balance >= 0),
    UNIQUE(enrollment_id, billing_year, billing_month)
);

CREATE INDEX idx_premium_member ON premium(member_id);
CREATE INDEX idx_premium_status ON premium(status);
CREATE INDEX idx_premium_due ON premium(due_date);

CREATE TABLE payment (
    payment_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATE NOT NULL,
    payment_method VARCHAR(50) NOT NULL, -- Credit Card, ACH, Check, Cash
    payment_type VARCHAR(50) NOT NULL, -- Premium, Claim, Copay
    confirmation_number VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'Completed',
    applied_to VARCHAR(50), -- Reference to premium_id or claim_id
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT chk_payment_status CHECK (status IN ('Pending', 'Completed', 'Failed', 'Refunded'))
);

CREATE INDEX idx_payment_member ON payment(member_id);
CREATE INDEX idx_payment_date ON payment(payment_date);

-- ============================================================================
-- CALL CENTER OPERATIONS
-- ============================================================================

CREATE TABLE agent (
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

CREATE INDEX idx_agent_active ON agent(active) WHERE active = TRUE;
CREATE INDEX idx_agent_type ON agent(agent_type);

CREATE TABLE queue (
    queue_id VARCHAR(50) PRIMARY KEY,
    queue_name VARCHAR(100) NOT NULL UNIQUE,
    queue_type VARCHAR(50) NOT NULL, -- General, Claims, Benefits, Billing, Technical
    priority INTEGER NOT NULL DEFAULT 5,
    current_wait_count INTEGER DEFAULT 0,
    avg_wait_time_seconds INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT TRUE,
    CONSTRAINT chk_priority CHECK (priority >= 1 AND priority <= 10)
);

CREATE TABLE call (
    call_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) REFERENCES member(member_id),
    agent_id VARCHAR(50) REFERENCES agent(agent_id),
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

CREATE INDEX idx_call_member ON call(member_id);
CREATE INDEX idx_call_agent ON call(agent_id);
CREATE INDEX idx_call_start ON call(call_start_time);
CREATE INDEX idx_call_disposition ON call(disposition);

-- Add FK to grievance now that call table exists
ALTER TABLE grievance ADD CONSTRAINT fk_grievance_call FOREIGN KEY (call_id) REFERENCES call(call_id);
CREATE INDEX idx_grievance_call ON grievance(call_id);

CREATE TABLE call_queue_entry (
    entry_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES call(call_id),
    queue_id VARCHAR(50) NOT NULL REFERENCES queue(queue_id),
    entered_queue TIMESTAMP NOT NULL,
    exited_queue TIMESTAMP,
    wait_time_seconds INTEGER,
    exit_reason VARCHAR(50), -- Answered, Abandoned, Transferred
    CONSTRAINT chk_queue_times CHECK (exited_queue IS NULL OR exited_queue >= entered_queue)
);

CREATE INDEX idx_queue_entry_call ON call_queue_entry(call_id);
CREATE INDEX idx_queue_entry_queue ON call_queue_entry(queue_id);

CREATE TABLE call_interaction (
    interaction_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES call(call_id),
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

CREATE INDEX idx_interaction_call ON call_interaction(call_id, sequence_number);
CREATE INDEX idx_interaction_category ON call_interaction(query_category);

CREATE TABLE call_notes (
    note_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES call(call_id),
    agent_id VARCHAR(50) NOT NULL REFERENCES agent(agent_id),
    note_content TEXT NOT NULL,
    note_type VARCHAR(50) NOT NULL, -- General, Follow-up Required, Escalation, Compliance
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notes_call ON call_notes(call_id);
CREATE INDEX idx_notes_agent ON call_notes(agent_id);

CREATE TABLE escalation (
    escalation_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) NOT NULL REFERENCES call(call_id),
    from_agent_id VARCHAR(50) REFERENCES agent(agent_id),
    to_agent_id VARCHAR(50) REFERENCES agent(agent_id),
    escalation_reason TEXT NOT NULL,
    escalation_type VARCHAR(50) NOT NULL, -- Tier 2, Supervisor, Specialist
    escalation_time TIMESTAMP NOT NULL,
    resolution_status VARCHAR(50),
    notes TEXT,
    CONSTRAINT chk_escalation_type CHECK (escalation_type IN ('Tier 2', 'Supervisor', 'Specialist', 'Management'))
);

CREATE INDEX idx_escalation_call ON escalation(call_id);
CREATE INDEX idx_escalation_from ON escalation(from_agent_id);
CREATE INDEX idx_escalation_to ON escalation(to_agent_id);

CREATE TABLE callback_request (
    callback_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    call_id VARCHAR(50) REFERENCES call(call_id),
    requested_time TIMESTAMP NOT NULL,
    scheduled_time TIMESTAMP,
    completed_time TIMESTAMP,
    phone_number VARCHAR(20) NOT NULL,
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    assigned_agent_id VARCHAR(50) REFERENCES agent(agent_id),
    CONSTRAINT chk_callback_status CHECK (status IN ('Pending', 'Scheduled', 'Completed', 'Cancelled'))
);

CREATE INDEX idx_callback_member ON callback_request(member_id);
CREATE INDEX idx_callback_status ON callback_request(status);
CREATE INDEX idx_callback_scheduled ON callback_request(scheduled_time);

CREATE TABLE ivr_session (
    session_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) REFERENCES call(call_id),
    session_start TIMESTAMP NOT NULL,
    session_end TIMESTAMP,
    phone_number VARCHAR(20) NOT NULL,
    menu_path JSONB, -- ["Main Menu", "Claims", "Claims Status"]
    exit_reason VARCHAR(50), -- Completed, Transferred to Agent, Abandoned
    transferred_to_agent BOOLEAN DEFAULT FALSE,
    self_service_completed BOOLEAN DEFAULT FALSE,
    intent_detected VARCHAR(100)
);

CREATE INDEX idx_ivr_call ON ivr_session(call_id);
CREATE INDEX idx_ivr_start ON ivr_session(session_start);

-- ============================================================================
-- MEMBER SERVICES
-- ============================================================================

CREATE TABLE id_card_request (
    request_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member(member_id),
    call_id VARCHAR(50) REFERENCES call(call_id),
    request_date TIMESTAMP NOT NULL,
    delivery_method VARCHAR(20) NOT NULL, -- Email, Mail, Digital Wallet
    delivery_address VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    fulfilled_date TIMESTAMP,
    tracking_number VARCHAR(100),
    CONSTRAINT chk_idcard_delivery CHECK (delivery_method IN ('Email', 'Mail', 'Digital Wallet', 'SMS')),
    CONSTRAINT chk_idcard_status CHECK (status IN ('Pending', 'Processing', 'Sent', 'Delivered', 'Failed'))
);

CREATE INDEX idx_idcard_member ON id_card_request(member_id);
CREATE INDEX idx_idcard_status ON id_card_request(status);

-- ============================================================================
-- AI AUTOMATION & KNOWLEDGE BASE
-- ============================================================================

CREATE TABLE knowledge_base (
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

CREATE INDEX idx_kb_category ON knowledge_base(category, subcategory);
CREATE INDEX idx_kb_active ON knowledge_base(active) WHERE active = TRUE;
CREATE INDEX idx_kb_search ON knowledge_base USING GIN (to_tsvector('english', question || ' ' || answer));

CREATE TABLE ai_automation_log (
    log_id VARCHAR(50) PRIMARY KEY,
    call_id VARCHAR(50) REFERENCES call(call_id),
    interaction_id VARCHAR(50) REFERENCES call_interaction(interaction_id),
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

CREATE INDEX idx_ai_log_call ON ai_automation_log(call_id);
CREATE INDEX idx_ai_log_interaction ON ai_automation_log(interaction_id);
CREATE INDEX idx_ai_log_success ON ai_automation_log(automation_successful);
CREATE INDEX idx_ai_log_created ON ai_automation_log(created_at);

-- ============================================================================
-- AUDIT & COMPLIANCE
-- ============================================================================

CREATE TABLE audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
    changed_by VARCHAR(100) NOT NULL, -- User or System identifier
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    CONSTRAINT chk_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE INDEX idx_audit_table ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_changed_at ON audit_log(changed_at);
CREATE INDEX idx_audit_changed_by ON audit_log(changed_by);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Active member enrollment with current plan details
CREATE VIEW v_active_enrollment AS
SELECT 
    e.enrollment_id,
    e.member_id,
    m.first_name,
    m.last_name,
    m.date_of_birth,
    m.phone_primary,
    e.plan_id,
    p.plan_name,
    p.plan_type,
    e.effective_date,
    e.termination_date,
    e.is_subscriber
FROM enrollment e
JOIN member m ON e.member_id = m.member_id
JOIN plan p ON e.plan_id = p.plan_id
WHERE e.enrollment_status = 'Active'
AND (e.termination_date IS NULL OR e.termination_date >= CURRENT_DATE);

-- Member deductible and OOP status for current year
CREATE VIEW v_member_accumulators AS
SELECT 
    a.member_id,
    m.first_name,
    m.last_name,
    a.calendar_year,
    p.individual_deductible,
    a.individual_deductible_met,
    (p.individual_deductible - a.individual_deductible_met) AS deductible_remaining,
    p.individual_oop_max,
    a.individual_oop_met,
    (p.individual_oop_max - a.individual_oop_met) AS oop_remaining,
    CASE 
        WHEN a.individual_deductible_met >= p.individual_deductible THEN TRUE 
        ELSE FALSE 
    END AS deductible_met,
    CASE 
        WHEN a.individual_oop_met >= p.individual_oop_max THEN TRUE 
        ELSE FALSE 
    END AS oop_max_met
FROM accumulator a
JOIN member m ON a.member_id = m.member_id
JOIN plan p ON a.plan_id = p.plan_id
WHERE a.calendar_year = EXTRACT(YEAR FROM CURRENT_DATE);

-- Call center performance metrics
CREATE VIEW v_call_metrics AS
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
FROM call
WHERE call_end_time IS NOT NULL
GROUP BY DATE(call_start_time), agent_id;

-- AI automation performance
CREATE VIEW v_ai_automation_metrics AS
SELECT 
    DATE(created_at) AS metric_date,
    ai_model_used,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN automation_successful THEN 1 ELSE 0 END) AS successful_automations,
    ROUND(100.0 * SUM(CASE WHEN automation_successful THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate,
    AVG(confidence_score) AS avg_confidence,
    AVG(response_time_ms) AS avg_response_time_ms
FROM ai_automation_log
GROUP BY DATE(created_at), ai_model_used;

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Function to update updated_date timestamp
CREATE OR REPLACE FUNCTION update_updated_date()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_date = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for member table
CREATE TRIGGER trg_member_updated
BEFORE UPDATE ON member
FOR EACH ROW
EXECUTE FUNCTION update_updated_date();

-- Trigger for claim table
CREATE TRIGGER trg_claim_updated
BEFORE UPDATE ON claim
FOR EACH ROW
EXECUTE FUNCTION update_updated_date();

-- Function to calculate call duration
CREATE OR REPLACE FUNCTION calculate_call_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.call_end_time IS NOT NULL THEN
        NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.call_end_time - NEW.call_start_time))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_call_duration
BEFORE INSERT OR UPDATE ON call
FOR EACH ROW
EXECUTE FUNCTION calculate_call_duration();

-- ============================================================================
-- GRANTS & PERMISSIONS (Example - adjust for your security model)
-- ============================================================================

-- Create roles
-- CREATE ROLE call_center_agent;
-- CREATE ROLE call_center_supervisor;
-- CREATE ROLE analytics_user;
-- CREATE ROLE ai_automation_service;

-- Grant appropriate permissions
-- GRANT SELECT, INSERT, UPDATE ON call, call_interaction, call_notes TO call_center_agent;
-- GRANT SELECT ON member, enrollment, plan, claim, provider TO call_center_agent;
-- GRANT ALL ON ALL TABLES IN SCHEMA public TO call_center_supervisor;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO analytics_user;
-- GRANT SELECT, INSERT ON ai_automation_log TO ai_automation_service;

-- ============================================================================
-- SAMPLE DATA INSERTS (Optional - for testing)
-- ============================================================================

-- Insert sample agent
INSERT INTO agent (agent_id, first_name, last_name, email, employee_id, agent_type, hire_date, skills, languages)
VALUES 
('AGT001', 'AI', 'Assistant', 'ai.assistant@healthplan.com', 'AI-001', 'AI', CURRENT_DATE, 
 '["Claims", "Benefits", "Provider Search", "Eligibility"]'::jsonb, 
 '["English", "Spanish", "Mandarin"]'::jsonb);

-- Insert sample knowledge base entries
INSERT INTO knowledge_base (kb_id, category, subcategory, question, answer, active)
VALUES 
('KB001', 'Benefits', 'Deductible', 'What is a deductible?', 
 'A deductible is the amount you pay for covered health care services before your insurance plan starts to pay. For example, if your deductible is $1,000, you pay the first $1,000 of covered services yourself.', 
 TRUE),
('KB002', 'Claims', 'Status', 'How do I check my claim status?',
 'You can check your claim status by calling us, logging into your member portal, or our AI assistant can look it up for you right now if you provide your claim number or date of service.',
 TRUE);

COMMENT ON DATABASE healthplan_callcenter IS 'Health Plan Call Center Database - HIPAA Compliant';
