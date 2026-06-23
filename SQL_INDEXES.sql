-- AURORA Performance: Missing Database Indexes
-- Run after migration to production

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nuuh_created_at
    ON nodes_user_usage_history (created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_status_active
    ON users (status) WHERE status = 'ACTIVE';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_torrent_blocker_reports_user
    ON torrent_blocker_reports (user_id, created_at);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_nodes_usage_history_lookup
    ON nodes_usage_history (node_uuid, created_at DESC);
