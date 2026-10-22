ALTER TABLE fingerprint_observation
  ADD COLUMN fingerprint_type VARCHAR(16) NOT NULL DEFAULT 'browser';

ALTER TABLE fingerprint_observation
  ADD CONSTRAINT fingerprint_observation_type_check
  CHECK (fingerprint_type IN ('browser', 'ja4'));

CREATE INDEX idx_fingerprint_observation_site_type_key
  ON fingerprint_observation(site_id, fingerprint_type, fingerprint_key, observed_at);
