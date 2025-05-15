-- This script MUST run AFTER 00_install_postgis.sh (if used) and the default AGE extension creation.
-- It should run BEFORE your main 01_schema.sql if that schema relies on the graph existing
-- or creates graph labels/vertices/edges.
-- However, for just creating the graph, it can run after the main schema too.
-- Let's try running it early.

\echo 'Attempting to load AGE extension and set search path...'
LOAD 'age';
SET search_path = ag_catalog, '$user', public;
\echo 'Search path set. Attempting to create graph "fiore"...'

-- Create the graph 'fiore' if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ag_catalog.ag_graph WHERE name = 'fiore') THEN
        PERFORM ag_catalog.create_graph('fiore');
        RAISE NOTICE 'Graph "fiore" created by 00_init_age_graph.sql.';
    ELSE
        RAISE NOTICE 'Graph "fiore" already exists (checked by 00_init_age_graph.sql).';
    END IF;
END
$$;

-- Optional: You could also create the 'fiore' SQL schema here if it's purely for AGE
-- CREATE SCHEMA IF NOT EXISTS fiore; 
-- COMMENT ON SCHEMA fiore IS 'Schema for Apache AGE graph data backing tables';
CREATE DATABASE hoppscotch;

\echo 'Graph "fiore" creation/check complete.'
