-- ============================================================================
-- MASTER INSTALL SCRIPT
-- Health Plan Call Center Database - Multi-Schema
-- Run this file to install all schemas in dependency order
-- ============================================================================

-- Usage:
--   psql -U postgres -d healthplan_callcenter -f 00_install_all.sql

\echo 'Installing schema: member_mgmt...'
\i 01_schema_member.sql

\echo 'Installing schema: plan_mgmt...'
\i 02_schema_plan_mgmt.sql

\echo 'Installing schema: benefits...'
\i 03_schema_benefits.sql

\echo 'Installing schema: provider_network...'
\i 04_schema_provider_network.sql

\echo 'Installing schema: claims...'
\i 05_schema_claims.sql

\echo 'Installing schema: appeals...'
\i 06_schema_appeals.sql

\echo 'Installing schema: billing...'
\i 07_schema_billing.sql

\echo 'Installing schema: callcenter...'
\i 08_schema_callcenter.sql

\echo 'Installing schema: member_services...'
\i 09_schema_member_services.sql

\echo 'Installing schema: ai_automation...'
\i 10_schema_ai_automation.sql

\echo 'Installing schema: audit...'
\i 11_schema_audit.sql

\echo '✅ All schemas installed successfully.'

-- ============================================================================
-- GRANTS (uncomment and adjust for your security model)
-- ============================================================================

-- CREATE ROLE call_center_agent;
-- CREATE ROLE call_center_supervisor;
-- CREATE ROLE analytics_user;
-- CREATE ROLE ai_automation_service;

-- GRANT USAGE ON SCHEMA member_mgmt, plan_mgmt, benefits, claims, callcenter, billing TO call_center_agent;
-- GRANT SELECT ON ALL TABLES IN SCHEMA member_mgmt TO call_center_agent;
-- GRANT SELECT ON ALL TABLES IN SCHEMA plan_mgmt TO call_center_agent;
-- GRANT SELECT ON ALL TABLES IN SCHEMA claims TO call_center_agent;
-- GRANT SELECT ON ALL TABLES IN SCHEMA benefits TO call_center_agent;
-- GRANT SELECT ON ALL TABLES IN SCHEMA provider_network TO call_center_agent;
-- GRANT SELECT, INSERT, UPDATE ON callcenter.call, callcenter.call_interaction, callcenter.call_notes TO call_center_agent;

-- GRANT ALL ON ALL TABLES IN SCHEMA callcenter TO call_center_supervisor;
-- GRANT SELECT ON ALL TABLES IN SCHEMA member_mgmt TO analytics_user;
-- GRANT SELECT ON ALL TABLES IN SCHEMA callcenter TO analytics_user;
-- GRANT SELECT ON ALL TABLES IN SCHEMA ai_automation TO analytics_user;
-- GRANT SELECT, INSERT ON ai_automation.ai_automation_log TO ai_automation_service;

COMMENT ON DATABASE healthplan_callcenter IS 'Health Plan Call Center Database - HIPAA Compliant - Multi-Schema';
