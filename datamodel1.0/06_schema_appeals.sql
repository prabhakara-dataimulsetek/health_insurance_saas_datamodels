-- ============================================================================
-- SCHEMA: appeals
-- Tables: appeal, grievance
-- Depends on: member_mgmt, claims
-- Note: grievance.call_id FK to callcenter.call is added in 07_schema_callcenter.sql
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS appeals;

CREATE TABLE appeals.appeal (
    appeal_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    claim_id VARCHAR(50) REFERENCES claims.claim(claim_id),
    auth_id VARCHAR(50) REFERENCES claims.prior_authorization(auth_id),
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

CREATE INDEX idx_appeal_member ON appeals.appeal(member_id);
CREATE INDEX idx_appeal_claim ON appeals.appeal(claim_id);
CREATE INDEX idx_appeal_status ON appeals.appeal(status);

CREATE TABLE appeals.grievance (
    grievance_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    call_id VARCHAR(50), -- FK to callcenter.call added later in 07_schema_callcenter.sql
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

CREATE INDEX idx_grievance_member ON appeals.grievance(member_id);
CREATE INDEX idx_grievance_status ON appeals.grievance(status);
