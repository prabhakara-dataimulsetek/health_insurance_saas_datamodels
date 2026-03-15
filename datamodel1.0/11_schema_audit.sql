-- ============================================================================
-- SCHEMA: audit
-- Tables: audit_log
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE audit.audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id VARCHAR(50) NOT NULL,
    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
    changed_by VARCHAR(100) NOT NULL, -- User or System identifier
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    CONSTRAINT chk_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'))
);

CREATE INDEX idx_audit_table ON audit.audit_log(table_name, record_id);
CREATE INDEX idx_audit_changed_at ON audit.audit_log(changed_at);
CREATE INDEX idx_audit_changed_by ON audit.audit_log(changed_by);
