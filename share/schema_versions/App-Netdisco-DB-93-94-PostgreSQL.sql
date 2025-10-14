BEGIN;

ALTER TABLE device_port_properties ADD COLUMN "cable_type" text;

COMMIT;
