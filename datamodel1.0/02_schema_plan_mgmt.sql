-- ============================================================================
-- SCHEMA: plan_mgmt
-- Tables: plan, group, enrollment
-- Depends on: member_mgmt
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS plan_mgmt;

CREATE TABLE plan_mgmt.plan (
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

CREATE INDEX idx_plan_active ON plan_mgmt.plan(effective_date, termination_date) WHERE termination_date IS NULL;

CREATE TABLE plan_mgmt.group (
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

CREATE TABLE plan_mgmt.enrollment (
    enrollment_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    plan_id VARCHAR(50) NOT NULL REFERENCES plan_mgmt.plan(plan_id),
    group_id VARCHAR(50) REFERENCES plan_mgmt.group(group_id),
    effective_date DATE NOT NULL,
    termination_date DATE,
    enrollment_status VARCHAR(20) NOT NULL DEFAULT 'Active',
    subscriber_relationship VARCHAR(20) NOT NULL, -- Self, Spouse, Child, Other
    is_subscriber BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_enrollment_status CHECK (enrollment_status IN ('Active', 'Terminated', 'Suspended', 'Pending')),
    CONSTRAINT chk_dates CHECK (termination_date IS NULL OR termination_date >= effective_date)
);

CREATE INDEX idx_enrollment_member ON plan_mgmt.enrollment(member_id);
CREATE INDEX idx_enrollment_plan ON plan_mgmt.enrollment(plan_id);
CREATE INDEX idx_enrollment_active ON plan_mgmt.enrollment(enrollment_status) WHERE enrollment_status = 'Active';

-- ============================================================================
-- VIEW: active enrollment with plan details
-- ============================================================================

CREATE VIEW plan_mgmt.v_active_enrollment AS
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
FROM plan_mgmt.enrollment e
JOIN member_mgmt.member m ON e.member_id = m.member_id
JOIN plan_mgmt.plan p ON e.plan_id = p.plan_id
WHERE e.enrollment_status = 'Active'
AND (e.termination_date IS NULL OR e.termination_date >= CURRENT_DATE);
