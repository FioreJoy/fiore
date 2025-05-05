\echo '--- Applying Phase 1 Indexes ---'

-- == Full-Text Search Indexes (Using GIN) ==
-- Requires unaccent extension for better non-English/accented char search (Optional but recommended)
-- CREATE EXTENSION IF NOT EXISTS unaccent;

\echo 'Creating FTS index on users (name, username)...'
-- Option 1: Index on expression (simpler, potentially slower writes)
CREATE INDEX IF NOT EXISTS idx_users_fts ON public.users
    USING gin(to_tsvector('english', coalesce(name, '') || ' ' || coalesce(username, '')));
-- Option 2: Generated column (PG12+) - Usually better performance
-- ALTER TABLE public.users ADD COLUMN fts_doc tsvector
--    GENERATED ALWAYS AS (to_tsvector('english', coalesce(name, '') || ' ' || coalesce(username, ''))) STORED;
-- CREATE INDEX IF NOT EXISTS idx_users_fts ON public.users USING gin(fts_doc);


\echo 'Creating FTS index on communities (name, description)...'
CREATE INDEX IF NOT EXISTS idx_communities_fts ON public.communities
    USING gin(to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, '')));
-- Option 2: Generated column
-- ALTER TABLE public.communities ADD COLUMN fts_doc tsvector
--    GENERATED ALWAYS AS (to_tsvector('english', coalesce(name, '') || ' ' || coalesce(description, ''))) STORED;
-- CREATE INDEX IF NOT EXISTS idx_communities_fts ON public.communities USING gin(fts_doc);

\echo 'Creating FTS index on posts (title, content)...'
CREATE INDEX IF NOT EXISTS idx_posts_fts ON public.posts
    USING gin(to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, '')));
-- Option 2: Generated column
-- ALTER TABLE public.posts ADD COLUMN fts_doc tsvector
--    GENERATED ALWAYS AS (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(content, ''))) STORED;
-- CREATE INDEX IF NOT EXISTS idx_posts_fts ON public.posts USING gin(fts_doc);


-- == Standard B-Tree Indexes for Filtering/Sorting ==

\echo 'Creating B-Tree indexes...'
-- Events (Timestamp is most common for feeds/sorting)
CREATE INDEX IF NOT EXISTS idx_events_event_timestamp_desc ON public.events (event_timestamp DESC NULLS LAST); -- Add NULLS LAST
-- idx_events_community_id likely created by FK, verify if needed

-- Posts (created_at likely exists, user_id might)
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts (user_id);

-- Communities
CREATE INDEX IF NOT EXISTS idx_communities_interest ON public.communities (interest text_pattern_ops); -- Use text_pattern_ops for LIKE queries if needed
CREATE INDEX IF NOT EXISTS idx_communities_created_by ON public.communities (created_by);
CREATE INDEX IF NOT EXISTS idx_communities_created_at_desc ON public.communities (created_at DESC NULLS LAST);


-- Users
CREATE INDEX IF NOT EXISTS idx_users_college ON public.users (college);
CREATE INDEX IF NOT EXISTS idx_users_interest ON public.users (interest text_pattern_ops);
-- idx_users_last_seen already exists

-- == PostGIS Spatial Indexing (Optional - Requires PostGIS Extension) ==
-- Check if PostGIS is installed FIRST: SELECT postgis_version();
-- If not installed: CREATE EXTENSION postgis; (Run as database superuser)

-- Use DO block to create indexes only if extension exists
DO $$
BEGIN
   IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
      RAISE NOTICE 'PostGIS extension found, creating spatial indexes...';
      CREATE INDEX IF NOT EXISTS idx_users_location_gist ON public.users USING gist (current_location) WHERE current_location IS NOT NULL;
      CREATE INDEX IF NOT EXISTS idx_communities_location_gist ON public.communities USING gist (primary_location) WHERE primary_location IS NOT NULL;
      RAISE NOTICE 'Spatial indexes created (or already exist).';
   ELSE
      RAISE WARNING 'PostGIS extension not found. Skipping spatial index creation.';
   END IF;
END $$;


\echo '--- Phase 1 Indexing script finished ---'