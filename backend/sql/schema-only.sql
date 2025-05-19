

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE SCHEMA ag_catalog;

CREATE SCHEMA fiore;

CREATE EXTENSION IF NOT EXISTS age WITH SCHEMA ag_catalog;

COMMENT ON EXTENSION age IS 'AGE database extension';

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';

CREATE TYPE public.device_platform AS ENUM (
    'ios',
    'android',
    'web'
);

CREATE TYPE public.notification_entity_type AS ENUM (
    'user',
    'post',
    'reply',
    'community',
    'event'
);

CREATE TYPE public.notification_type AS ENUM (
    'new_follower',
    'post_reply',
    'reply_reply',
    'post_vote',
    'reply_vote',
    'post_favorite',
    'reply_favorite',
    'event_invite',
    'event_reminder',
    'event_update',
    'community_invite',
    'community_post',
    'user_mention',
    'new_community_event'
);

SET default_tablespace = '';

SET default_table_access_method = heap;

CREATE TABLE fiore._ag_label_edge (
    id ag_catalog.graphid NOT NULL,
    start_id ag_catalog.graphid NOT NULL,
    end_id ag_catalog.graphid NOT NULL,
    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
);

CREATE TABLE fiore."CREATED" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."CREATED_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."CREATED_id_seq" OWNED BY fiore."CREATED".id;

CREATE TABLE fiore._ag_label_vertex (
    id ag_catalog.graphid NOT NULL,
    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
);

CREATE TABLE fiore."Community" (
)
INHERITS (fiore._ag_label_vertex);

CREATE SEQUENCE fiore."Community_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."Community_id_seq" OWNED BY fiore."Community".id;

CREATE TABLE fiore."Event" (
)
INHERITS (fiore._ag_label_vertex);

CREATE SEQUENCE fiore."Event_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."Event_id_seq" OWNED BY fiore."Event".id;

CREATE TABLE fiore."FAVORITED" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."FAVORITED_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."FAVORITED_id_seq" OWNED BY fiore."FAVORITED".id;

CREATE TABLE fiore."FOLLOWS" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."FOLLOWS_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."FOLLOWS_id_seq" OWNED BY fiore."FOLLOWS".id;

CREATE TABLE fiore."HAS_POST" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."HAS_POST_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."HAS_POST_id_seq" OWNED BY fiore."HAS_POST".id;

CREATE TABLE fiore."MEMBER_OF" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."MEMBER_OF_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."MEMBER_OF_id_seq" OWNED BY fiore."MEMBER_OF".id;

CREATE TABLE fiore."PARTICIPATED_IN" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."PARTICIPATED_IN_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."PARTICIPATED_IN_id_seq" OWNED BY fiore."PARTICIPATED_IN".id;

CREATE TABLE fiore."Post" (
)
INHERITS (fiore._ag_label_vertex);

CREATE SEQUENCE fiore."Post_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."Post_id_seq" OWNED BY fiore."Post".id;

CREATE TABLE fiore."REPLIED_TO" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."REPLIED_TO_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."REPLIED_TO_id_seq" OWNED BY fiore."REPLIED_TO".id;

CREATE TABLE fiore."Reply" (
)
INHERITS (fiore._ag_label_vertex);

CREATE SEQUENCE fiore."Reply_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."Reply_id_seq" OWNED BY fiore."Reply".id;

CREATE TABLE fiore."User" (
)
INHERITS (fiore._ag_label_vertex);

CREATE SEQUENCE fiore."User_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."User_id_seq" OWNED BY fiore."User".id;

CREATE TABLE fiore."VOTED" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."VOTED_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."VOTED_id_seq" OWNED BY fiore."VOTED".id;

CREATE TABLE fiore."WROTE" (
)
INHERITS (fiore._ag_label_edge);

CREATE SEQUENCE fiore."WROTE_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore."WROTE_id_seq" OWNED BY fiore."WROTE".id;

CREATE SEQUENCE fiore._ag_label_edge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore._ag_label_edge_id_seq OWNED BY fiore._ag_label_edge.id;

CREATE SEQUENCE fiore._ag_label_vertex_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;

ALTER SEQUENCE fiore._ag_label_vertex_id_seq OWNED BY fiore._ag_label_vertex.id;

CREATE SEQUENCE fiore._label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 65535
    CACHE 1
    CYCLE;

CREATE TABLE public.chat_message_media (
    message_id integer NOT NULL,
    media_id integer NOT NULL
);

CREATE TABLE public.chat_messages (
    id integer NOT NULL,
    community_id integer,
    event_id integer,
    user_id integer NOT NULL,
    content text NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now(),
    CONSTRAINT chat_messages_check CHECK ((((community_id IS NOT NULL) AND (event_id IS NULL)) OR ((community_id IS NULL) AND (event_id IS NOT NULL))))
);

CREATE SEQUENCE public.chat_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;

CREATE TABLE public.communities (
    id integer NOT NULL,
    name text NOT NULL,
    description text,
    created_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    interest text,
    location public.geography(Point,4326),
    location_address text,
    CONSTRAINT check_interest CHECK ((interest = ANY (ARRAY['Gaming'::text, 'Tech'::text, 'Science'::text, 'Music'::text, 'Sports'::text, 'College Event'::text, 'Activities'::text, 'Social'::text, 'Other'::text])))
);

COMMENT ON COLUMN public.communities.location IS 'Community''s primary geographic location (SRID 4326). Replaces old primary_location point.';

COMMENT ON COLUMN public.communities.location_address IS 'Community''s primary human-readable address.';

CREATE SEQUENCE public.communities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.communities_id_seq OWNED BY public.communities.id;

CREATE TABLE public.community_logo (
    community_id integer NOT NULL,
    media_id integer NOT NULL,
    set_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.community_members (
    id integer NOT NULL,
    user_id integer NOT NULL,
    community_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);

CREATE SEQUENCE public.community_members_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.community_members_id_seq OWNED BY public.community_members.id;

CREATE TABLE public.community_posts (
    id integer NOT NULL,
    community_id integer NOT NULL,
    post_id integer NOT NULL,
    added_at timestamp with time zone DEFAULT now()
);

CREATE SEQUENCE public.community_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.community_posts_id_seq OWNED BY public.community_posts.id;

CREATE TABLE public.event_participants (
    id integer NOT NULL,
    event_id integer NOT NULL,
    user_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);

CREATE SEQUENCE public.event_participants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.event_participants_id_seq OWNED BY public.event_participants.id;

CREATE TABLE public.events (
    id integer NOT NULL,
    community_id integer NOT NULL,
    creator_id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    location text NOT NULL,
    event_timestamp timestamp with time zone NOT NULL,
    max_participants integer DEFAULT 100 NOT NULL,
    image_url text,
    created_at timestamp with time zone DEFAULT now(),
    location_coords public.geography(Point,4326)
);

COMMENT ON COLUMN public.events.location IS 'Event''s human-readable address string.';

COMMENT ON COLUMN public.events.location_coords IS 'Event''s geographic coordinates (SRID 4326).';

CREATE SEQUENCE public.events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;

CREATE TABLE public.media_items (
    id integer NOT NULL,
    uploader_user_id integer NOT NULL,
    minio_object_name text NOT NULL,
    mime_type character varying(100) NOT NULL,
    file_size_bytes bigint,
    original_filename text,
    created_at timestamp with time zone DEFAULT now(),
    width integer,
    height integer,
    duration_seconds double precision
);

CREATE SEQUENCE public.media_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.media_items_id_seq OWNED BY public.media_items.id;

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    recipient_user_id integer NOT NULL,
    actor_user_id integer,
    type public.notification_type NOT NULL,
    related_entity_type public.notification_entity_type,
    related_entity_id integer,
    content_preview text,
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;

CREATE TABLE public.post_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);

CREATE SEQUENCE public.post_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.post_favorites_id_seq OWNED BY public.post_favorites.id;

CREATE TABLE public.post_media (
    post_id integer NOT NULL,
    media_id integer NOT NULL,
    display_order smallint DEFAULT 0
);

CREATE TABLE public.posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    title character varying(255) NOT NULL
);

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;

CREATE TABLE public.replies (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    parent_reply_id integer,
    created_at timestamp with time zone DEFAULT now()
);

CREATE SEQUENCE public.replies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.replies_id_seq OWNED BY public.replies.id;

CREATE TABLE public.reply_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reply_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);

CREATE SEQUENCE public.reply_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.reply_favorites_id_seq OWNED BY public.reply_favorites.id;

CREATE TABLE public.reply_media (
    reply_id integer NOT NULL,
    media_id integer NOT NULL,
    display_order smallint DEFAULT 0
);

CREATE TABLE public.user_blocks (
    blocker_id integer NOT NULL,
    blocked_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_blocker_not_blocked CHECK ((blocker_id <> blocked_id))
);

CREATE TABLE public.user_device_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    device_token text NOT NULL,
    platform public.device_platform NOT NULL,
    last_used_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE public.user_device_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.user_device_tokens_id_seq OWNED BY public.user_device_tokens.id;

CREATE TABLE public.user_followers (
    follower_id integer NOT NULL,
    following_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);

CREATE TABLE public.user_profile_picture (
    user_id integer NOT NULL,
    media_id integer NOT NULL,
    set_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.users (
    id integer NOT NULL,
    name text NOT NULL,
    username text NOT NULL,
    gender text NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    interest text,
    college_email text,
    college character varying(255),
    interests jsonb,
    last_seen timestamp with time zone DEFAULT now(),
    current_location_address text,
    notify_new_post_in_community boolean DEFAULT true,
    notify_new_reply_to_post boolean DEFAULT true,
    notify_new_event_in_community boolean DEFAULT true,
    notify_event_reminder boolean DEFAULT true,
    notify_direct_message boolean DEFAULT false,
    notify_event_update boolean DEFAULT true,
    location public.geography(Point,4326),
    location_last_updated timestamp with time zone,
    location_address text,
    CONSTRAINT gender_check CHECK ((gender = ANY (ARRAY['Male'::text, 'Female'::text, 'Others'::text])))
);

COMMENT ON COLUMN public.users.location IS 'User''s current geographic location (SRID 4326). Replaces old current_location point.';

COMMENT ON COLUMN public.users.location_last_updated IS 'Timestamp of when the location was last updated.';

COMMENT ON COLUMN public.users.location_address IS 'User''s current human-readable address.';

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;

CREATE TABLE public.votes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer,
    reply_id integer,
    vote_type boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_vote_target CHECK ((((post_id IS NOT NULL) AND (reply_id IS NULL)) OR ((post_id IS NULL) AND (reply_id IS NOT NULL))))
);

CREATE SEQUENCE public.votes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.votes_id_seq OWNED BY public.votes.id;

ALTER TABLE ONLY fiore."CREATED" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'CREATED'::name))::integer, nextval('fiore."CREATED_id_seq"'::regclass));

ALTER TABLE ONLY fiore."CREATED" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."Community" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Community'::name))::integer, nextval('fiore."Community_id_seq"'::regclass));

ALTER TABLE ONLY fiore."Community" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."Event" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Event'::name))::integer, nextval('fiore."Event_id_seq"'::regclass));

ALTER TABLE ONLY fiore."Event" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."FAVORITED" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'FAVORITED'::name))::integer, nextval('fiore."FAVORITED_id_seq"'::regclass));

ALTER TABLE ONLY fiore."FAVORITED" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."FOLLOWS" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'FOLLOWS'::name))::integer, nextval('fiore."FOLLOWS_id_seq"'::regclass));

ALTER TABLE ONLY fiore."FOLLOWS" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."HAS_POST" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'HAS_POST'::name))::integer, nextval('fiore."HAS_POST_id_seq"'::regclass));

ALTER TABLE ONLY fiore."HAS_POST" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."MEMBER_OF" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'MEMBER_OF'::name))::integer, nextval('fiore."MEMBER_OF_id_seq"'::regclass));

ALTER TABLE ONLY fiore."MEMBER_OF" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."PARTICIPATED_IN" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'PARTICIPATED_IN'::name))::integer, nextval('fiore."PARTICIPATED_IN_id_seq"'::regclass));

ALTER TABLE ONLY fiore."PARTICIPATED_IN" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."Post" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Post'::name))::integer, nextval('fiore."Post_id_seq"'::regclass));

ALTER TABLE ONLY fiore."Post" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."REPLIED_TO" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'REPLIED_TO'::name))::integer, nextval('fiore."REPLIED_TO_id_seq"'::regclass));

ALTER TABLE ONLY fiore."REPLIED_TO" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."Reply" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Reply'::name))::integer, nextval('fiore."Reply_id_seq"'::regclass));

ALTER TABLE ONLY fiore."Reply" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."User" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'User'::name))::integer, nextval('fiore."User_id_seq"'::regclass));

ALTER TABLE ONLY fiore."User" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."VOTED" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'VOTED'::name))::integer, nextval('fiore."VOTED_id_seq"'::regclass));

ALTER TABLE ONLY fiore."VOTED" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore."WROTE" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'WROTE'::name))::integer, nextval('fiore."WROTE_id_seq"'::regclass));

ALTER TABLE ONLY fiore."WROTE" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();

ALTER TABLE ONLY fiore._ag_label_edge ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, '_ag_label_edge'::name))::integer, nextval('fiore._ag_label_edge_id_seq'::regclass));

ALTER TABLE ONLY fiore._ag_label_vertex ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, '_ag_label_vertex'::name))::integer, nextval('fiore._ag_label_vertex_id_seq'::regclass));

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);

ALTER TABLE ONLY public.communities ALTER COLUMN id SET DEFAULT nextval('public.communities_id_seq'::regclass);

ALTER TABLE ONLY public.community_members ALTER COLUMN id SET DEFAULT nextval('public.community_members_id_seq'::regclass);

ALTER TABLE ONLY public.community_posts ALTER COLUMN id SET DEFAULT nextval('public.community_posts_id_seq'::regclass);

ALTER TABLE ONLY public.event_participants ALTER COLUMN id SET DEFAULT nextval('public.event_participants_id_seq'::regclass);

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);

ALTER TABLE ONLY public.media_items ALTER COLUMN id SET DEFAULT nextval('public.media_items_id_seq'::regclass);

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);

ALTER TABLE ONLY public.post_favorites ALTER COLUMN id SET DEFAULT nextval('public.post_favorites_id_seq'::regclass);

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);

ALTER TABLE ONLY public.replies ALTER COLUMN id SET DEFAULT nextval('public.replies_id_seq'::regclass);

ALTER TABLE ONLY public.reply_favorites ALTER COLUMN id SET DEFAULT nextval('public.reply_favorites_id_seq'::regclass);

ALTER TABLE ONLY public.user_device_tokens ALTER COLUMN id SET DEFAULT nextval('public.user_device_tokens_id_seq'::regclass);

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);

ALTER TABLE ONLY public.votes ALTER COLUMN id SET DEFAULT nextval('public.votes_id_seq'::regclass);

ALTER TABLE ONLY fiore._ag_label_edge
    ADD CONSTRAINT _ag_label_edge_pkey PRIMARY KEY (id);

ALTER TABLE ONLY fiore._ag_label_vertex
    ADD CONSTRAINT _ag_label_vertex_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.chat_message_media
    ADD CONSTRAINT chat_message_media_pkey PRIMARY KEY (message_id, media_id);

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.community_logo
    ADD CONSTRAINT community_logo_pkey PRIMARY KEY (community_id);

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_community_id_key UNIQUE (user_id, community_id);

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_post_id_key UNIQUE (community_id, post_id);

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_user_id_key UNIQUE (event_id, user_id);

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.media_items
    ADD CONSTRAINT media_items_minio_object_name_key UNIQUE (minio_object_name);

ALTER TABLE ONLY public.media_items
    ADD CONSTRAINT media_items_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_post_id_key UNIQUE (user_id, post_id);

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_pkey PRIMARY KEY (post_id, media_id);

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_reply_id_key UNIQUE (user_id, reply_id);

ALTER TABLE ONLY public.reply_media
    ADD CONSTRAINT reply_media_pkey PRIMARY KEY (reply_id, media_id);

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_post_vote UNIQUE (user_id, post_id);

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_reply_vote UNIQUE (user_id, reply_id);

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (blocker_id, blocked_id);

ALTER TABLE ONLY public.user_device_tokens
    ADD CONSTRAINT user_device_tokens_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_pkey PRIMARY KEY (follower_id, following_id);

ALTER TABLE ONLY public.user_profile_picture
    ADD CONSTRAINT user_profile_picture_pkey PRIMARY KEY (user_id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);

CREATE INDEX community_id_graph_idx ON fiore."Community" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));

CREATE INDEX event_id_graph_idx ON fiore."Event" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));

CREATE INDEX post_id_graph_idx ON fiore."Post" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));

CREATE INDEX reply_id_graph_idx ON fiore."Reply" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));

CREATE INDEX user_id_graph_idx ON fiore."User" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));

CREATE INDEX idx_chat_message_media_media ON public.chat_message_media USING btree (media_id);

CREATE INDEX idx_chat_messages_community_id ON public.chat_messages USING btree (community_id) WHERE (community_id IS NOT NULL);

CREATE INDEX idx_chat_messages_event_id ON public.chat_messages USING btree (event_id) WHERE (event_id IS NOT NULL);

CREATE INDEX idx_chat_messages_timestamp ON public.chat_messages USING btree ("timestamp" DESC);

CREATE INDEX idx_communities_created_by ON public.communities USING btree (created_by);

CREATE INDEX idx_communities_fts ON public.communities USING gin (to_tsvector('english'::regconfig, ((COALESCE(name, ''::text) || ' '::text) || COALESCE(description, ''::text))));

CREATE INDEX idx_communities_interest ON public.communities USING btree (interest);

CREATE INDEX idx_communities_location ON public.communities USING gist (location);

CREATE INDEX idx_community_logo_media ON public.community_logo USING btree (media_id);

CREATE INDEX idx_event_participants_event_id ON public.event_participants USING btree (event_id);

CREATE INDEX idx_event_participants_user_id ON public.event_participants USING btree (user_id);

CREATE INDEX idx_events_community_id ON public.events USING btree (community_id);

CREATE INDEX idx_events_event_timestamp ON public.events USING btree (event_timestamp);

CREATE INDEX idx_events_event_timestamp_desc ON public.events USING btree (event_timestamp DESC);

CREATE INDEX idx_events_location_coords ON public.events USING gist (location_coords);

CREATE INDEX idx_followers_follower ON public.user_followers USING btree (follower_id);

CREATE INDEX idx_followers_following ON public.user_followers USING btree (following_id);

CREATE INDEX idx_media_items_minio_object ON public.media_items USING btree (minio_object_name);

CREATE INDEX idx_media_items_uploader ON public.media_items USING btree (uploader_user_id);

CREATE INDEX idx_notifications_actor ON public.notifications USING btree (actor_user_id);

CREATE INDEX idx_notifications_recipient_created ON public.notifications USING btree (recipient_user_id, created_at DESC);

CREATE INDEX idx_notifications_recipient_unread ON public.notifications USING btree (recipient_user_id, is_read, created_at DESC);

CREATE INDEX idx_notifications_related_entity ON public.notifications USING btree (related_entity_type, related_entity_id);

CREATE INDEX idx_post_media_media ON public.post_media USING btree (media_id);

CREATE INDEX idx_posts_created_at ON public.posts USING btree (created_at DESC);

CREATE INDEX idx_posts_fts ON public.posts USING gin (to_tsvector('english'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(content, ''::text))));

CREATE INDEX idx_posts_user_id ON public.posts USING btree (user_id);

CREATE INDEX idx_replies_created_at ON public.replies USING btree (created_at);

CREATE INDEX idx_replies_post_id ON public.replies USING btree (post_id);

CREATE INDEX idx_reply_media_media ON public.reply_media USING btree (media_id);

CREATE INDEX idx_user_blocks_blocked ON public.user_blocks USING btree (blocked_id);

CREATE INDEX idx_user_blocks_blocker ON public.user_blocks USING btree (blocker_id);

CREATE UNIQUE INDEX idx_user_device_tokens_token_platform ON public.user_device_tokens USING btree (device_token, platform);

CREATE INDEX idx_user_device_tokens_user_id ON public.user_device_tokens USING btree (user_id);

CREATE INDEX idx_user_profile_picture_media ON public.user_profile_picture USING btree (media_id);

CREATE INDEX idx_users_college ON public.users USING btree (college);

CREATE INDEX idx_users_fts ON public.users USING gin (to_tsvector('english'::regconfig, ((COALESCE(name, ''::text) || ' '::text) || COALESCE(username, ''::text))));

CREATE INDEX idx_users_interest ON public.users USING btree (interest);

CREATE INDEX idx_users_last_seen ON public.users USING btree (last_seen DESC NULLS LAST);

CREATE INDEX idx_users_location ON public.users USING gist (location);

CREATE INDEX idx_votes_on_post ON public.votes USING btree (post_id) WHERE (post_id IS NOT NULL);

CREATE INDEX idx_votes_on_reply ON public.votes USING btree (reply_id) WHERE (reply_id IS NOT NULL);

ALTER TABLE ONLY public.chat_message_media
    ADD CONSTRAINT chat_message_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.chat_message_media
    ADD CONSTRAINT chat_message_media_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.chat_messages(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.community_logo
    ADD CONSTRAINT community_logo_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.community_logo
    ADD CONSTRAINT community_logo_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.media_items
    ADD CONSTRAINT media_items_uploader_user_id_fkey FOREIGN KEY (uploader_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_recipient_user_id_fkey FOREIGN KEY (recipient_user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_parent_reply_id_fkey FOREIGN KEY (parent_reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.reply_media
    ADD CONSTRAINT reply_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.reply_media
    ADD CONSTRAINT reply_media_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_device_tokens
    ADD CONSTRAINT user_device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.user_profile_picture
    ADD CONSTRAINT user_profile_picture_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE RESTRICT;

ALTER TABLE ONLY public.user_profile_picture
    ADD CONSTRAINT user_profile_picture_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

