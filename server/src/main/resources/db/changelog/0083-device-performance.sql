ALTER TABLE analytics_session ADD COLUMN hardware_concurrency INTEGER;
ALTER TABLE analytics_session ADD COLUMN device_memory_gb DOUBLE PRECISION;
ALTER TABLE analytics_session ADD COLUMN connection_type VARCHAR(16);
ALTER TABLE analytics_session ADD COLUMN connection_downlink_mbps DOUBLE PRECISION;
ALTER TABLE analytics_session ADD COLUMN connection_rtt_ms INTEGER;
ALTER TABLE analytics_session ADD COLUMN save_data BOOLEAN;
ALTER TABLE analytics_session ADD COLUMN ttfb_ms INTEGER;
ALTER TABLE analytics_session ADD COLUMN dom_interactive_ms INTEGER;
ALTER TABLE analytics_session ADD COLUMN page_load_ms INTEGER;
ALTER TABLE analytics_session ADD COLUMN js_heap_used_mb DOUBLE PRECISION;
ALTER TABLE analytics_session ADD COLUMN js_heap_limit_mb DOUBLE PRECISION;
ALTER TABLE analytics_session ADD COLUMN frame_rate_fps INTEGER;
ALTER TABLE analytics_session ADD COLUMN performance_score INTEGER;
ALTER TABLE analytics_session ADD COLUMN performance_tier VARCHAR(16);

CREATE INDEX idx_analytics_session_site_device_performance
  ON analytics_session (site_id, started_at, performance_tier, performance_score);
