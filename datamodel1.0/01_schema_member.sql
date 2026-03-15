-- ============================================================================
-- SCHEMA: member_mgmt
-- Tables: member
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS member_mgmt;

CREATE TABLE member_mgmt.member (
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

CREATE INDEX idx_member_dob ON member_mgmt.member(date_of_birth);
CREATE INDEX idx_member_name ON member_mgmt.member(last_name, first_name);
CREATE INDEX idx_member_phone ON member_mgmt.member(phone_primary);

COMMENT ON TABLE member_mgmt.member IS 'PHI - Protected Health Information. Encrypt at rest.';
COMMENT ON COLUMN member_mgmt.member.ssn_last4 IS 'Last 4 digits only for member identification';

-- Trigger function for updated_date
CREATE OR REPLACE FUNCTION member_mgmt.update_updated_date()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_date = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_member_updated
BEFORE UPDATE ON member_mgmt.member
FOR EACH ROW
EXECUTE FUNCTION member_mgmt.update_updated_date();
