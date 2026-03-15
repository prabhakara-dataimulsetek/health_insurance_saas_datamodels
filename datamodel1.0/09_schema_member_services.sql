-- ============================================================================
-- SCHEMA: member_services
-- Tables: id_card_request
-- Depends on: member_mgmt, callcenter
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS member_services;

CREATE TABLE member_services.id_card_request (
    request_id VARCHAR(50) PRIMARY KEY,
    member_id VARCHAR(50) NOT NULL REFERENCES member_mgmt.member(member_id),
    call_id VARCHAR(50) REFERENCES callcenter.call(call_id),
    request_date TIMESTAMP NOT NULL,
    delivery_method VARCHAR(20) NOT NULL, -- Email, Mail, Digital Wallet
    delivery_address VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    fulfilled_date TIMESTAMP,
    tracking_number VARCHAR(100),
    CONSTRAINT chk_idcard_delivery CHECK (delivery_method IN ('Email', 'Mail', 'Digital Wallet', 'SMS')),
    CONSTRAINT chk_idcard_status CHECK (status IN ('Pending', 'Processing', 'Sent', 'Delivered', 'Failed'))
);

CREATE INDEX idx_idcard_member ON member_services.id_card_request(member_id);
CREATE INDEX idx_idcard_status ON member_services.id_card_request(status);
