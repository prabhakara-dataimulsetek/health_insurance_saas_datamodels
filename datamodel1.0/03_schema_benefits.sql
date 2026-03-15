-- ============================================================================
-- SCHEMA: benefits
-- Tables: benefit_coverage, accumulator
-- Depends on: member_mgmt, plan_mgmt
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS benefits;

CREATE TABLE benefits.benefit_coverage (
    coverage_id VARCHAR(50) PRIMARY KEY,
    plan_id VARCHAR(50) NOT NULL REFERENCES plan_mgmt.plan(plan_id),
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

CREATE INDEX idx_coverage_plan ON benefits.benefit_coverage(plan_id);
CREATE INDEX idx_coverage_service ON benefits.benefit_coverage(service_category);

CREATE TABLE benefits.accumulator (
    accumulator_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    plan_id VARCHAR(50) NOT NULL REFERENCES plan_mgmt.plan(plan_id),
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

CREATE INDEX idx_accumulator_member_year ON benefits.accumulator(member_id, calendar_year);

-- ============================================================================
-- VIEW: member deductible and OOP status for current year
-- ============================================================================

CREATE VIEW benefits.v_member_accumulators AS
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
FROM benefits.accumulator a
JOIN member_mgmt.member m ON a.member_id = m.member_id
JOIN plan_mgmt.plan p ON a.plan_id = p.plan_id
WHERE a.calendar_year = EXTRACT(YEAR FROM CURRENT_DATE);
