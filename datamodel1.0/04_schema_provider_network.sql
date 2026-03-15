-- ============================================================================
-- SCHEMA: provider_network
-- Tables: provider, provider_location
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS provider_network;

CREATE TABLE provider_network.provider (
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

CREATE INDEX idx_provider_npi ON provider_network.provider(npi);
CREATE INDEX idx_provider_specialty ON provider_network.provider(specialty);
CREATE INDEX idx_provider_network ON provider_network.provider(network_status) WHERE network_status = 'In-Network';

CREATE TABLE provider_network.provider_location (
    location_id VARCHAR(50) PRIMARY KEY,
    provider_id VARCHAR(50) NOT NULL REFERENCES provider_network.provider(provider_id),
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

CREATE INDEX idx_location_provider ON provider_network.provider_location(provider_id);
CREATE INDEX idx_location_zip ON provider_network.provider_location(zip_code);
CREATE INDEX idx_location_geo ON provider_network.provider_location USING GIST (
    ll_to_earth(latitude, longitude)
) WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
