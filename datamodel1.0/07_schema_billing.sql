-- ============================================================================
-- SCHEMA: billing
-- Tables: premium, payment
-- Depends on: member_mgmt, plan_mgmt
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS billing;

CREATE TABLE billing.premium (
    premium_id VARCHAR(50) PRIMARY KEY,
    enrollment_id VARCHAR(50) NOT NULL REFERENCES plan_mgmt.enrollment(enrollment_id),
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
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

CREATE INDEX idx_premium_member ON billing.premium(member_id);
CREATE INDEX idx_premium_status ON billing.premium(status);
CREATE INDEX idx_premium_due ON billing.premium(due_date);

CREATE TABLE billing.payment (
    payment_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
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

CREATE INDEX idx_payment_member ON billing.payment(member_id);
CREATE INDEX idx_payment_date ON billing.payment(payment_date);
