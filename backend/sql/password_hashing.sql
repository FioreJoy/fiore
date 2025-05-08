CREATE EXTENSION IF NOT EXISTS pgcrypto;

UPDATE users
SET password_hash = crypt('alice123', gen_salt('bf'))
WHERE email = 'alice@example.com';

UPDATE users
SET password_hash = crypt('bobsecure', gen_salt('bf'))
WHERE email = 'bob@example.com';

UPDATE users
SET password_hash = crypt('charliepass', gen_salt('bf'))
WHERE email = 'charlie@example.com';
