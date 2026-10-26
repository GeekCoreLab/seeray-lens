ALTER TABLE raw_event
  ADD COLUMN client_ip inet;

ALTER TABLE analytics_session
  ADD COLUMN client_ip inet;
