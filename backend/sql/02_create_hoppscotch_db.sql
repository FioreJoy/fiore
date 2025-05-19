-- Create the 'hoppscotch' database if it doesn't exist
SELECT 'CREATE DATABASE hoppscotch'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'hoppscotch')\gexec

-- After the DB is created, connect to it to set its default search_path
\connect hoppscotch
ALTER DATABASE hoppscotch SET search_path = public, "$user"; -- Set DB default explicitly
\echo 'Hoppscotch database created/exists and its default search_path configured to public, "$user".'

-- Connect back to a default DB (e.g., postgres or fiore) to alter the user role globally.
-- This global alteration might be what's needed if the per-DB setting isn't fully respected by Prisma.
\connect postgres

-- Set a global default search path for 'fioreuser' that is simple.
-- This will apply when 'fioreuser' connects to ANY database, unless that database
-- or the role IN that database has a more specific override.
ALTER ROLE fioreuser SET search_path = public, "$user";
\echo 'Global default search_path for fioreuser set to public, "$user".'

-- Connect to your 'fiore' database (application DB)
\connect fiore

-- Explicitly set the search_path for 'fioreuser' WHEN CONNECTED TO 'fiore'
-- to include ag_catalog for AGE operations.
ALTER ROLE fioreuser IN DATABASE fiore SET search_path = ag_catalog, "$user", public;
-- Also set the 'fiore' database default to include ag_catalog.
ALTER DATABASE fiore SET search_path = ag_catalog, "$user", public;
\echo 'Search_path for fioreuser IN DATABASE fiore (and fiore DB default) configured to include ag_catalog.'