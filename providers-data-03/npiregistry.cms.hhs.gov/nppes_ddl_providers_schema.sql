-- ============================================================
-- NPPES NPI Data Model - SQL DDL
-- Schema: providers
-- Source files: npidata_pfile, pl_pfile, othername_pfile,
--               endpoint_pfile
-- Generated: 2026-03-21
-- ============================================================

-- ============================================================
-- CREATE SCHEMA
-- ============================================================
CREATE SCHEMA IF NOT EXISTS providers;

-- Set search_path so unqualified references resolve to providers.
-- (Optional — all objects below are fully qualified)
-- SET search_path TO providers, public;

-- ============================================================
-- CORE PROVIDER TABLE
-- Source: npidata_pfile
-- ============================================================
CREATE TABLE providers.provider (
    npi                          CHAR(10)     NOT NULL,
    entity_type_code             SMALLINT     NOT NULL,        -- 1=Individual, 2=Organization
    replacement_npi              CHAR(10)     NULL,
    ein                          VARCHAR(9)   NULL,            -- Employer Identification Number
    org_name                     VARCHAR(300) NULL,            -- Provider Organization Name (Legal Business Name)
    last_name                    VARCHAR(100) NULL,            -- Provider Last Name (Legal Name)
    first_name                   VARCHAR(100) NULL,
    middle_name                  VARCHAR(100) NULL,
    name_prefix                  VARCHAR(10)  NULL,
    name_suffix                  VARCHAR(10)  NULL,
    credential                   VARCHAR(50)  NULL,
    other_org_name               VARCHAR(300) NULL,
    other_org_name_type_code     VARCHAR(10)  NULL,
    other_last_name              VARCHAR(100) NULL,
    other_first_name             VARCHAR(100) NULL,
    other_middle_name            VARCHAR(100) NULL,
    other_name_prefix            VARCHAR(10)  NULL,
    other_name_suffix            VARCHAR(10)  NULL,
    other_credential             VARCHAR(50)  NULL,
    other_last_name_type_code    VARCHAR(10)  NULL,
    sex_code                     CHAR(1)      NULL,            -- M=Male, F=Female
    enumeration_date             DATE         NULL,
    last_update_date             DATE         NULL,
    deactivation_reason_code     VARCHAR(10)  NULL,
    deactivation_date            DATE         NULL,
    reactivation_date            DATE         NULL,
    is_sole_proprietor           CHAR(1)      NULL,            -- X=Yes, blank=No
    is_org_subpart               CHAR(1)      NULL,            -- X=Yes, blank=No
    parent_org_lbn               VARCHAR(300) NULL,
    parent_org_tin               VARCHAR(9)   NULL,
    certification_date           DATE         NULL,
    CONSTRAINT pk_provider PRIMARY KEY (npi)
);

-- ============================================================
-- MAILING ADDRESS
-- Source: npidata_pfile (embedded columns)
-- ============================================================
CREATE TABLE providers.mailing_address (
    npi              CHAR(10)     NOT NULL,
    address_line_1   VARCHAR(200) NULL,
    address_line_2   VARCHAR(200) NULL,
    city             VARCHAR(200) NULL,
    state            VARCHAR(40)  NULL,
    postal_code      VARCHAR(20)  NULL,
    country_code     CHAR(2)      NULL,
    phone            VARCHAR(20)  NULL,
    fax              VARCHAR(20)  NULL,
    CONSTRAINT pk_mailing_address PRIMARY KEY (npi),
    CONSTRAINT fk_mailing_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi)
);

-- ============================================================
-- PRIMARY PRACTICE LOCATION ADDRESS
-- Source: npidata_pfile (embedded columns)
-- ============================================================
CREATE TABLE providers.practice_location (
    npi              CHAR(10)     NOT NULL,
    address_line_1   VARCHAR(200) NULL,
    address_line_2   VARCHAR(200) NULL,
    city             VARCHAR(200) NULL,
    state            VARCHAR(40)  NULL,
    postal_code      VARCHAR(20)  NULL,
    country_code     CHAR(2)      NULL,
    phone            VARCHAR(20)  NULL,
    fax              VARCHAR(20)  NULL,
    CONSTRAINT pk_practice_location PRIMARY KEY (npi),
    CONSTRAINT fk_practice_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi)
);

-- ============================================================
-- SECONDARY PRACTICE LOCATIONS
-- Source: pl_pfile
-- ============================================================
CREATE TABLE providers.secondary_practice_location (
    id               SERIAL       NOT NULL,
    npi              CHAR(10)     NOT NULL,
    address_line_1   VARCHAR(200) NULL,
    address_line_2   VARCHAR(200) NULL,
    city             VARCHAR(200) NULL,
    state            VARCHAR(40)  NULL,
    postal_code      VARCHAR(20)  NULL,
    country_code     CHAR(2)      NULL,
    phone            VARCHAR(20)  NULL,
    phone_ext        VARCHAR(10)  NULL,
    fax              VARCHAR(20)  NULL,
    CONSTRAINT pk_secondary_location PRIMARY KEY (id),
    CONSTRAINT fk_secondary_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi)
);

CREATE INDEX idx_secondary_location_npi
    ON providers.secondary_practice_location (npi);

-- ============================================================
-- PROVIDER TAXONOMIES
-- Source: npidata_pfile (columns _1 through _15, normalized)
-- ============================================================
CREATE TABLE providers.taxonomy (
    id                    SERIAL       NOT NULL,
    npi                   CHAR(10)     NOT NULL,
    slot                  SMALLINT     NOT NULL,  -- 1 to 15
    taxonomy_code         VARCHAR(10)  NULL,
    license_number        VARCHAR(20)  NULL,
    license_state         CHAR(2)      NULL,
    primary_switch        CHAR(1)      NULL,      -- Y=Primary taxonomy
    taxonomy_group        VARCHAR(10)  NULL,
    CONSTRAINT pk_taxonomy        PRIMARY KEY (id),
    CONSTRAINT fk_taxonomy_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi),
    CONSTRAINT uq_taxonomy_slot   UNIQUE (npi, slot)
);

CREATE INDEX idx_taxonomy_npi  ON providers.taxonomy (npi);
CREATE INDEX idx_taxonomy_code ON providers.taxonomy (taxonomy_code);

-- ============================================================
-- OTHER PROVIDER IDENTIFIERS
-- Source: npidata_pfile (columns _1 through _50, normalized)
-- ============================================================
CREATE TABLE providers.other_identifier (
    id               SERIAL       NOT NULL,
    npi              CHAR(10)     NOT NULL,
    slot             SMALLINT     NOT NULL,   -- 1 to 50
    identifier       VARCHAR(20)  NULL,
    type_code        VARCHAR(10)  NULL,
    state            CHAR(2)      NULL,
    issuer           VARCHAR(80)  NULL,
    CONSTRAINT pk_other_identifier PRIMARY KEY (id),
    CONSTRAINT fk_other_id_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi),
    CONSTRAINT uq_other_id_slot   UNIQUE (npi, slot)
);

CREATE INDEX idx_other_identifier_npi ON providers.other_identifier (npi);

-- ============================================================
-- OTHER ORGANIZATION NAMES
-- Source: othername_pfile
-- ============================================================
CREATE TABLE providers.other_name (
    id                    SERIAL       NOT NULL,
    npi                   CHAR(10)     NOT NULL,
    other_org_name        VARCHAR(300) NULL,
    name_type_code        VARCHAR(10)  NULL,
    CONSTRAINT pk_other_name PRIMARY KEY (id),
    CONSTRAINT fk_other_name_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi)
);

CREATE INDEX idx_other_name_npi ON providers.other_name (npi);

-- ============================================================
-- AUTHORIZED OFFICIAL
-- Source: npidata_pfile (entity type 2 / organizations only)
-- ============================================================
CREATE TABLE providers.authorized_official (
    npi                  CHAR(10)     NOT NULL,
    last_name            VARCHAR(100) NULL,
    first_name           VARCHAR(100) NULL,
    middle_name          VARCHAR(100) NULL,
    title_or_position    VARCHAR(200) NULL,
    phone                VARCHAR(20)  NULL,
    name_prefix          VARCHAR(10)  NULL,
    name_suffix          VARCHAR(10)  NULL,
    credential           VARCHAR(50)  NULL,
    CONSTRAINT pk_authorized_official PRIMARY KEY (npi),
    CONSTRAINT fk_auth_official_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi)
);

-- ============================================================
-- ENDPOINTS
-- Source: endpoint_pfile
-- ============================================================
CREATE TABLE providers.endpoint (
    id                              SERIAL        NOT NULL,
    npi                             CHAR(10)      NOT NULL,
    endpoint_type                   VARCHAR(20)   NULL,
    endpoint_type_description       VARCHAR(200)  NULL,
    endpoint                        VARCHAR(1000) NULL,
    affiliation                     VARCHAR(10)   NULL,
    endpoint_description            VARCHAR(500)  NULL,
    affiliation_legal_business_name VARCHAR(300)  NULL,
    use_code                        VARCHAR(20)   NULL,
    use_description                 VARCHAR(200)  NULL,
    other_use_description           VARCHAR(200)  NULL,
    content_type                    VARCHAR(20)   NULL,
    content_description             VARCHAR(200)  NULL,
    other_content_description       VARCHAR(200)  NULL,
    affiliation_address_line_1      VARCHAR(200)  NULL,
    affiliation_address_line_2      VARCHAR(200)  NULL,
    affiliation_city                VARCHAR(200)  NULL,
    affiliation_state               VARCHAR(40)   NULL,
    affiliation_country             CHAR(2)       NULL,
    affiliation_postal_code         VARCHAR(20)   NULL,
    CONSTRAINT pk_endpoint PRIMARY KEY (id),
    CONSTRAINT fk_endpoint_provider
        FOREIGN KEY (npi) REFERENCES providers.provider (npi)
);

CREATE INDEX idx_endpoint_npi  ON providers.endpoint (npi);
CREATE INDEX idx_endpoint_type ON providers.endpoint (endpoint_type);

-- ============================================================
-- VIEWS
-- ============================================================

-- Individual providers with primary practice location
CREATE VIEW providers.v_individual_provider AS
SELECT
    p.npi,
    p.last_name,
    p.first_name,
    p.middle_name,
    p.credential,
    p.sex_code,
    p.enumeration_date,
    p.last_update_date,
    p.deactivation_date,
    pl.address_line_1,
    pl.city,
    pl.state,
    pl.postal_code,
    pl.phone
FROM providers.provider p
LEFT JOIN providers.practice_location pl ON p.npi = pl.npi
WHERE p.entity_type_code = 1;

-- Organization providers
CREATE VIEW providers.v_organization_provider AS
SELECT
    p.npi,
    p.org_name,
    p.ein,
    p.is_sole_proprietor,
    p.is_org_subpart,
    p.parent_org_lbn,
    p.enumeration_date,
    p.last_update_date,
    pl.address_line_1,
    pl.city,
    pl.state,
    pl.postal_code,
    pl.phone,
    ao.last_name        AS auth_official_last_name,
    ao.first_name       AS auth_official_first_name,
    ao.title_or_position
FROM providers.provider p
LEFT JOIN providers.practice_location    pl ON p.npi = pl.npi
LEFT JOIN providers.authorized_official  ao ON p.npi = ao.npi
WHERE p.entity_type_code = 2;

-- Providers with primary taxonomy
CREATE VIEW providers.v_provider_primary_taxonomy AS
SELECT
    p.npi,
    COALESCE(p.org_name, p.last_name || ', ' || p.first_name) AS provider_name,
    p.entity_type_code,
    t.taxonomy_code,
    t.license_number,
    t.license_state
FROM providers.provider p
LEFT JOIN providers.taxonomy t ON p.npi = t.npi AND t.primary_switch = 'Y';

-- ============================================================
-- GRANT USAGE (uncomment and adjust role names as needed)
-- ============================================================
-- GRANT USAGE  ON SCHEMA providers TO your_app_role;
-- GRANT SELECT ON ALL TABLES IN SCHEMA providers TO your_readonly_role;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA providers TO your_app_role;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA providers TO your_app_role;
