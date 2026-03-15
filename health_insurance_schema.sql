-- =============================================================================
-- Health Insurance SaaS Platform — PostgreSQL Database Schema
-- Compatible with: PostgreSQL 14+  (tested on 16)
-- Entities: Tenant, Member, Dependent, Enrollment, Product, Plan, Benefit,
--           Provider, ProviderLocation, Network, ProviderNetwork,
--           Claim, ClaimLine, Authorization, PremiumBilling
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- 1. TENANT  (SaaS multi-tenant root)
-- =============================================================================
CREATE TABLE tenants (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(200)    NOT NULL,
    subdomain       VARCHAR(100)    NOT NULL UNIQUE,
    plan_tier       VARCHAR(50)     NOT NULL DEFAULT 'starter'
                                    CHECK (plan_tier IN ('starter','pro','enterprise')),
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  tenants           IS 'SaaS tenant — one row per insurance company client';
COMMENT ON COLUMN tenants.plan_tier IS 'starter | pro | enterprise';


-- =============================================================================
-- 2. MEMBER
-- =============================================================================
CREATE TABLE members (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_number   VARCHAR(50)     NOT NULL,
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    date_of_birth   DATE            NOT NULL,
    gender          VARCHAR(10)     CHECK (gender IN ('M','F','X','U')),
    email           VARCHAR(200),
    phone           VARCHAR(20),
    address         TEXT,
    city            VARCHAR(100),
    state           VARCHAR(50),
    zip             VARCHAR(20),
    status          VARCHAR(20)     NOT NULL DEFAULT 'active'
                                    CHECK (status IN ('active','inactive','terminated','pending')),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, member_number)
);

CREATE INDEX idx_members_tenant    ON members(tenant_id);
CREATE INDEX idx_members_status    ON members(status);
CREATE INDEX idx_members_last_name ON members(last_name);

COMMENT ON TABLE members IS 'Core subscriber / patient record';


-- =============================================================================
-- 3. DEPENDENT
-- =============================================================================
CREATE TABLE dependents (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    subscriber_id   UUID            NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    member_id       UUID            NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    relationship    VARCHAR(30)     NOT NULL
                                    CHECK (relationship IN ('spouse','child','domestic_partner','other')),
    effective_date  DATE            NOT NULL,
    end_date        DATE,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dependents_subscriber ON dependents(subscriber_id);
CREATE INDEX idx_dependents_member     ON dependents(member_id);

COMMENT ON TABLE dependents IS 'Family members (spouse, child) linked to a subscriber';


-- =============================================================================
-- 4. PRODUCT
-- =============================================================================
CREATE TABLE products (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_code        VARCHAR(50)     NOT NULL,
    product_name        VARCHAR(200)    NOT NULL,
    product_type        VARCHAR(50)     NOT NULL
                                        CHECK (product_type IN ('HMO','PPO','EPO','POS','HDHP')),
    line_of_business    VARCHAR(50)     NOT NULL
                                        CHECK (line_of_business IN ('commercial','medicare','medicaid','marketplace')),
    market_segment      VARCHAR(50)     CHECK (market_segment IN ('individual','small_group','large_group','government')),
    effective_date      DATE            NOT NULL,
    expiration_date     DATE,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, product_code)
);

CREATE INDEX idx_products_tenant    ON products(tenant_id);
CREATE INDEX idx_products_is_active ON products(is_active);

COMMENT ON TABLE products IS 'Insurance product lines (HMO, PPO, EPO) offered by a tenant';


-- =============================================================================
-- 5. PLAN
-- =============================================================================
CREATE TABLE plans (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id              UUID            NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    plan_code               VARCHAR(50)     NOT NULL,
    plan_name               VARCHAR(200)    NOT NULL,
    metal_tier              VARCHAR(20)     CHECK (metal_tier IN ('bronze','silver','gold','platinum','catastrophic')),
    deductible_individual   NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    deductible_family       NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    oop_max_individual      NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    oop_max_family          NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    premium_amount          NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    network_type            VARCHAR(20)     CHECK (network_type IN ('HMO','PPO','EPO','POS')),
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    effective_date          DATE            NOT NULL,
    expiration_date         DATE,
    created_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, plan_code)
);

CREATE INDEX idx_plans_product    ON plans(product_id);
CREATE INDEX idx_plans_metal_tier ON plans(metal_tier);
CREATE INDEX idx_plans_is_active  ON plans(is_active);

COMMENT ON TABLE plans IS 'Specific plan — deductibles, OOP max, premiums, metal tier';


-- =============================================================================
-- 6. BENEFIT
-- =============================================================================
CREATE TABLE benefits (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id                 UUID            NOT NULL REFERENCES plans(id) ON DELETE CASCADE,
    benefit_category        VARCHAR(100)    NOT NULL,
    benefit_name            VARCHAR(200)    NOT NULL,
    coverage_type           VARCHAR(50)     CHECK (coverage_type IN ('in_network','out_of_network','both')),
    copay_amount            NUMERIC(10,2)   DEFAULT 0.00,
    coinsurance_pct         NUMERIC(5,2)    DEFAULT 0.00
                                            CHECK (coinsurance_pct BETWEEN 0 AND 100),
    prior_auth_required     BOOLEAN         NOT NULL DEFAULT FALSE,
    visit_limit             INTEGER,
    created_at              TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_benefits_plan ON benefits(plan_id);

COMMENT ON TABLE benefits IS 'Coverage rules per plan — copay, coinsurance, prior auth, visit limits';


-- =============================================================================
-- 7. MEMBER_ENROLLMENT
-- =============================================================================
CREATE TABLE member_enrollments (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id           UUID            NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    plan_id             UUID            NOT NULL REFERENCES plans(id),
    subscriber_id       UUID            REFERENCES members(id),
    effective_date      DATE            NOT NULL,
    termination_date    DATE,
    enrollment_status   VARCHAR(20)     NOT NULL DEFAULT 'active'
                                        CHECK (enrollment_status IN ('active','terminated','pending','suspended')),
    relationship_type   VARCHAR(30)     NOT NULL DEFAULT 'subscriber'
                                        CHECK (relationship_type IN ('subscriber','spouse','child','domestic_partner','other')),
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_enrollments_member ON member_enrollments(member_id);
CREATE INDEX idx_enrollments_plan   ON member_enrollments(plan_id);
CREATE INDEX idx_enrollments_status ON member_enrollments(enrollment_status);
CREATE INDEX idx_enrollments_dates  ON member_enrollments(effective_date, termination_date);

COMMENT ON TABLE member_enrollments IS 'Links a member to a specific plan with effective / termination dates';


-- =============================================================================
-- 8. PROVIDER
-- =============================================================================
CREATE TABLE providers (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    npi                 VARCHAR(10)     NOT NULL,
    provider_type       VARCHAR(50)     NOT NULL
                                        CHECK (provider_type IN ('individual','organization')),
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    organization_name   VARCHAR(200),
    specialty           VARCHAR(100),
    email               VARCHAR(200),
    phone               VARCHAR(20),
    tax_id              VARCHAR(20),
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, npi)
);

CREATE INDEX idx_providers_tenant    ON providers(tenant_id);
CREATE INDEX idx_providers_npi       ON providers(npi);
CREATE INDEX idx_providers_specialty ON providers(specialty);
CREATE INDEX idx_providers_active    ON providers(is_active);

COMMENT ON TABLE  providers     IS 'Doctors, hospitals, specialists — identified by NPI';
COMMENT ON COLUMN providers.npi IS 'National Provider Identifier (10 digits)';


-- =============================================================================
-- 9. PROVIDER_LOCATION
-- =============================================================================
CREATE TABLE provider_locations (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id         UUID            NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    address             TEXT            NOT NULL,
    city                VARCHAR(100),
    state               VARCHAR(50),
    zip                 VARCHAR(20),
    latitude            DOUBLE PRECISION,
    longitude           DOUBLE PRECISION,
    accepting_patients  BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_prov_loc_provider ON provider_locations(provider_id);

COMMENT ON TABLE provider_locations IS 'Multiple practice locations per provider with geo-coordinates';


-- =============================================================================
-- 10. NETWORK
-- =============================================================================
CREATE TABLE networks (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id           UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    network_name        VARCHAR(200)    NOT NULL,
    network_code        VARCHAR(50)     NOT NULL,
    network_type        VARCHAR(50)     CHECK (network_type IN ('HMO','PPO','EPO','POS','narrow','broad')),
    effective_date      DATE            NOT NULL,
    expiration_date     DATE,
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, network_code)
);

CREATE INDEX idx_networks_tenant ON networks(tenant_id);

COMMENT ON TABLE networks IS 'In-network / out-of-network provider groups';


-- =============================================================================
-- 11. PROVIDER_NETWORK  (junction)
-- =============================================================================
CREATE TABLE provider_networks (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id             UUID            NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
    network_id              UUID            NOT NULL REFERENCES networks(id) ON DELETE CASCADE,
    tier                    VARCHAR(20)     CHECK (tier IN ('tier1','tier2','tier3','out_of_network')),
    effective_date          DATE            NOT NULL,
    termination_date        DATE,
    participation_status    VARCHAR(20)     NOT NULL DEFAULT 'active'
                                            CHECK (participation_status IN ('active','terminated','pending','suspended')),
    created_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (provider_id, network_id)
);

CREATE INDEX idx_prov_net_provider ON provider_networks(provider_id);
CREATE INDEX idx_prov_net_network  ON provider_networks(network_id);

COMMENT ON TABLE provider_networks IS 'Many-to-many: providers <-> networks with tier';


-- =============================================================================
-- 12. CLAIM
-- =============================================================================
CREATE TABLE claims (
    id                      UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id               UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id               UUID            NOT NULL REFERENCES members(id),
    provider_id             UUID            NOT NULL REFERENCES providers(id),
    plan_id                 UUID            NOT NULL REFERENCES plans(id),
    claim_number            VARCHAR(50)     NOT NULL,
    claim_type              VARCHAR(20)     NOT NULL
                                            CHECK (claim_type IN ('medical','dental','vision','pharmacy','behavioral')),
    service_date            DATE            NOT NULL,
    received_date           DATE            NOT NULL DEFAULT CURRENT_DATE,
    billed_amount           NUMERIC(12,2)   NOT NULL DEFAULT 0.00,
    allowed_amount          NUMERIC(12,2)   DEFAULT 0.00,
    paid_amount             NUMERIC(12,2)   DEFAULT 0.00,
    member_responsibility   NUMERIC(12,2)   DEFAULT 0.00,
    claim_status            VARCHAR(20)     NOT NULL DEFAULT 'received'
                                            CHECK (claim_status IN ('received','processing','approved','denied','paid','appealed','void')),
    created_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, claim_number)
);

CREATE INDEX idx_claims_tenant     ON claims(tenant_id);
CREATE INDEX idx_claims_member     ON claims(member_id);
CREATE INDEX idx_claims_provider   ON claims(provider_id);
CREATE INDEX idx_claims_plan       ON claims(plan_id);
CREATE INDEX idx_claims_status     ON claims(claim_status);
CREATE INDEX idx_claims_service_dt ON claims(service_date);

COMMENT ON TABLE claims IS 'Medical claim submission — billed, allowed, paid amounts';


-- =============================================================================
-- 13. CLAIM_LINE
-- =============================================================================
CREATE TABLE claim_lines (
    id                  UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    claim_id            UUID            NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
    line_number         SMALLINT        NOT NULL DEFAULT 1,
    procedure_code      VARCHAR(20)     NOT NULL,
    diagnosis_code      VARCHAR(20),
    quantity            INTEGER         NOT NULL DEFAULT 1,
    billed_amount       NUMERIC(12,2)   NOT NULL DEFAULT 0.00,
    allowed_amount      NUMERIC(12,2)   DEFAULT 0.00,
    paid_amount         NUMERIC(12,2)   DEFAULT 0.00,
    service_description TEXT,
    created_at          TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (claim_id, line_number)
);

CREATE INDEX idx_claim_lines_claim ON claim_lines(claim_id);

COMMENT ON TABLE  claim_lines                IS 'Line-level claim detail — CPT procedure codes, ICD-10 diagnosis codes';
COMMENT ON COLUMN claim_lines.procedure_code IS 'CPT code';
COMMENT ON COLUMN claim_lines.diagnosis_code IS 'ICD-10 code';


-- =============================================================================
-- 14. AUTHORIZATION
-- =============================================================================
CREATE TABLE authorizations (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id       UUID            NOT NULL REFERENCES members(id),
    provider_id     UUID            NOT NULL REFERENCES providers(id),
    plan_id         UUID            NOT NULL REFERENCES plans(id),
    auth_number     VARCHAR(50)     NOT NULL,
    service_type    VARCHAR(100)    NOT NULL,
    procedure_code  VARCHAR(20),
    start_date      DATE            NOT NULL,
    end_date        DATE,
    approved_units  INTEGER         DEFAULT 1,
    status          VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                    CHECK (status IN ('pending','approved','denied','expired','cancelled')),
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, auth_number)
);

CREATE INDEX idx_auth_member   ON authorizations(member_id);
CREATE INDEX idx_auth_provider ON authorizations(provider_id);
CREATE INDEX idx_auth_status   ON authorizations(status);
CREATE INDEX idx_auth_dates    ON authorizations(start_date, end_date);

COMMENT ON TABLE authorizations IS 'Prior authorization requests for procedures or services';


-- =============================================================================
-- 15. PREMIUM_BILLING
-- =============================================================================
CREATE TABLE premium_billings (
    id              UUID            PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id       UUID            NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    member_id       UUID            NOT NULL REFERENCES members(id),
    plan_id         UUID            NOT NULL REFERENCES plans(id),
    invoice_number  VARCHAR(50)     NOT NULL,
    billing_date    DATE            NOT NULL,
    due_date        DATE            NOT NULL,
    amount_due      NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    amount_paid     NUMERIC(10,2)   NOT NULL DEFAULT 0.00,
    payment_status  VARCHAR(20)     NOT NULL DEFAULT 'pending'
                                    CHECK (payment_status IN ('pending','paid','partial','overdue','waived','refunded')),
    payment_method  VARCHAR(30)     CHECK (payment_method IN ('ach','credit_card','check','wire','payroll_deduction')),
    payment_date    DATE,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    UNIQUE (tenant_id, invoice_number)
);

CREATE INDEX idx_billing_member ON premium_billings(member_id);
CREATE INDEX idx_billing_plan   ON premium_billings(plan_id);
CREATE INDEX idx_billing_status ON premium_billings(payment_status);
CREATE INDEX idx_billing_dates  ON premium_billings(billing_date, due_date);

COMMENT ON TABLE premium_billings IS 'Monthly premium invoicing and payment tracking per member / plan';


-- =============================================================================
-- AUTO-UPDATE updated_at TRIGGER
-- =============================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tenants_updated_at
    BEFORE UPDATE ON tenants
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_members_updated_at
    BEFORE UPDATE ON members
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_plans_updated_at
    BEFORE UPDATE ON plans
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_enrollments_updated_at
    BEFORE UPDATE ON member_enrollments
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_providers_updated_at
    BEFORE UPDATE ON providers
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_claims_updated_at
    BEFORE UPDATE ON claims
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_authorizations_updated_at
    BEFORE UPDATE ON authorizations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_billings_updated_at
    BEFORE UPDATE ON premium_billings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- =============================================================================
-- SAMPLE SEED DATA
-- =============================================================================

-- Tenant
INSERT INTO tenants (id, name, subdomain, plan_tier) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'BlueCross HealthCare', 'bluecross', 'enterprise');

-- Product
INSERT INTO products (id, tenant_id, product_code, product_name, product_type, line_of_business, market_segment, effective_date) VALUES
    ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
     'PPO-2024', 'BlueCross PPO 2024', 'PPO', 'commercial', 'large_group', '2024-01-01');

-- Plan
INSERT INTO plans (id, product_id, plan_code, plan_name, metal_tier, deductible_individual, deductible_family, oop_max_individual, oop_max_family, premium_amount, network_type, effective_date) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
     'PPO-GOLD-2024', 'BlueCross Gold PPO 2024', 'gold',
     1500.00, 3000.00, 5000.00, 10000.00, 450.00, 'PPO', '2024-01-01');

-- Benefits
INSERT INTO benefits (plan_id, benefit_category, benefit_name, coverage_type, copay_amount, coinsurance_pct, prior_auth_required) VALUES
    ('c0000000-0000-0000-0000-000000000001', 'Primary Care',  'PCP Office Visit',        'in_network', 25.00,  0.00,  FALSE),
    ('c0000000-0000-0000-0000-000000000001', 'Specialist',    'Specialist Office Visit', 'in_network', 50.00,  0.00,  FALSE),
    ('c0000000-0000-0000-0000-000000000001', 'Emergency',     'Emergency Room',          'both',       250.00, 0.00,  FALSE),
    ('c0000000-0000-0000-0000-000000000001', 'Inpatient',     'Hospital Inpatient',      'in_network', 0.00,   20.00, TRUE),
    ('c0000000-0000-0000-0000-000000000001', 'Mental Health', 'Outpatient Therapy',      'in_network', 25.00,  0.00,  FALSE),
    ('c0000000-0000-0000-0000-000000000001', 'Pharmacy',      'Generic Drug Tier 1',     'in_network', 10.00,  0.00,  FALSE);

-- Member
INSERT INTO members (id, tenant_id, member_number, first_name, last_name, date_of_birth, gender, email, phone, address, city, state, zip, status) VALUES
    ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
     'MBR-000001', 'John', 'Smith', '1985-06-15', 'M',
     'john.smith@email.com', '555-100-2000', '123 Main Street', 'Los Angeles', 'CA', '90001', 'active');

-- Member Enrollment
INSERT INTO member_enrollments (tenant_id, member_id, plan_id, effective_date, enrollment_status, relationship_type) VALUES
    ('a0000000-0000-0000-0000-000000000001',
     'd0000000-0000-0000-0000-000000000001',
     'c0000000-0000-0000-0000-000000000001',
     '2024-01-01', 'active', 'subscriber');

-- Network
INSERT INTO networks (id, tenant_id, network_name, network_code, network_type, effective_date) VALUES
    ('e0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
     'BlueCross Preferred Network', 'BC-PREF-2024', 'PPO', '2024-01-01');

-- Provider
INSERT INTO providers (id, tenant_id, npi, provider_type, first_name, last_name, specialty, email, phone, tax_id) VALUES
    ('f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
     '1234567890', 'individual', 'Sarah', 'Johnson', 'Internal Medicine',
     'dr.johnson@clinic.com', '555-200-3000', '12-3456789');

-- Provider Location
INSERT INTO provider_locations (provider_id, address, city, state, zip, latitude, longitude, accepting_patients) VALUES
    ('f0000000-0000-0000-0000-000000000001',
     '456 Medical Plaza, Suite 200', 'Los Angeles', 'CA', '90010',
     34.0522, -118.2437, TRUE);

-- Provider Network
INSERT INTO provider_networks (provider_id, network_id, tier, effective_date, participation_status) VALUES
    ('f0000000-0000-0000-0000-000000000001',
     'e0000000-0000-0000-0000-000000000001',
     'tier1', '2024-01-01', 'active');

-- Claim
INSERT INTO claims (id, tenant_id, member_id, provider_id, plan_id, claim_number, claim_type, service_date, received_date, billed_amount, allowed_amount, paid_amount, member_responsibility, claim_status) VALUES
    ('g0000000-0000-0000-0000-000000000001',
     'a0000000-0000-0000-0000-000000000001',
     'd0000000-0000-0000-0000-000000000001',
     'f0000000-0000-0000-0000-000000000001',
     'c0000000-0000-0000-0000-000000000001',
     'CLM-2024-000001', 'medical',
     '2024-03-10', '2024-03-12',
     350.00, 280.00, 255.00, 25.00, 'paid');

-- Claim Line
INSERT INTO claim_lines (claim_id, line_number, procedure_code, diagnosis_code, quantity, billed_amount, allowed_amount, paid_amount, service_description) VALUES
    ('g0000000-0000-0000-0000-000000000001',
     1, '99213', 'Z00.00', 1,
     350.00, 280.00, 255.00,
     'Office visit — established patient, moderate complexity');

-- Premium Billing
INSERT INTO premium_billings (tenant_id, member_id, plan_id, invoice_number, billing_date, due_date, amount_due, amount_paid, payment_status, payment_method, payment_date) VALUES
    ('a0000000-0000-0000-0000-000000000001',
     'd0000000-0000-0000-0000-000000000001',
     'c0000000-0000-0000-0000-000000000001',
     'INV-2024-03-000001',
     '2024-03-01', '2024-03-15',
     450.00, 450.00, 'paid', 'ach', '2024-03-10');


-- =============================================================================
-- USEFUL VIEWS
-- =============================================================================

-- Active member enrollments with plan details
CREATE OR REPLACE VIEW v_active_enrollments AS
SELECT
    m.tenant_id,
    m.member_number,
    m.first_name || ' ' || m.last_name  AS member_name,
    m.date_of_birth,
    m.status                             AS member_status,
    pl.plan_name,
    pl.metal_tier,
    pl.premium_amount,
    me.effective_date,
    me.termination_date,
    me.relationship_type
FROM member_enrollments me
JOIN members m  ON m.id  = me.member_id
JOIN plans   pl ON pl.id = me.plan_id
WHERE me.enrollment_status = 'active';

-- Claim summary with member and provider info
CREATE OR REPLACE VIEW v_claim_summary AS
SELECT
    c.tenant_id,
    c.claim_number,
    c.claim_type,
    c.service_date,
    c.claim_status,
    m.first_name || ' ' || m.last_name                                  AS member_name,
    m.member_number,
    COALESCE(p.first_name || ' ' || p.last_name, p.organization_name)   AS provider_name,
    p.npi,
    pl.plan_name,
    c.billed_amount,
    c.allowed_amount,
    c.paid_amount,
    c.member_responsibility
FROM claims c
JOIN members   m  ON m.id  = c.member_id
JOIN providers p  ON p.id  = c.provider_id
JOIN plans     pl ON pl.id = c.plan_id;

-- Provider directory with network participation
CREATE OR REPLACE VIEW v_provider_directory AS
SELECT
    p.tenant_id,
    p.npi,
    COALESCE(p.first_name || ' ' || p.last_name, p.organization_name) AS provider_name,
    p.provider_type,
    p.specialty,
    p.phone,
    n.network_name,
    pn.tier,
    pn.participation_status,
    pl.city,
    pl.state,
    pl.accepting_patients
FROM providers p
LEFT JOIN provider_networks  pn ON pn.provider_id = p.id
LEFT JOIN networks           n  ON n.id            = pn.network_id
LEFT JOIN provider_locations pl ON pl.provider_id  = p.id
WHERE p.is_active = TRUE;


-- =============================================================================
-- HOW TO RUN THIS SCRIPT
-- =============================================================================
-- psql -U postgres -d your_database -f health_insurance_schema.sql
--
-- Or from inside psql:
-- \i /path/to/health_insurance_schema.sql
-- =============================================================================
