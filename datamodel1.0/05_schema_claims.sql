-- ============================================================================
-- SCHEMA: claims
-- Tables: claim, prior_authorization, referral
-- Depends on: member_mgmt, provider_network
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS claims;

CREATE TABLE claims.claim (
    claim_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    provider_id VARCHAR(50) REFERENCES provider_network.provider(provider_id),
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

CREATE INDEX idx_claim_member ON claims.claim(member_id);
CREATE INDEX idx_claim_provider ON claims.claim(provider_id);
CREATE INDEX idx_claim_status ON claims.claim(claim_status);
CREATE INDEX idx_claim_dos ON claims.claim(date_of_service);

-- Trigger for updated_date on claim
CREATE OR REPLACE FUNCTION claims.update_claim_updated_date()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_date = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_claim_updated
BEFORE UPDATE ON claims.claim
FOR EACH ROW
EXECUTE FUNCTION claims.update_claim_updated_date();

CREATE TABLE claims.prior_authorization (
    auth_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    provider_id VARCHAR(50) REFERENCES provider_network.provider(provider_id),
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

CREATE INDEX idx_pa_member ON claims.prior_authorization(member_id);
CREATE INDEX idx_pa_status ON claims.prior_authorization(status);
CREATE INDEX idx_pa_valid ON claims.prior_authorization(valid_from, valid_through);

CREATE TABLE claims.referral (
    referral_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    from_provider_id VARCHAR(50) REFERENCES provider_network.provider(provider_id),
    to_provider_id VARCHAR(50) REFERENCES provider_network.provider(provider_id),
    specialty_needed VARCHAR(100) NOT NULL,
    referral_date DATE NOT NULL,
    expiration_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'Active',
    visits_authorized INTEGER,
    visits_used INTEGER DEFAULT 0,
    CONSTRAINT chk_referral_status CHECK (status IN ('Active', 'Expired', 'Completed', 'Cancelled')),
    CONSTRAINT chk_referral_visits CHECK (visits_used IS NULL OR visits_authorized IS NULL OR visits_used <= visits_authorized)
);

CREATE INDEX idx_referral_member ON claims.referral(member_id);
CREATE INDEX idx_referral_to_provider ON claims.referral(to_provider_id);
