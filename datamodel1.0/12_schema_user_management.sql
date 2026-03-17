-- ============================================================================
-- SCHEMA: user_mgmt
-- Tables: roles, permissions, role_permissions, users, sessions, login_history, 
--         audit_logs, password_reset_tokens
-- ============================================================================
-- Health Insurance System - User Management Data Model (v2.0 Enhanced)
-- ============================================================================
-- Complete user, role, permission, and audit trail management
-- Features: RBAC, MFA support, session tracking, audit logging, password reset
-- ============================================================================

-- Create schema for user management
CREATE SCHEMA IF NOT EXISTS user_mgmt;

-- ============================================================================
-- 1. ROLES TABLE - Define available roles in the system
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    permission_level INT NOT NULL DEFAULT 0 CHECK (permission_level BETWEEN 0 AND 3),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on role_name
CREATE INDEX IF NOT EXISTS idx_roles_name ON user_mgmt.roles(role_name);
CREATE INDEX IF NOT EXISTS idx_roles_active ON user_mgmt.roles(is_active);

-- Insert default roles
INSERT INTO user_mgmt.roles (role_name, description, permission_level, is_active) VALUES
    ('admin', 'System administrator with full access', 3, TRUE),
    ('supervisor', 'Supervisor with limited management access', 2, TRUE),
    ('agent', 'Call center agent with standard access', 1, TRUE),
    ('viewer', 'Read-only viewer with minimal access', 0, TRUE)
ON CONFLICT (role_name) DO NOTHING;

-- ============================================================================
-- 2. PERMISSIONS TABLE - Define granular permissions
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.permissions (
    permission_id SERIAL PRIMARY KEY,
    permission_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    resource VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    permission_level INT NOT NULL DEFAULT 0 CHECK (permission_level BETWEEN 0 AND 3),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_permissions_name ON user_mgmt.permissions(permission_name);
CREATE INDEX IF NOT EXISTS idx_permissions_resource ON user_mgmt.permissions(resource);
CREATE INDEX IF NOT EXISTS idx_permissions_active ON user_mgmt.permissions(is_active);

-- Insert default permissions (14 core permissions)
INSERT INTO user_mgmt.permissions (permission_name, description, resource, action, permission_level) VALUES
    ('view_members', 'View member information', 'members', 'read', 0),
    ('edit_members', 'Edit member information', 'members', 'write', 1),
    ('delete_members', 'Delete member records', 'members', 'delete', 2),
    ('view_claims', 'View claim information', 'claims', 'read', 0),
    ('edit_claims', 'Edit claim information', 'claims', 'write', 1),
    ('delete_claims', 'Delete claim records', 'claims', 'delete', 2),
    ('view_providers', 'View provider information', 'providers', 'read', 0),
    ('edit_providers', 'Edit provider information', 'providers', 'write', 1),
    ('view_users', 'View user accounts', 'users', 'read', 1),
    ('manage_users', 'Create/edit/delete users', 'users', 'write', 2),
    ('manage_roles', 'Create/edit/delete roles', 'roles', 'write', 3),
    ('view_audit', 'View audit logs', 'audit', 'read', 2),
    ('view_reports', 'View system reports', 'reports', 'read', 0),
    ('export_data', 'Export data', 'data', 'export', 1)
ON CONFLICT (permission_name) DO NOTHING;

-- ============================================================================
-- 3. ROLE_PERMISSIONS JUNCTION TABLE - Map roles to permissions
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.role_permissions (
    role_permission_id SERIAL PRIMARY KEY,
    role_id INT NOT NULL REFERENCES user_mgmt.roles(role_id) ON DELETE CASCADE,
    permission_id INT NOT NULL REFERENCES user_mgmt.permissions(permission_id) ON DELETE CASCADE,
    granted_by INT REFERENCES user_mgmt.users(user_id),
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP,
    CONSTRAINT unique_role_permission UNIQUE(role_id, permission_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON user_mgmt.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_perm ON user_mgmt.role_permissions(permission_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_active ON user_mgmt.role_permissions(revoked_at);

-- Assign permissions to roles
-- ADMIN - Full access to everything
INSERT INTO user_mgmt.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM user_mgmt.roles r, user_mgmt.permissions p
WHERE r.role_name = 'admin' AND p.is_active = TRUE
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- SUPERVISOR - Can view and edit most things, but not manage users/roles
INSERT INTO user_mgmt.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM user_mgmt.roles r, user_mgmt.permissions p
WHERE r.role_name = 'supervisor' 
AND p.permission_name IN (
    'view_members', 'edit_members', 'view_claims', 'edit_claims',
    'view_providers', 'view_users', 'view_reports', 'export_data'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- AGENT - Standard access with limited write permissions
INSERT INTO user_mgmt.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM user_mgmt.roles r, user_mgmt.permissions p
WHERE r.role_name = 'agent'
AND p.permission_name IN (
    'view_members', 'edit_members', 'view_claims', 'edit_claims',
    'view_providers', 'view_users', 'view_reports'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- VIEWER - Read-only access
INSERT INTO user_mgmt.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM user_mgmt.roles r, user_mgmt.permissions p
WHERE r.role_name = 'viewer'
AND p.permission_name IN (
    'view_members', 'view_claims', 'view_providers', 'view_reports'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ============================================================================
-- 4. USERS TABLE - Main user account table with security features
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role_id INT NOT NULL REFERENCES user_mgmt.roles(role_id),
    
    -- User Status Fields
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    last_login TIMESTAMP,
    last_password_change TIMESTAMP,
    
    -- Contact Information
    phone_number VARCHAR(20),
    department VARCHAR(100),
    manager_id INT REFERENCES user_mgmt.users(user_id),
    
    -- Security Fields
    failed_login_attempts INT DEFAULT 0 CHECK (failed_login_attempts >= 0),
    locked_until TIMESTAMP,
    password_reset_token VARCHAR(500),
    password_reset_expires TIMESTAMP,
    
    -- Multi-Factor Authentication
    mfa_enabled BOOLEAN DEFAULT FALSE,
    mfa_method VARCHAR(50), -- 'totp', 'email', 'sms'
    mfa_secret VARCHAR(255),
    mfa_backup_codes TEXT,
    
    -- Security Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INT REFERENCES user_mgmt.users(user_id),
    updated_by INT REFERENCES user_mgmt.users(user_id)
);

-- Create comprehensive indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_username ON user_mgmt.users(username) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_users_email ON user_mgmt.users(email) WHERE is_deleted = FALSE;
CREATE INDEX IF NOT EXISTS idx_users_role_id ON user_mgmt.users(role_id);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON user_mgmt.users(is_active);
CREATE INDEX IF NOT EXISTS idx_users_is_deleted ON user_mgmt.users(is_deleted);
CREATE INDEX IF NOT EXISTS idx_users_locked_until ON user_mgmt.users(locked_until);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON user_mgmt.users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_manager_id ON user_mgmt.users(manager_id);

-- ============================================================================
-- 5. AUDIT_LOG TABLE - Comprehensive audit trail for compliance
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.audit_logs (
    audit_id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES user_mgmt.users(user_id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id INT,
    resource_name VARCHAR(255),
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    status VARCHAR(20) DEFAULT 'success' CHECK (status IN ('success', 'failed', 'pending')),
    error_message TEXT,
    duration_ms INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create comprehensive indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_audit_user_id ON user_mgmt.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON user_mgmt.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action ON user_mgmt.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_resource ON user_mgmt.audit_logs(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_audit_status ON user_mgmt.audit_logs(status);

-- ============================================================================
-- 6. LOGIN_HISTORY TABLE - Track all login attempts for security monitoring
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.login_history (
    login_id BIGSERIAL PRIMARY KEY,
    user_id INT REFERENCES user_mgmt.users(user_id) ON DELETE SET NULL,
    username VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    device_info VARCHAR(255),
    status VARCHAR(20) NOT NULL CHECK (status IN ('success', 'failed', 'locked', 'mfa_required')), 
    failure_reason VARCHAR(255),
    mfa_verified BOOLEAN DEFAULT FALSE,
    session_id VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for login query performance
CREATE INDEX IF NOT EXISTS idx_login_user_id ON user_mgmt.login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_created_at ON user_mgmt.login_history(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_login_username ON user_mgmt.login_history(username);
CREATE INDEX IF NOT EXISTS idx_login_status ON user_mgmt.login_history(status);
CREATE INDEX IF NOT EXISTS idx_login_ip ON user_mgmt.login_history(ip_address);

-- ============================================================================
-- 7. SESSION TABLE - Track active user sessions with security controls
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.sessions (
    session_id VARCHAR(500) PRIMARY KEY,
    user_id INT NOT NULL REFERENCES user_mgmt.users(user_id) ON DELETE CASCADE,
    token VARCHAR(2000) NOT NULL,
    token_type VARCHAR(50) DEFAULT 'Bearer',
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    device_info VARCHAR(255),
    browser_fingerprint VARCHAR(500),
    
    -- Session Management
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Security
    is_mfa_verified BOOLEAN DEFAULT FALSE,
    refresh_token VARCHAR(500),
    refresh_token_expires TIMESTAMP,
    revoked_at TIMESTAMP
);

-- Create comprehensive session indexes
CREATE INDEX IF NOT EXISTS idx_session_user_id ON user_mgmt.sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_session_expires_at ON user_mgmt.sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_session_is_active ON user_mgmt.sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_session_token ON user_mgmt.sessions(token);
CREATE INDEX IF NOT EXISTS idx_session_created_at ON user_mgmt.sessions(created_at DESC);

-- ============================================================================
-- 8. PASSWORD_RESET_TOKENS TABLE - Secure password reset management
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_mgmt.password_reset_tokens (
    token_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES user_mgmt.users(user_id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    token_hash VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    used_at TIMESTAMP,
    used_from_ip VARCHAR(45),
    is_revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMP,
    revoke_reason VARCHAR(255)
);

-- Create indexes for password reset token lookups
CREATE INDEX IF NOT EXISTS idx_reset_token ON user_mgmt.password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_reset_token_hash ON user_mgmt.password_reset_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_reset_user_id ON user_mgmt.password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_reset_expires_at ON user_mgmt.password_reset_tokens(expires_at);

-- ============================================================================
-- 9. SAMPLE DATA - Insert demo users with hashed passwords (bcrypt)
-- ============================================================================
-- Password: "secret" hashed with bcrypt (cost=12):
-- Hash: $2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5YmMxSUGyohie

-- Create admin user
INSERT INTO user_mgmt.users (
    username, email, full_name, hashed_password, role_id,
    is_active, is_verified, phone_number, department, created_by, updated_by
)
SELECT 
    'admin',
    'admin@healthplan.com',
    'System Administrator',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5YmMxSUGyohie', -- 'secret'
    r.role_id,
    TRUE,
    TRUE,
    '(800) 555-0100',
    'IT Administration',
    NULL,
    NULL
FROM user_mgmt.roles r WHERE r.role_name = 'admin'
ON CONFLICT (username) DO NOTHING;

-- Create supervisor user
INSERT INTO user_mgmt.users (
    username, email, full_name, hashed_password, role_id,
    is_active, is_verified, phone_number, department, created_by, updated_by
)
SELECT 
    'supervisor',
    'supervisor@healthplan.com',
    'Call Center Supervisor',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5YmMxSUGyohie', -- 'secret'
    r.role_id,
    TRUE,
    TRUE,
    '(800) 555-0101',
    'Call Center Management',
    (SELECT user_id FROM user_mgmt.users WHERE username = 'admin'),
    (SELECT user_id FROM user_mgmt.users WHERE username = 'admin')
FROM user_mgmt.roles r WHERE r.role_name = 'supervisor'
ON CONFLICT (username) DO NOTHING;

-- Create agent user
INSERT INTO user_mgmt.users (
    username, email, full_name, hashed_password, role_id,
    is_active, is_verified, phone_number, department, created_by, updated_by
)
SELECT 
    'agent',
    'agent@healthplan.com',
    'Call Center Agent',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5YmMxSUGyohie', -- 'secret'
    r.role_id,
    TRUE,
    TRUE,
    '(800) 555-0102',
    'Call Center Operations',
    (SELECT user_id FROM user_mgmt.users WHERE username = 'admin'),
    (SELECT user_id FROM user_mgmt.users WHERE username = 'admin')
FROM user_mgmt.roles r WHERE r.role_name = 'agent'
ON CONFLICT (username) DO NOTHING;

-- Create viewer user
INSERT INTO user_mgmt.users (
    username, email, full_name, hashed_password, role_id,
    is_active, is_verified, phone_number, department, created_by, updated_by
)
SELECT 
    'viewer',
    'viewer@healthplan.com',
    'Report Viewer',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5YmMxSUGyohie', -- 'secret'
    r.role_id,
    TRUE,
    TRUE,
    '(800) 555-0103',
    'Finance',
    (SELECT user_id FROM user_mgmt.users WHERE username = 'admin'),
    (SELECT user_id FROM user_mgmt.users WHERE username = 'admin')
FROM user_mgmt.roles r WHERE r.role_name = 'viewer'
ON CONFLICT (username) DO NOTHING;

-- ============================================================================
-- 10. VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: User Details with Role Information
DROP VIEW IF EXISTS user_mgmt.v_user_details CASCADE;
CREATE OR REPLACE VIEW user_mgmt.v_user_details AS
SELECT 
    u.user_id,
    u.username,
    u.email,
    u.full_name,
    u.phone_number,
    u.department,
    r.role_id,
    r.role_name,
    r.permission_level,
    u.is_active,
    u.is_verified,
    u.is_deleted,
    u.last_login,
    u.last_password_change,
    u.mfa_enabled,
    u.failed_login_attempts,
    u.locked_until,
    u.created_at,
    u.updated_at,
    (SELECT COUNT(*) FROM user_mgmt.sessions WHERE user_id = u.user_id AND is_active = TRUE) as active_sessions,
    (SELECT COUNT(*) FROM user_mgmt.login_history WHERE user_id = u.user_id AND status = 'success' AND created_at > NOW() - INTERVAL '7 days') as logins_last_7days
FROM user_mgmt.users u
JOIN user_mgmt.roles r ON u.role_id = r.role_id
WHERE u.is_deleted = FALSE;

-- View: User Permissions (flattened with role info)
DROP VIEW IF EXISTS user_mgmt.v_user_permissions CASCADE;
CREATE OR REPLACE VIEW user_mgmt.v_user_permissions AS
SELECT DISTINCT
    u.user_id,
    u.username,
    u.email,
    r.role_id,
    r.role_name,
    r.permission_level,
    p.permission_id,
    p.permission_name,
    p.resource,
    p.action,
    p.permission_level as perm_level
FROM user_mgmt.users u
JOIN user_mgmt.roles r ON u.role_id = r.role_id
JOIN user_mgmt.role_permissions rp ON r.role_id = rp.role_id AND rp.revoked_at IS NULL
JOIN user_mgmt.permissions p ON rp.permission_id = p.permission_id
WHERE u.is_deleted = FALSE AND u.is_active = TRUE AND p.is_active = TRUE;

-- View: Recent Login Activity (Last 90 Days)
DROP VIEW IF EXISTS user_mgmt.v_recent_logins CASCADE;
CREATE OR REPLACE VIEW user_mgmt.v_recent_logins AS
SELECT 
    lh.login_id,
    u.user_id,
    u.username,
    u.email,
    lh.status,
    lh.ip_address,
    lh.device_info,
    lh.mfa_verified,
    lh.created_at,
    ROW_NUMBER() OVER (PARTITION BY u.user_id ORDER BY lh.created_at DESC) as login_rank
FROM user_mgmt.login_history lh
LEFT JOIN user_mgmt.users u ON lh.user_id = u.user_id
WHERE lh.created_at > NOW() - INTERVAL '90 days'
ORDER BY lh.created_at DESC;

-- View: Active Sessions Summary
DROP VIEW IF EXISTS user_mgmt.v_active_sessions CASCADE;
CREATE OR REPLACE VIEW user_mgmt.v_active_sessions AS
SELECT 
    s.session_id,
    s.user_id,
    u.username,
    u.email,
    u.full_name,
    s.ip_address,
    s.device_info,
    s.browser_fingerprint,
    s.is_mfa_verified,
    s.created_at,
    s.expires_at,
    s.last_activity,
    (NOW() < s.expires_at) as is_valid,
    EXTRACT(EPOCH FROM (s.expires_at - NOW())) / 60 as minutes_until_expiry
FROM user_mgmt.sessions s
JOIN user_mgmt.users u ON s.user_id = u.user_id
WHERE s.is_active = TRUE AND s.revoked_at IS NULL;

-- View: User Audit Activity
DROP VIEW IF EXISTS user_mgmt.v_user_audit_activity CASCADE;
CREATE OR REPLACE VIEW user_mgmt.v_user_audit_activity AS
SELECT 
    al.audit_id,
    al.user_id,
    u.username,
    u.email,
    al.action,
    al.resource_type,
    al.resource_id,
    al.resource_name,
    al.status,
    al.ip_address,
    al.created_at,
    (SELECT COUNT(*) FROM user_mgmt.audit_logs WHERE user_id = al.user_id AND created_at > NOW() - INTERVAL '1 day') as actions_today
FROM user_mgmt.audit_logs al
LEFT JOIN user_mgmt.users u ON al.user_id = u.user_id
ORDER BY al.created_at DESC;

-- ============================================================================
-- 11. FUNCTIONS FOR USER MANAGEMENT OPERATIONS
-- ============================================================================

-- Function: Update user's last login timestamp and reset failed attempts
CREATE OR REPLACE FUNCTION user_mgmt.fn_update_last_login(p_user_id INT)
RETURNS VOID AS $$
BEGIN
    UPDATE user_mgmt.users 
    SET last_login = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP,
        failed_login_attempts = 0,
        locked_until = NULL
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Increment failed login attempts and handle account lockout
CREATE OR REPLACE FUNCTION user_mgmt.fn_increment_failed_login(
    p_user_id INT, 
    p_max_attempts INT DEFAULT 5,
    p_lockout_duration INTERVAL DEFAULT '30 minutes'
)
RETURNS TABLE(attempts INT, is_locked BOOLEAN, locked_until_time TIMESTAMP) AS $$
DECLARE
    v_attempts INT;
    v_is_locked BOOLEAN := FALSE;
    v_locked_until TIMESTAMP;
BEGIN
    -- Increment failed attempts
    UPDATE user_mgmt.users 
    SET failed_login_attempts = failed_login_attempts + 1
    WHERE user_id = p_user_id
    RETURNING failed_login_attempts INTO v_attempts;
    
    -- Check if account should be locked
    IF v_attempts >= p_max_attempts THEN
        v_locked_until := CURRENT_TIMESTAMP + p_lockout_duration;
        UPDATE user_mgmt.users 
        SET locked_until = v_locked_until
        WHERE user_id = p_user_id;
        v_is_locked := TRUE;
    END IF;
    
    RETURN QUERY SELECT v_attempts, v_is_locked, v_locked_until;
END;
$$ LANGUAGE plpgsql;

-- Function: Check if user account is locked
CREATE OR REPLACE FUNCTION user_mgmt.fn_is_user_locked(p_user_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_locked_until TIMESTAMP;
BEGIN
    SELECT locked_until INTO v_locked_until FROM user_mgmt.users WHERE user_id = p_user_id;
    
    -- If locked_until is NULL or in the past, account is not locked
    IF v_locked_until IS NULL OR v_locked_until < CURRENT_TIMESTAMP THEN
        RETURN FALSE;
    ELSE
        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Unlock user account
CREATE OR REPLACE FUNCTION user_mgmt.fn_unlock_user(p_user_id INT)
RETURNS VOID AS $$
BEGIN
    UPDATE user_mgmt.users 
    SET failed_login_attempts = 0,
        locked_until = NULL,
        updated_at = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Create audit log entry
CREATE OR REPLACE FUNCTION user_mgmt.fn_create_audit_log(
    p_user_id INT,
    p_action VARCHAR,
    p_resource_type VARCHAR,
    p_resource_id INT,
    p_resource_name VARCHAR,
    p_old_values JSONB,
    p_new_values JSONB,
    p_ip_address VARCHAR,
    p_status VARCHAR DEFAULT 'success'
)
RETURNS BIGINT AS $$
DECLARE
    v_audit_id BIGINT;
BEGIN
    INSERT INTO user_mgmt.audit_logs (
        user_id, action, resource_type, resource_id, resource_name,
        old_values, new_values, ip_address, status
    ) VALUES (
        p_user_id, p_action, p_resource_type, p_resource_id, p_resource_name,
        p_old_values, p_new_values, p_ip_address, p_status
    )
    RETURNING audit_id INTO v_audit_id;
    
    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Create session
CREATE OR REPLACE FUNCTION user_mgmt.fn_create_session(
    p_user_id INT,
    p_session_id VARCHAR,
    p_token VARCHAR,
    p_ip_address VARCHAR,
    p_expires_at TIMESTAMP
)
RETURNS VARCHAR AS $$
DECLARE
    v_session_id VARCHAR;
BEGIN
    v_session_id := COALESCE(p_session_id, gen_random_uuid()::VARCHAR);
    
    INSERT INTO user_mgmt.sessions (
        session_id, user_id, token, ip_address, expires_at
    ) VALUES (
        v_session_id, p_user_id, p_token, p_ip_address, p_expires_at
    );
    
    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Cleanup expired sessions
CREATE OR REPLACE FUNCTION user_mgmt.fn_cleanup_expired_sessions()
RETURNS INT AS $$
DECLARE
    v_count INT;
BEGIN
    DELETE FROM user_mgmt.sessions 
    WHERE expires_at < CURRENT_TIMESTAMP AND is_active = TRUE;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Function: Get user permissions (comma-separated list)
CREATE OR REPLACE FUNCTION user_mgmt.fn_get_user_permissions(p_user_id INT)
RETURNS TEXT AS $$
DECLARE
    v_permissions TEXT;
BEGIN
    SELECT STRING_AGG(DISTINCT p.permission_name, ', ')
    INTO v_permissions
    FROM user_mgmt.users u
    JOIN user_mgmt.roles r ON u.role_id = r.role_id
    JOIN user_mgmt.role_permissions rp ON r.role_id = rp.role_id AND rp.revoked_at IS NULL
    JOIN user_mgmt.permissions p ON rp.permission_id = p.permission_id
    WHERE u.user_id = p_user_id AND u.is_deleted = FALSE;
    
    RETURN COALESCE(v_permissions, '');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 12. TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Trigger: Update users.updated_at on any change
CREATE OR REPLACE FUNCTION user_mgmt.fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_users_update_timestamp ON user_mgmt.users;
CREATE TRIGGER tr_users_update_timestamp
BEFORE UPDATE ON user_mgmt.users
FOR EACH ROW
EXECUTE FUNCTION user_mgmt.fn_update_timestamp();

-- Trigger: Update roles.updated_at
DROP TRIGGER IF EXISTS tr_roles_update_timestamp ON user_mgmt.roles;
CREATE TRIGGER tr_roles_update_timestamp
BEFORE UPDATE ON user_mgmt.roles
FOR EACH ROW
EXECUTE FUNCTION user_mgmt.fn_update_timestamp();

-- Trigger: Ensure role_name is lowercase
DROP TRIGGER IF EXISTS tr_roles_lowercase_name ON user_mgmt.roles;
CREATE OR REPLACE FUNCTION user_mgmt.fn_lowercase_role_name()
RETURNS TRIGGER AS $$
BEGIN
    NEW.role_name = LOWER(NEW.role_name);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_roles_lowercase_name
BEFORE INSERT OR UPDATE ON user_mgmt.roles
FOR EACH ROW
EXECUTE FUNCTION user_mgmt.fn_lowercase_role_name();

-- Trigger: Update last_activity on session access
DROP TRIGGER IF EXISTS tr_session_activity ON user_mgmt.sessions;
CREATE OR REPLACE FUNCTION user_mgmt.fn_update_session_activity()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_activity = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_session_activity
BEFORE UPDATE ON user_mgmt.sessions
FOR EACH ROW
WHEN (OLD.last_activity IS DISTINCT FROM NEW.last_activity)
EXECUTE FUNCTION user_mgmt.fn_update_session_activity();

-- ============================================================================
-- 13. CONSTRAINTS AND VALIDATIONS
-- ============================================================================

-- Constraint: Ensure password is not empty
ALTER TABLE user_mgmt.users
ADD CONSTRAINT ck_users_password_not_empty CHECK (length(hashed_password) > 0);

-- Constraint: Ensure email format (basic validation)
ALTER TABLE user_mgmt.users
ADD CONSTRAINT ck_users_email_format CHECK (email ~ '^[^@]+@[^@]+\.[^@]+$');

-- Constraint: Ensure username is at least 3 characters
ALTER TABLE user_mgmt.users
ADD CONSTRAINT ck_users_username_length CHECK (length(username) >= 3);

-- ============================================================================
-- 14. PERFORMANCE OPTIMIZATION - MATERIALIZED VIEWS
-- ============================================================================

-- Materialized View: User Statistics (refresh periodically)
DROP MATERIALIZED VIEW IF EXISTS user_mgmt.mv_user_statistics;
CREATE MATERIALIZED VIEW user_mgmt.mv_user_statistics AS
SELECT 
    (SELECT COUNT(*) FROM user_mgmt.users WHERE is_deleted = FALSE) as total_active_users,
    (SELECT COUNT(*) FROM user_mgmt.users WHERE is_deleted = FALSE AND is_active = TRUE) as total_enabled_users,
    (SELECT COUNT(*) FROM user_mgmt.users WHERE is_deleted = FALSE AND locked_until > CURRENT_TIMESTAMP) as locked_users,
    (SELECT COUNT(DISTINCT user_id) FROM user_mgmt.sessions WHERE is_active = TRUE) as active_sessions,
    (SELECT COUNT(*) FROM user_mgmt.login_history WHERE created_at > CURRENT_DATE) as logins_today,
    (SELECT COUNT(*) FROM user_mgmt.audit_logs WHERE created_at > NOW() - INTERVAL '24 hours') as audit_actions_today,
    NOW() as last_refreshed;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_mv_user_stats_refresh ON user_mgmt.mv_user_statistics USING hash((last_refreshed));

-- Add COMMENT on tables for data classification
COMMENT ON TABLE user_mgmt.users IS 'PII - Personally Identifiable Information. Passwords encrypted with bcrypt. Encrypt at rest.';
COMMENT ON TABLE user_mgmt.login_history IS 'PHI - Protected Health Information. Sensitive security audit data.';
COMMENT ON TABLE user_mgmt.audit_logs IS 'PHI - Protected Health Information. Compliance audit trail.';
COMMENT ON COLUMN user_mgmt.users.hashed_password IS 'Password hashed with bcrypt (cost=12). Never store plain text.';
COMMENT ON COLUMN user_mgmt.users.mfa_secret IS 'MFA secret key. Encrypt at rest. Use for TOTP generation.';

-- ============================================================================
-- 15. VERIFICATION QUERIES
-- ============================================================================
-- Run these queries to verify the schema:
--
-- SELECT * FROM user_mgmt.roles;
-- SELECT * FROM user_mgmt.permissions;
-- SELECT * FROM user_mgmt.users;
-- SELECT * FROM user_mgmt.v_user_details;
-- SELECT * FROM user_mgmt.v_user_permissions;
-- SELECT * FROM user_mgmt.v_recent_logins;
-- SELECT * FROM user_mgmt.v_active_sessions;
-- SELECT * FROM user_mgmt.v_user_audit_activity;
-- SELECT * FROM user_mgmt.mv_user_statistics;
--
-- Count records:
-- SELECT COUNT(*) as total_roles FROM user_mgmt.roles;
-- SELECT COUNT(*) as total_permissions FROM user_mgmt.permissions;
-- SELECT COUNT(*) as total_users FROM user_mgmt.users WHERE is_deleted = FALSE;
-- SELECT COUNT(*) as total_active_sessions FROM user_mgmt.sessions WHERE is_active = TRUE;
--
-- ============================================================================
-- END OF USER MANAGEMENT SCHEMA (v2.0 Enhanced with Namespace)
-- ============================================================================
