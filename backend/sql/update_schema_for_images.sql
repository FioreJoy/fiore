-- Change 'image' from bytea to text to store MinIO object name/path
ALTER TABLE users DROP COLUMN IF EXISTS image; -- Drop if it exists as bytea
ALTER TABLE users ADD COLUMN image_path TEXT NULL; -- Store MinIO object name/path

ALTER TABLE communities ADD COLUMN logo_path TEXT NULL;

ALTER TABLE posts ADD COLUMN image_path TEXT NULL;