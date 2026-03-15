-- ============================================================================
-- MASTER SAMPLE DATA LOAD SCRIPT
-- Run AFTER 00_install_all.sql (schemas must exist first)
-- Usage: psql -U postgres -d healthplan_callcenter -f 00_load_all_data.sql
-- ============================================================================

\echo 'Loading member_mgmt sample data...'
\i data_01_member.sql

\echo 'Loading plan_mgmt sample data...'
\i data_02_plan_mgmt.sql

\echo 'Loading benefits sample data...'
\i data_03_benefits.sql

\echo 'Loading provider_network sample data...'
\i data_04_provider.sql

\echo 'Loading claims sample data...'
\i data_05_claims.sql

\echo 'Loading appeals sample data...'
\i data_06_appeals.sql

\echo 'Loading billing sample data...'
\i data_07_billing.sql

\echo 'Loading callcenter sample data...'
\i data_08_callcenter.sql

\echo 'Loading member_services sample data...'
\i data_09_member_services.sql

\echo 'Loading ai_automation sample data...'
\i data_10_ai_automation.sql

\echo 'Loading audit sample data...'
\i data_11_audit.sql

\echo '✅ All sample data loaded successfully.'
