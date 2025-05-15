--
-- PostgreSQL database dump
--

-- Dumped from database version 15.12 (Ubuntu 15.12-1.pgdg24.04+1)
-- Dumped by pg_dump version 15.12 (Ubuntu 15.12-1.pgdg24.04+1)

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

--
-- Name: ag_catalog; Type: SCHEMA; Schema: -; Owner: -
--

-- CREATE SCHEMA ag_catalog;


--
-- Name: fiore; Type: SCHEMA; Schema: -; Owner: -
--

-- CREATE SCHEMA fiore;


--
-- Name: age; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS age WITH SCHEMA ag_catalog;


--
-- Name: EXTENSION age; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION age IS 'AGE database extension';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: device_platform; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.device_platform AS ENUM (
    'ios',
    'android',
    'web'
);


--
-- Name: notification_entity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.notification_entity_type AS ENUM (
    'user',
    'post',
    'reply',
    'community',
    'event'
);


--
-- Name: notification_type; Type: TYPE; Schema: public; Owner: -
--

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

--
-- Name: _ag_label_edge; Type: TABLE; Schema: fiore; Owner: -
--

--CREATE TABLE fiore._ag_label_edge (
--    id ag_catalog.graphid NOT NULL,
--    start_id ag_catalog.graphid NOT NULL,
--    end_id ag_catalog.graphid NOT NULL,
--    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
--);


--
-- Name: CREATED; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."CREATED" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: CREATED_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."CREATED_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: CREATED_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."CREATED_id_seq" OWNED BY fiore."CREATED".id;


--
-- Name: _ag_label_vertex; Type: TABLE; Schema: fiore; Owner: -
--

--CREATE TABLE fiore._ag_label_vertex (
--    id ag_catalog.graphid NOT NULL,
--    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
--);


--
-- Name: Community; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."Community" (
)
INHERITS (fiore._ag_label_vertex);


--
-- Name: Community_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."Community_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: Community_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."Community_id_seq" OWNED BY fiore."Community".id;


--
-- Name: Event; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."Event" (
)
INHERITS (fiore._ag_label_vertex);


--
-- Name: Event_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."Event_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: Event_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."Event_id_seq" OWNED BY fiore."Event".id;


--
-- Name: FAVORITED; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."FAVORITED" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: FAVORITED_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."FAVORITED_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: FAVORITED_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."FAVORITED_id_seq" OWNED BY fiore."FAVORITED".id;


--
-- Name: FOLLOWS; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."FOLLOWS" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: FOLLOWS_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."FOLLOWS_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: FOLLOWS_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."FOLLOWS_id_seq" OWNED BY fiore."FOLLOWS".id;


--
-- Name: HAS_POST; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."HAS_POST" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: HAS_POST_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."HAS_POST_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: HAS_POST_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."HAS_POST_id_seq" OWNED BY fiore."HAS_POST".id;


--
-- Name: MEMBER_OF; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."MEMBER_OF" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: MEMBER_OF_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."MEMBER_OF_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: MEMBER_OF_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."MEMBER_OF_id_seq" OWNED BY fiore."MEMBER_OF".id;


--
-- Name: PARTICIPATED_IN; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."PARTICIPATED_IN" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: PARTICIPATED_IN_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."PARTICIPATED_IN_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: PARTICIPATED_IN_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."PARTICIPATED_IN_id_seq" OWNED BY fiore."PARTICIPATED_IN".id;


--
-- Name: Post; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."Post" (
)
INHERITS (fiore._ag_label_vertex);


--
-- Name: Post_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."Post_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: Post_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."Post_id_seq" OWNED BY fiore."Post".id;


--
-- Name: REPLIED_TO; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."REPLIED_TO" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: REPLIED_TO_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."REPLIED_TO_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: REPLIED_TO_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."REPLIED_TO_id_seq" OWNED BY fiore."REPLIED_TO".id;


--
-- Name: Reply; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."Reply" (
)
INHERITS (fiore._ag_label_vertex);


--
-- Name: Reply_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."Reply_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: Reply_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."Reply_id_seq" OWNED BY fiore."Reply".id;


--
-- Name: User; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."User" (
)
INHERITS (fiore._ag_label_vertex);


--
-- Name: User_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."User_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: User_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."User_id_seq" OWNED BY fiore."User".id;


--
-- Name: VOTED; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."VOTED" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: VOTED_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."VOTED_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: VOTED_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."VOTED_id_seq" OWNED BY fiore."VOTED".id;


--
-- Name: WROTE; Type: TABLE; Schema: fiore; Owner: -
--

CREATE TABLE fiore."WROTE" (
)
INHERITS (fiore._ag_label_edge);


--
-- Name: WROTE_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore."WROTE_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: WROTE_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore."WROTE_id_seq" OWNED BY fiore."WROTE".id;


--
-- Name: _ag_label_edge_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

--CREATE SEQUENCE fiore._ag_label_edge_id_seq
--    START WITH 1
--    INCREMENT BY 1
--    NO MINVALUE
--    MAXVALUE 281474976710655
--    CACHE 1;


--
-- Name: _ag_label_edge_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

--ALTER SEQUENCE fiore._ag_label_edge_id_seq OWNED BY fiore._ag_label_edge.id;


--
-- Name: _ag_label_vertex_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

--CREATE SEQUENCE fiore._ag_label_vertex_id_seq
--    START WITH 1
--    INCREMENT BY 1
--    NO MINVALUE
--    MAXVALUE 281474976710655
--    CACHE 1;


--
-- Name: _ag_label_vertex_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

--ALTER SEQUENCE fiore._ag_label_vertex_id_seq OWNED BY fiore._ag_label_vertex.id;


--
-- Name: _label_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

--CREATE SEQUENCE fiore._label_id_seq
--    AS integer
--    START WITH 1
--    INCREMENT BY 1
--    NO MINVALUE
--    MAXVALUE 65535
--    CACHE 1
--    CYCLE;


--
-- Name: chat_message_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_message_media (
    message_id integer NOT NULL,
    media_id integer NOT NULL
);


--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_messages (
    id integer NOT NULL,
    community_id integer,
    event_id integer,
    user_id integer NOT NULL,
    content text NOT NULL,
    "timestamp" timestamp with time zone DEFAULT now(),
    CONSTRAINT chat_messages_check CHECK ((((community_id IS NOT NULL) AND (event_id IS NULL)) OR ((community_id IS NULL) AND (event_id IS NOT NULL))))
);


--
-- Name: chat_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;


--
-- Name: communities; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: COLUMN communities.location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.location IS 'Community''s primary geographic location (SRID 4326). Replaces old primary_location point.';


--
-- Name: COLUMN communities.location_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.location_address IS 'Community''s primary human-readable address.';


--
-- Name: communities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.communities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: communities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.communities_id_seq OWNED BY public.communities.id;


--
-- Name: community_logo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.community_logo (
    community_id integer NOT NULL,
    media_id integer NOT NULL,
    set_at timestamp with time zone DEFAULT now()
);


--
-- Name: community_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.community_members (
    id integer NOT NULL,
    user_id integer NOT NULL,
    community_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);


--
-- Name: community_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.community_members_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: community_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.community_members_id_seq OWNED BY public.community_members.id;


--
-- Name: community_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.community_posts (
    id integer NOT NULL,
    community_id integer NOT NULL,
    post_id integer NOT NULL,
    added_at timestamp with time zone DEFAULT now()
);


--
-- Name: community_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.community_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: community_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.community_posts_id_seq OWNED BY public.community_posts.id;


--
-- Name: event_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_participants (
    id integer NOT NULL,
    event_id integer NOT NULL,
    user_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);


--
-- Name: event_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_participants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_participants_id_seq OWNED BY public.event_participants.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: COLUMN events.location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.events.location IS 'Event''s human-readable address string.';


--
-- Name: COLUMN events.location_coords; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.events.location_coords IS 'Event''s geographic coordinates (SRID 4326).';


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: media_items; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: media_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_items_id_seq OWNED BY public.media_items.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: post_favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);


--
-- Name: post_favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.post_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: post_favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.post_favorites_id_seq OWNED BY public.post_favorites.id;


--
-- Name: post_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_media (
    post_id integer NOT NULL,
    media_id integer NOT NULL,
    display_order smallint DEFAULT 0
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    title character varying(255) NOT NULL
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: replies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.replies (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    parent_reply_id integer,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: replies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.replies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: replies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.replies_id_seq OWNED BY public.replies.id;


--
-- Name: reply_favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reply_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reply_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);


--
-- Name: reply_favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reply_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reply_favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reply_favorites_id_seq OWNED BY public.reply_favorites.id;


--
-- Name: reply_media; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reply_media (
    reply_id integer NOT NULL,
    media_id integer NOT NULL,
    display_order smallint DEFAULT 0
);


--
-- Name: user_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_blocks (
    blocker_id integer NOT NULL,
    blocked_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_blocker_not_blocked CHECK ((blocker_id <> blocked_id))
);


--
-- Name: user_device_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_device_tokens (
    id integer NOT NULL,
    user_id integer NOT NULL,
    device_token text NOT NULL,
    platform public.device_platform NOT NULL,
    last_used_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_device_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_device_tokens_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_device_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_device_tokens_id_seq OWNED BY public.user_device_tokens.id;


--
-- Name: user_followers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_followers (
    follower_id integer NOT NULL,
    following_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: user_profile_picture; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_profile_picture (
    user_id integer NOT NULL,
    media_id integer NOT NULL,
    set_at timestamp with time zone DEFAULT now()
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

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


--
-- Name: COLUMN users.location; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.location IS 'User''s current geographic location (SRID 4326). Replaces old current_location point.';


--
-- Name: COLUMN users.location_last_updated; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.location_last_updated IS 'Timestamp of when the location was last updated.';


--
-- Name: COLUMN users.location_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.location_address IS 'User''s current human-readable address.';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.votes (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer,
    reply_id integer,
    vote_type boolean NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT check_vote_target CHECK ((((post_id IS NOT NULL) AND (reply_id IS NULL)) OR ((post_id IS NULL) AND (reply_id IS NOT NULL))))
);


--
-- Name: votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.votes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.votes_id_seq OWNED BY public.votes.id;


--
-- Name: CREATED id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."CREATED" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'CREATED'::name))::integer, nextval('fiore."CREATED_id_seq"'::regclass));


--
-- Name: CREATED properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."CREATED" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: Community id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Community" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Community'::name))::integer, nextval('fiore."Community_id_seq"'::regclass));


--
-- Name: Community properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Community" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: Event id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Event" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Event'::name))::integer, nextval('fiore."Event_id_seq"'::regclass));


--
-- Name: Event properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Event" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: FAVORITED id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."FAVORITED" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'FAVORITED'::name))::integer, nextval('fiore."FAVORITED_id_seq"'::regclass));


--
-- Name: FAVORITED properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."FAVORITED" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: FOLLOWS id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."FOLLOWS" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'FOLLOWS'::name))::integer, nextval('fiore."FOLLOWS_id_seq"'::regclass));


--
-- Name: FOLLOWS properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."FOLLOWS" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: HAS_POST id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."HAS_POST" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'HAS_POST'::name))::integer, nextval('fiore."HAS_POST_id_seq"'::regclass));


--
-- Name: HAS_POST properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."HAS_POST" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: MEMBER_OF id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."MEMBER_OF" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'MEMBER_OF'::name))::integer, nextval('fiore."MEMBER_OF_id_seq"'::regclass));


--
-- Name: MEMBER_OF properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."MEMBER_OF" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: PARTICIPATED_IN id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."PARTICIPATED_IN" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'PARTICIPATED_IN'::name))::integer, nextval('fiore."PARTICIPATED_IN_id_seq"'::regclass));


--
-- Name: PARTICIPATED_IN properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."PARTICIPATED_IN" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: Post id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Post" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Post'::name))::integer, nextval('fiore."Post_id_seq"'::regclass));


--
-- Name: Post properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Post" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: REPLIED_TO id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."REPLIED_TO" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'REPLIED_TO'::name))::integer, nextval('fiore."REPLIED_TO_id_seq"'::regclass));


--
-- Name: REPLIED_TO properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."REPLIED_TO" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: Reply id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Reply" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'Reply'::name))::integer, nextval('fiore."Reply_id_seq"'::regclass));


--
-- Name: Reply properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."Reply" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: User id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."User" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'User'::name))::integer, nextval('fiore."User_id_seq"'::regclass));


--
-- Name: User properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."User" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: VOTED id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."VOTED" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'VOTED'::name))::integer, nextval('fiore."VOTED_id_seq"'::regclass));


--
-- Name: VOTED properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."VOTED" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: WROTE id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."WROTE" ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, 'WROTE'::name))::integer, nextval('fiore."WROTE_id_seq"'::regclass));


--
-- Name: WROTE properties; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore."WROTE" ALTER COLUMN properties SET DEFAULT ag_catalog.agtype_build_map();


--
-- Name: _ag_label_edge id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore._ag_label_edge ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, '_ag_label_edge'::name))::integer, nextval('fiore._ag_label_edge_id_seq'::regclass));


--
-- Name: _ag_label_vertex id; Type: DEFAULT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore._ag_label_vertex ALTER COLUMN id SET DEFAULT ag_catalog._graphid((ag_catalog._label_id('fiore'::name, '_ag_label_vertex'::name))::integer, nextval('fiore._ag_label_vertex_id_seq'::regclass));


--
-- Name: chat_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);


--
-- Name: communities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communities ALTER COLUMN id SET DEFAULT nextval('public.communities_id_seq'::regclass);


--
-- Name: community_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_members ALTER COLUMN id SET DEFAULT nextval('public.community_members_id_seq'::regclass);


--
-- Name: community_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_posts ALTER COLUMN id SET DEFAULT nextval('public.community_posts_id_seq'::regclass);


--
-- Name: event_participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_participants ALTER COLUMN id SET DEFAULT nextval('public.event_participants_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: media_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_items ALTER COLUMN id SET DEFAULT nextval('public.media_items_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: post_favorites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_favorites ALTER COLUMN id SET DEFAULT nextval('public.post_favorites_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: replies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replies ALTER COLUMN id SET DEFAULT nextval('public.replies_id_seq'::regclass);


--
-- Name: reply_favorites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_favorites ALTER COLUMN id SET DEFAULT nextval('public.reply_favorites_id_seq'::regclass);


--
-- Name: user_device_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_device_tokens ALTER COLUMN id SET DEFAULT nextval('public.user_device_tokens_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes ALTER COLUMN id SET DEFAULT nextval('public.votes_id_seq'::regclass);


--
-- Data for Name: ag_graph; Type: TABLE DATA; Schema: ag_catalog; Owner: -
--

--COPY ag_catalog.ag_graph (graphid, name, namespace) FROM stdin;
--25916	fiore	fiore
--\.


--
-- Data for Name: ag_label; Type: TABLE DATA; Schema: ag_catalog; Owner: -
--

--COPY ag_catalog.ag_label (name, graph, id, kind, relation, seq_name) FROM stdin;
--_ag_label_vertex	25916	1	v	fiore._ag_label_vertex	_ag_label_vertex_id_seq
--_ag_label_edge	25916	2	e	fiore._ag_label_edge	_ag_label_edge_id_seq
--User	25916	3	v	fiore."User"	User_id_seq
--Community	25916	4	v	fiore."Community"	Community_id_seq
--Post	25916	5	v	fiore."Post"	Post_id_seq
--Reply	25916	6	v	fiore."Reply"	Reply_id_seq
--Event	25916	7	v	fiore."Event"	Event_id_seq
--FOLLOWS	25916	8	e	fiore."FOLLOWS"	FOLLOWS_id_seq
--MEMBER_OF	25916	9	e	fiore."MEMBER_OF"	MEMBER_OF_id_seq
--WROTE	25916	10	e	fiore."WROTE"	WROTE_id_seq
--HAS_POST	25916	11	e	fiore."HAS_POST"	HAS_POST_id_seq
--PARTICIPATED_IN	25916	12	e	fiore."PARTICIPATED_IN"	PARTICIPATED_IN_id_seq
--VOTED	25916	13	e	fiore."VOTED"	VOTED_id_seq
--FAVORITED	25916	14	e	fiore."FAVORITED"	FAVORITED_id_seq
--REPLIED_TO	25916	15	e	fiore."REPLIED_TO"	REPLIED_TO_id_seq
--CREATED	25916	16	e	fiore."CREATED"	CREATED_id_seq
--\.


--
-- Data for Name: CREATED; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."CREATED" (id, start_id, end_id, properties) FROM stdin;
4503599627370497	844424930131980	1125899906842625	{}
4503599627370498	844424930131969	1125899906842626	{}
4503599627370499	844424930131970	1125899906842627	{}
4503599627370500	844424930131979	1125899906842628	{}
4503599627370501	844424930131980	1125899906842629	{}
4503599627370502	844424930131969	1125899906842630	{}
4503599627370503	844424930131979	1125899906842631	{}
4503599627370504	844424930131979	1125899906842632	{}
4503599627370505	844424930131979	1125899906842633	{}
4503599627370506	844424930131979	1125899906842634	{}
4503599627370507	844424930131978	1125899906842635	{}
4503599627370508	844424930131980	1970324836974593	{}
4503599627370509	844424930131978	1970324836974594	{}
4503599627370510	844424930131979	1970324836974595	{}
4503599627370511	844424930131978	1970324836974596	{}
4503599627370512	844424930131978	1970324836974597	{}
4503599627370513	844424930131979	1970324836974598	{}
4503599627370515	844424930131980	1970324836974600	{}
4503599627370516	844424930131980	1970324836974601	{}
4503599627370517	844424930131980	1970324836974602	{}
4503599627370518	844424930131980	1970324836974603	{}
4503599627370519	844424930131980	1970324836974604	{}
4503599627370520	844424930131980	1970324836974605	{}
4503599627370521	844424930131980	1970324836974606	{}
4503599627370522	844424930131978	1970324836974607	{}
4503599627370523	844424930131980	1970324836974608	{}
4503599627370524	844424930131980	1970324836974609	{}
4503599627370525	844424930131980	1970324836974610	{}
4503599627370526	844424930131980	1970324836974611	{}
4503599627370527	844424930131980	1970324836974612	{}
4503599627370528	844424930131980	1970324836974613	{}
4503599627370529	844424930131980	1970324836974614	{}
4503599627370530	844424930131980	1125899906842636	{}
4503599627370531	844424930131980	1970324836974615	{}
4503599627370532	844424930131980	1125899906842637	{}
4503599627370577	844424930131980	1125899906842661	{}
4503599627370582	844424930131980	1970324836974638	{}
\.


--
-- Data for Name: Community; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."Community" (id, properties) FROM stdin;
1125899906842625	{"id": 1, "name": "Tech Enthusiasts", "interest": "Tech"}
1125899906842626	{"id": 2, "name": "Gaming Hub", "interest": "Gaming"}
1125899906842627	{"id": 3, "name": "Book Readers", "interest": "Other"}
1125899906842628	{"id": 12, "name": "Kanisk Fan club", "interest": "Social"}
1125899906842629	{"id": 4, "name": "Fitness Freaks", "interest": "Sports"}
1125899906842630	{"id": 5, "name": "AI & ML Researchers", "interest": "Science"}
1125899906842631	{"id": 11, "name": "Star Wars", "interest": "Other"}
1125899906842632	{"id": 13, "name": "IPL Betting", "interest": "Sports"}
1125899906842633	{"id": 14, "name": "White Girl Song Fan Club", "interest": "Music"}
1125899906842634	{"id": 15, "name": "Content Creators", "interest": "Social"}
1125899906842635	{"id": 16, "name": "lol", "interest": "Science"}
1125899906842636	{"id": 120, "name": "Pytest Community 175705063625", "interest": "Music"}
1125899906842637	{"id": 121, "name": "Pytest Community 105953369530", "interest": "Music"}
1125899906842661	{"id": 145, "name": "Pytest Community 152730452783", "interest": "Music"}
\.


--
-- Data for Name: Event; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."Event" (id, properties) FROM stdin;
1970324836974593	{"id": 1, "title": "Tech Talk: Future of AI", "event_timestamp": "2025-04-03T01:09:14.605861+05:30"}
1970324836974594	{"id": 2, "title": "Weekly Coding Meetup", "event_timestamp": "2025-04-01T11:09:14.605861+05:30"}
1970324836974595	{"id": 3, "title": "Morning Yoga Session", "event_timestamp": "2025-03-31T13:09:14.605861+05:30"}
1970324836974596	{"id": 4, "title": "lol", "event_timestamp": "2025-04-01T12:00:00+05:30"}
1970324836974597	{"id": 6, "title": "xxx", "event_timestamp": "2025-04-03T11:54:00+05:30"}
1970324836974598	{"id": 8, "title": "csk vs rcb", "event_timestamp": "2025-04-04T22:48:00+05:30"}
1970324836974600	{"id": 345, "title": "Test Event w/ Image 145129", "event_timestamp": "2025-05-11T09:21:29.410244+00:00"}
1970324836974601	{"id": 346, "title": "Test Event w/ Image 200358", "event_timestamp": "2025-05-11T14:33:58.301056+00:00"}
1970324836974602	{"id": 347, "title": "Test Event w/ Img 215045", "event_timestamp": "2025-05-11T16:20:45.864876+00:00"}
1970324836974603	{"id": 348, "title": "Test Event w/ Img 215651", "event_timestamp": "2025-05-11T16:26:51.318174+00:00"}
1970324836974604	{"id": 349, "title": "Test Event w/ Img 215935", "event_timestamp": "2025-05-11T16:29:35.103493+00:00"}
1970324836974638	{"id": 383, "title": "Pytest Event w/ Img 155020", "event_timestamp": "2025-05-21T10:20:20.458144+00:00"}
1970324836974605	{"id": 350, "title": "Test Event w/ Img 093650", "event_timestamp": "2025-05-12T04:06:50.188771+00:00"}
1970324836974606	{"id": 351, "title": "Test Event w/ Img 115011", "event_timestamp": "2025-05-12T06:20:11.361152+00:00"}
1970324836974607	{"id": 352, "title": "Test Event w/ Img 115154", "event_timestamp": "2025-05-12T06:21:54.878530+00:00"}
1970324836974608	{"id": 353, "title": "Test Event w/ Img 155108", "event_timestamp": "2025-05-12T10:21:08.259810+00:00"}
1970324836974609	{"id": 354, "title": "Test Event w/ Img 160130", "event_timestamp": "2025-05-12T10:31:30.260423+00:00"}
1970324836974610	{"id": 355, "title": "Test Event w/ Img 165324", "event_timestamp": "2025-05-12T11:23:24.749299+00:00"}
1970324836974611	{"id": 356, "title": "Test Event w/ Img 163149", "event_timestamp": "2025-05-13T11:01:49.492749+00:00"}
1970324836974612	{"id": 357, "title": "Test Event w/ Img 171107", "event_timestamp": "2025-05-13T11:41:07.326515+00:00"}
1970324836974613	{"id": 358, "title": "Test Event w/ Img 174239", "event_timestamp": "2025-05-13T12:12:39.003402+00:00"}
1970324836974614	{"id": 359, "title": "Test Event w/ Img 174356", "event_timestamp": "2025-05-13T12:13:56.825738+00:00"}
1970324836974615	{"id": 360, "title": "Test Event w/ Img 092016", "event_timestamp": "2025-05-14T03:50:16.496348+00:00"}
\.


--
-- Data for Name: FAVORITED; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."FAVORITED" (id, start_id, end_id, properties) FROM stdin;
3940649673949185	844424930131969	1407374883553281	{}
3940649673949186	844424930131970	1407374883553282	{}
3940649673949187	844424930131980	1407374883553283	{}
3940649673949188	844424930131970	1407374883553287	{}
3940649673949189	844424930131969	1407374883553290	{}
3940649673949190	844424930131970	1688849860263937	{}
3940649673949191	844424930131980	1688849860263938	{}
3940649673949192	844424930131969	1688849860263939	{}
3940649673949193	844424930131980	1688849860263940	{}
3940649673949194	844424930131970	1688849860263941	{}
3940649673949195	844424930131969	1688849860263942	{}
3940649673949196	844424930131980	1688849860263943	{}
\.


--
-- Data for Name: FOLLOWS; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."FOLLOWS" (id, start_id, end_id, properties) FROM stdin;
2251799813685249	844424930131980	844424930131969	{}
2251799813685250	844424930131980	844424930131970	{}
2251799813685251	844424930131969	844424930131980	{}
2251799813685252	844424930131970	844424930131980	{}
2251799813685253	844424930131978	844424930131980	{}
2251799813685254	844424930131979	844424930131980	{}
2251799813685255	844424930131969	844424930131970	{}
2251799813685256	844424930131970	844424930131978	{}
2251799813685258	844424930131980	844424930131978	{}
\.


--
-- Data for Name: HAS_POST; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."HAS_POST" (id, start_id, end_id, properties) FROM stdin;
3096224743817217	1125899906842625	1407374883553281	{}
3096224743817218	1125899906842625	1407374883553282	{}
3096224743817219	1125899906842626	1407374883553283	{}
3096224743817220	1125899906842626	1407374883553284	{}
3096224743817221	1125899906842627	1407374883553285	{}
3096224743817222	1125899906842627	1407374883553286	{}
3096224743817223	1125899906842629	1407374883553287	{}
3096224743817224	1125899906842629	1407374883553288	{}
3096224743817225	1125899906842630	1407374883553289	{}
3096224743817226	1125899906842630	1407374883553290	{}
3096224743817453	1125899906842625	1407374883553428	{}
3096224743817373	1125899906842625	1407374883553392	{}
3096224743817457	1125899906842625	1407374883553430	{}
3096224743817377	1125899906842625	1407374883553394	{}
3096224743817460	1125899906842625	1407374883553290	{}
3096224743817381	1125899906842625	1407374883553396	{}
3096224743817461	1125899906842625	1407374883553432	{}
3096224743817385	1125899906842625	1407374883553398	{}
3096224743817389	1125899906842625	1407374883553400	{}
3096224743817393	1125899906842625	1407374883553402	{}
3096224743817250	1125899906842625	1407374883553303	{}
3096224743817252	1125899906842625	1407374883553304	{}
3096224743817254	1125899906842625	1407374883553305	{}
3096224743817256	1125899906842625	1407374883553306	{}
3096224743817397	1125899906842625	1407374883553404	{}
3096224743817258	1125899906842635	1407374883553307	{}
3096224743817260	1125899906842625	1407374883553308	{}
3096224743817293	1125899906842625	1407374883553341	{}
3096224743817294	1125899906842625	1407374883553342	{}
3096224743817295	1125899906842625	1407374883553343	{}
3096224743817296	1125899906842625	1407374883553344	{}
3096224743817297	1125899906842625	1407374883553345	{}
3096224743817298	1125899906842625	1407374883553346	{}
3096224743817299	1125899906842625	1407374883553347	{}
3096224743817300	1125899906842625	1407374883553348	{}
3096224743817301	1125899906842625	1407374883553349	{}
3096224743817302	1125899906842625	1407374883553350	{}
3096224743817303	1125899906842625	1407374883553351	{}
3096224743817304	1125899906842625	1407374883553352	{}
3096224743817305	1125899906842625	1407374883553353	{}
3096224743817306	1125899906842625	1407374883553354	{}
3096224743817307	1125899906842625	1407374883553355	{}
3096224743817308	1125899906842625	1407374883553356	{}
3096224743817309	1125899906842625	1407374883553357	{}
3096224743817310	1125899906842625	1407374883553358	{}
3096224743817311	1125899906842625	1407374883553359	{}
3096224743817312	1125899906842625	1407374883553360	{}
3096224743817401	1125899906842625	1407374883553406	{}
3096224743817317	1125899906842625	1407374883553361	{}
3096224743817318	1125899906842625	1407374883553362	{}
3096224743817319	1125899906842625	1407374883553363	{}
3096224743817405	1125899906842625	1407374883553408	{}
3096224743817322	1125899906842625	1407374883553364	{}
3096224743817323	1125899906842625	1407374883553365	{}
3096224743817324	1125899906842625	1407374883553366	{}
3096224743817327	1125899906842625	1407374883553367	{}
3096224743817329	1125899906842625	1407374883553369	{}
3096224743817330	1125899906842625	1407374883553370	{}
3096224743817409	1125899906842625	1407374883553410	{}
3096224743817333	1125899906842625	1407374883553371	{}
3096224743817413	1125899906842625	1407374883553412	{}
3096224743817337	1125899906842625	1407374883553373	{}
3096224743817338	1125899906842625	1407374883553375	{}
3096224743817341	1125899906842625	1407374883553376	{}
3096224743817342	1125899906842625	1407374883553377	{}
3096224743817417	1125899906842625	1407374883553414	{}
3096224743817345	1125899906842625	1407374883553378	{}
3096224743817349	1125899906842625	1407374883553380	{}
3096224743817421	1125899906842625	1407374883553416	{}
3096224743817353	1125899906842625	1407374883553382	{}
3096224743817425	1125899906842625	1407374883553418	{}
3096224743817429	1125899906842625	1407374883553420	{}
3096224743817361	1125899906842625	1407374883553386	{}
3096224743817365	1125899906842625	1407374883553388	{}
3096224743817369	1125899906842625	1407374883553390	{}
3096224743817441	1125899906842625	1407374883553424	{}
3096224743817445	1125899906842625	1407374883553426	{}
\.


--
-- Data for Name: MEMBER_OF; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."MEMBER_OF" (id, start_id, end_id, properties) FROM stdin;
2533274790395906	844424930131969	1125899906842625	{}
2533274790395907	844424930131970	1125899906842625	{}
2533274790395908	844424930131980	1125899906842626	{}
2533274790395909	844424930131969	1125899906842627	{}
2533274790395910	844424930131970	1125899906842627	{}
2533274790395911	844424930131980	1125899906842629	{}
2533274790395912	844424930131969	1125899906842630	{}
2533274790395913	844424930131982	1125899906842629	{}
2533274790395914	844424930131979	1125899906842629	{}
2533274790395915	844424930131980	1125899906842628	{}
2533274790395916	844424930131979	1125899906842631	{}
2533274790395917	844424930131979	1125899906842628	{}
2533274790395918	844424930131979	1125899906842632	{}
2533274790395919	844424930131978	1125899906842628	{}
2533274790395920	844424930131978	1125899906842632	{}
2533274790395922	844424930131980	1125899906842633	{}
2533274790395924	844424930131978	1125899906842629	{}
2533274790395925	844424930131977	1125899906842629	{}
2533274790395926	844424930131982	1125899906842635	{}
2533274790395927	844424930131977	1125899906842632	{}
2533274790395928	844424930131979	1125899906842633	{}
2533274790395929	844424930131978	1125899906842633	{}
2533274790395930	844424930131978	1125899906842634	{}
2533274790395931	844424930131978	1125899906842626	{}
2533274790395932	844424930131978	1125899906842630	{}
2533274790395933	844424930131980	1125899906842635	{}
2533274790395934	844424930131980	1125899906842632	{}
2533274790396073	844424930131980	1125899906842661	{}
2533274790396021	844424930131980	1125899906842636	{}
2533274790396024	844424930131980	1125899906842637	{}
\.


--
-- Data for Name: PARTICIPATED_IN; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."PARTICIPATED_IN" (id, start_id, end_id, properties) FROM stdin;
3377699720527875	844424930131979	1970324836974593	{}
3377699720527876	844424930131978	1970324836974594	{}
3377699720527877	844424930131979	1970324836974595	{}
3377699720527878	844424930131978	1970324836974596	{}
3377699720527879	844424930131980	1970324836974597	{}
3377699720527880	844424930131978	1970324836974597	{}
3377699720527881	844424930131979	1970324836974598	{}
3377699720527942	844424930131980	1970324836974602	{}
\.


--
-- Data for Name: Post; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."Post" (id, properties) FROM stdin;
1407374883553281	{"id": 1, "title": "Latest in Tech", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553282	{"id": 2, "title": "Quantum Computing", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553283	{"id": 3, "title": "Best FPS Games", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553284	{"id": 4, "title": "Gaming Tournaments", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553285	{"id": 5, "title": "Must-Read Books", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553286	{"id": 6, "title": "Fantasy vs Sci-Fi", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553287	{"id": 7, "title": "Best Home Workouts", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553288	{"id": 8, "title": "Keto vs Vegan", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553289	{"id": 9, "title": "Neural Networks Explained", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553290	{"id": 10, "title": "AI Ethics", "created_at": "2025-03-05T08:59:17.753175+05:30"}
1407374883553291	{"id": 32, "title": "Test Post", "created_at": "2025-03-12T09:16:53.269166+05:30"}
1407374883553292	{"id": 37, "title": "Test Post", "created_at": "2025-03-12T09:24:11.810475+05:30"}
1407374883553293	{"id": 41, "title": "Test Post", "created_at": "2025-03-12T09:26:45.649699+05:30"}
1407374883553294	{"id": 42, "title": "Test Post", "created_at": "2025-03-12T09:26:48.303579+05:30"}
1407374883553295	{"id": 43, "title": "Test Post", "created_at": "2025-03-12T09:26:49.093318+05:30"}
1407374883553296	{"id": 44, "title": "Test Post", "created_at": "2025-03-12T09:28:10.649226+05:30"}
1407374883553297	{"id": 45, "title": "lol", "created_at": "2025-03-13T10:17:20.816993+05:30"}
1407374883553298	{"id": 46, "title": "cucici", "created_at": "2025-03-19T05:18:08.204896+05:30"}
1407374883553299	{"id": 47, "title": "Grok", "created_at": "2025-03-21T19:47:24.971766+05:30"}
1407374883553303	{"id": 52, "title": "Test Post 2025-05-04 00:35:08.314088", "created_at": "2025-05-04T00:35:08.330567+05:30"}
1407374883553304	{"id": 53, "title": "Test Post 2025-05-04 00:45:32.357097", "created_at": "2025-05-04T00:45:32.374212+05:30"}
1407374883553305	{"id": 54, "title": "Test Post 2025-05-04 01:19:35.418435", "created_at": "2025-05-04T01:19:35.437882+05:30"}
1407374883553306	{"id": 55, "title": "Test Post 2025-05-04 01:20:00.228456", "created_at": "2025-05-04T01:20:00.246311+05:30"}
1407374883553307	{"id": 56, "title": "Test Post 2025-05-04 01:34:53.375493", "created_at": "2025-05-04T01:34:53.393773+05:30"}
1407374883553308	{"id": 57, "title": "Test Post 2025-05-04 01:41:00.938752", "created_at": "2025-05-04T01:41:00.956535+05:30"}
1407374883553341	{"id": 90, "title": "Test Post 2025-05-04 12:44:38.113197", "created_at": "2025-05-04T12:44:38.130397+05:30"}
1407374883553342	{"id": 91, "title": "Test Post Multi-Media 2025-05-04 13:26:44.634045", "created_at": "2025-05-04T13:26:44.650481+05:30"}
1407374883553343	{"id": 92, "title": "Test Post Multi-Media 2025-05-04 14:51:30.728862", "created_at": "2025-05-04T14:51:30.744853+05:30"}
1407374883553344	{"id": 93, "title": "Test Post Multi-Media 2025-05-04 20:03:59.889143", "created_at": "2025-05-04T20:03:59.908235+05:30"}
1407374883553345	{"id": 96, "title": "Test Post Multi-Media 2025-05-04 21:05:17.429623", "created_at": "2025-05-04T21:05:17.446385+05:30"}
1407374883553346	{"id": 97, "title": "Test Post Multi-Media 2025-05-04 21:07:27.752442", "created_at": "2025-05-04T21:07:27.769258+05:30"}
1407374883553347	{"id": 98, "title": "Test Post Multi-Media 2025-05-04 21:08:12.582754", "created_at": "2025-05-04T21:08:12.599386+05:30"}
1407374883553348	{"id": 99, "title": "Test Post Multi-Media 2025-05-04 21:33:45.328819", "created_at": "2025-05-04T21:33:45.346400+05:30"}
1407374883553349	{"id": 100, "title": "Test Post Multi-Media 2025-05-04 21:40:47.251353", "created_at": "2025-05-04T21:40:47.277436+05:30"}
1407374883553350	{"id": 101, "title": "Test Post Multi-Media 2025-05-04 21:42:32.319465", "created_at": "2025-05-04T21:42:32.335466+05:30"}
1407374883553351	{"id": 102, "title": "Test Post Multi-Media 2025-05-04 21:50:46.997338", "created_at": "2025-05-04T21:50:47.013820+05:30"}
1407374883553352	{"id": 103, "title": "Test Post Multi-Media 2025-05-04 21:56:52.757407", "created_at": "2025-05-04T21:56:52.773619+05:30"}
1407374883553353	{"id": 104, "title": "Test Post Multi-Media 2025-05-04 21:59:37.479717", "created_at": "2025-05-04T21:59:37.495276+05:30"}
1407374883553354	{"id": 105, "title": "Test Post Multi-Media 2025-05-05 09:36:53.488962", "created_at": "2025-05-05T09:36:53.504064+05:30"}
1407374883553355	{"id": 106, "title": "Test Post Multi-Media 2025-05-05 11:50:14.791648", "created_at": "2025-05-05T11:50:14.807717+05:30"}
1407374883553356	{"id": 107, "title": "Test Post Multi-Media 2025-05-05 11:51:58.030456", "created_at": "2025-05-05T11:51:58.050094+05:30"}
1407374883553357	{"id": 108, "title": "WS Test Post 1746426593", "created_at": "2025-05-05T11:59:53.399903+05:30"}
1407374883553358	{"id": 109, "title": "Test Post Multi-Media 2025-05-05 15:51:11.374682", "created_at": "2025-05-05T15:51:11.393963+05:30"}
1407374883553359	{"id": 110, "title": "Test Post Multi-Media 2025-05-05 16:01:33.947161", "created_at": "2025-05-05T16:01:33.967182+05:30"}
1407374883553360	{"id": 111, "title": "Test Post Multi-Media 2025-05-05 16:53:28.133066", "created_at": "2025-05-05T16:53:28.152359+05:30"}
1407374883553361	{"id": 112, "title": "Pytest Post NoMedia 161224", "created_at": "2025-05-06T16:12:24.743917+05:30"}
1407374883553362	{"id": 113, "title": "Pytest Post MultiMedia 161224", "created_at": "2025-05-06T16:12:24.786576+05:30"}
1407374883553363	{"id": 114, "title": "Test Post Multi-Media 2025-05-06 16:32:08.314181", "created_at": "2025-05-06T16:32:08.335287+05:30"}
1407374883553364	{"id": 115, "title": "Pytest Post NoMedia 164518", "created_at": "2025-05-06T16:45:18.719773+05:30"}
1407374883553400	{"id": 151, "title": "Pytest Post NoMedia 125153", "created_at": "2025-05-07T12:51:54.000638+05:30"}
1407374883553365	{"id": 116, "title": "Pytest Post MultiMedia 164518", "created_at": "2025-05-06T16:45:18.761372+05:30"}
1407374883553366	{"id": 117, "title": "Test Post Multi-Media 2025-05-06 17:11:10.662190", "created_at": "2025-05-06T17:11:10.682421+05:30"}
1407374883553367	{"id": 118, "title": "Pytest Post NoMedia 171200", "created_at": "2025-05-06T17:12:00.745882+05:30"}
1407374883553402	{"id": 153, "title": "Pytest Post NoMedia 125527", "created_at": "2025-05-07T12:55:27.176102+05:30"}
1407374883553369	{"id": 120, "title": "Test Post Multi-Media 2025-05-06 17:42:42.713217", "created_at": "2025-05-06T17:42:42.738487+05:30"}
1407374883553370	{"id": 121, "title": "Test Post Multi-Media 2025-05-06 17:43:59.968147", "created_at": "2025-05-06T17:43:59.987437+05:30"}
1407374883553371	{"id": 122, "title": "Pytest Post NoMedia 174420", "created_at": "2025-05-06T17:44:20.949636+05:30"}
1407374883553404	{"id": 155, "title": "Pytest Post NoMedia 125850", "created_at": "2025-05-07T12:58:50.814973+05:30"}
1407374883553373	{"id": 124, "title": "Pytest Post NoMedia 175706", "created_at": "2025-05-06T17:57:06.838490+05:30"}
1407374883553406	{"id": 157, "title": "Pytest Post NoMedia 130133", "created_at": "2025-05-07T13:01:33.144714+05:30"}
1407374883553375	{"id": 126, "title": "Test Post Multi-Media 2025-05-07 09:20:20.703996", "created_at": "2025-05-07T09:20:20.720609+05:30"}
1407374883553376	{"id": 127, "title": "Pytest Post NoMedia 105955", "created_at": "2025-05-07T10:59:55.373737+05:30"}
1407374883553377	{"id": 128, "title": "Pytest Post MultiMedia 105955", "created_at": "2025-05-07T10:59:55.415321+05:30"}
1407374883553408	{"id": 159, "title": "Pytest Post NoMedia 130457", "created_at": "2025-05-07T13:04:57.439710+05:30"}
1407374883553378	{"id": 129, "title": "Pytest Post NoMedia 112245", "created_at": "2025-05-07T11:22:45.943304+05:30"}
1407374883553380	{"id": 131, "title": "Pytest Post NoMedia 113635", "created_at": "2025-05-07T11:36:35.399807+05:30"}
1407374883553410	{"id": 161, "title": "Pytest Post NoMedia 130934", "created_at": "2025-05-07T13:09:34.688205+05:30"}
1407374883553382	{"id": 133, "title": "Pytest Post NoMedia 114632", "created_at": "2025-05-07T11:46:32.097582+05:30"}
1407374883553412	{"id": 163, "title": "Pytest Post NoMedia 131235", "created_at": "2025-05-07T13:12:36.016526+05:30"}
1407374883553414	{"id": 165, "title": "Pytest Post NoMedia 131553", "created_at": "2025-05-07T13:15:53.687220+05:30"}
1407374883553386	{"id": 137, "title": "Pytest Post NoMedia 122232", "created_at": "2025-05-07T12:22:32.503252+05:30"}
1407374883553416	{"id": 167, "title": "Pytest Post NoMedia 131846", "created_at": "2025-05-07T13:18:46.524700+05:30"}
1407374883553388	{"id": 139, "title": "Pytest Post NoMedia 122711", "created_at": "2025-05-07T12:27:11.980704+05:30"}
1407374883553390	{"id": 141, "title": "Pytest Post NoMedia 123101", "created_at": "2025-05-07T12:31:01.612428+05:30"}
1407374883553418	{"id": 169, "title": "Pytest Post NoMedia 132303", "created_at": "2025-05-07T13:23:03.065875+05:30"}
1407374883553392	{"id": 143, "title": "Pytest Post NoMedia 123324", "created_at": "2025-05-07T12:33:24.592537+05:30"}
1407374883553420	{"id": 171, "title": "Pytest Post NoMedia 133447", "created_at": "2025-05-07T13:34:47.055145+05:30"}
1407374883553394	{"id": 145, "title": "Pytest Post NoMedia 123802", "created_at": "2025-05-07T12:38:02.480895+05:30"}
1407374883553396	{"id": 147, "title": "Pytest Post NoMedia 124348", "created_at": "2025-05-07T12:43:48.101764+05:30"}
1407374883553398	{"id": 149, "title": "Pytest Post NoMedia 124721", "created_at": "2025-05-07T12:47:21.610913+05:30"}
1407374883553424	{"id": 175, "title": "Pytest Post NoMedia 154009", "created_at": "2025-05-07T15:40:09.585683+05:30"}
1407374883553426	{"id": 177, "title": "Pytest Post NoMedia 154254", "created_at": "2025-05-07T15:42:54.727589+05:30"}
1407374883553428	{"id": 179, "title": "Pytest Post NoMedia 155519", "created_at": "2025-05-07T15:55:19.391672+05:30"}
1407374883553430	{"id": 181, "title": "Pytest Post NoMedia 160506", "created_at": "2025-05-07T16:05:06.848110+05:30"}
1407374883553432	{"id": 183, "title": "Pytest Post NoMedia 161008", "created_at": "2025-05-07T16:10:08.057146+05:30"}
\.


--
-- Data for Name: REPLIED_TO; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."REPLIED_TO" (id, start_id, end_id, properties) FROM stdin;
4222124650659841	1688849860263937	1407374883553281	{}
4222124650659842	1688849860263938	1407374883553281	{}
4222124650659843	1688849860263939	1407374883553282	{}
4222124650659844	1688849860263940	1407374883553282	{}
4222124650659845	1688849860263941	1407374883553283	{}
4222124650659846	1688849860263942	1407374883553283	{}
4222124650659847	1688849860263943	1407374883553285	{}
4222124650659848	1688849860263944	1407374883553285	{}
4222124650659849	1688849860263945	1407374883553287	{}
4222124650659850	1688849860263946	1407374883553287	{}
4222124650659851	1688849860263947	1407374883553290	{}
4222124650659852	1688849860263948	1407374883553290	{}
4222124650659853	1688849860263949	1407374883553295	{}
4222124650659854	1688849860263950	1407374883553295	{}
4222124650659855	1688849860263951	1407374883553295	{}
4222124650659856	1688849860263953	1407374883553295	{}
4222124650659857	1688849860263954	1407374883553295	{}
4222124650659858	1688849860263957	1407374883553296	{}
4222124650659859	1688849860263958	1407374883553286	{}
4222124650659860	1688849860263959	1407374883553285	{}
4222124650659861	1688849860263960	1407374883553285	{}
4222124650659862	1688849860263961	1407374883553294	{}
4222124650659863	1688849860263962	1407374883553299	{}
4222124650659864	1688849860263952	1688849860263948	{}
4222124650659865	1688849860263955	1688849860263948	{}
4222124650659866	1688849860263956	1688849860263955	{}
4222124650659867	1688849860263963	1407374883553299	{}
4222124650659868	1688849860263964	1407374883553299	{}
4222124650659869	1688849860263965	1407374883553299	{}
4222124650659870	1688849860263966	1407374883553299	{}
4222124650659871	1688849860263967	1407374883553299	{}
4222124650659872	1688849860263968	1407374883553299	{}
4222124650659873	1688849860263969	1407374883553299	{}
4222124650659874	1688849860263970	1407374883553299	{}
4222124650659875	1688849860263971	1407374883553299	{}
4222124650659876	1688849860263972	1407374883553299	{}
4222124650659877	1688849860263973	1407374883553299	{}
4222124650659878	1688849860263974	1407374883553299	{}
4222124650659879	1688849860263975	1407374883553299	{}
4222124650659880	1688849860263976	1407374883553299	{}
4222124650659885	1688849860263981	1407374883553299	{}
4222124650659886	1688849860263982	1407374883553299	{}
4222124650659887	1688849860263983	1407374883553299	{}
4222124650659888	1688849860263984	1407374883553299	{}
4222124650659889	1688849860263985	1407374883553299	{}
4222124650659890	1688849860263986	1407374883553299	{}
4222124650659923	1688849860264019	1407374883553299	{}
4222124650659924	1688849860264020	1407374883553282	{}
4222124650659925	1688849860264021	1407374883553282	{}
4222124650659926	1688849860264022	1407374883553282	{}
4222124650659927	1688849860264023	1407374883553282	{}
4222124650659928	1688849860264024	1407374883553282	{}
4222124650659929	1688849860264025	1407374883553282	{}
4222124650659930	1688849860264026	1407374883553282	{}
4222124650659931	1688849860264027	1407374883553282	{}
4222124650659932	1688849860264028	1407374883553282	{}
4222124650659933	1688849860264029	1407374883553282	{}
4222124650659934	1688849860264030	1407374883553282	{}
4222124650659935	1688849860264031	1407374883553282	{}
4222124650659936	1688849860264032	1407374883553281	{}
4222124650659937	1688849860264033	1407374883553282	{}
4222124650659938	1688849860264034	1407374883553282	{}
4222124650659939	1688849860264035	1407374883553282	{}
4222124650659940	1688849860264036	1407374883553282	{}
4222124650659941	1688849860264037	1407374883553282	{}
4222124650659942	1688849860264038	1407374883553282	{}
4222124650659943	1688849860264039	1407374883553282	{}
4222124650659944	1688849860264040	1407374883553282	{}
4222124650659945	1688849860264041	1407374883553282	{}
4222124650659946	1688849860264042	1407374883553282	{}
4222124650659947	1688849860264043	1407374883553282	{}
4222124650659948	1688849860264044	1407374883553282	{}
4222124650659949	1688849860264045	1407374883553282	{}
4222124650659950	1688849860264046	1407374883553282	{}
4222124650659951	1688849860264047	1407374883553282	{}
4222124650659953	1688849860264049	1407374883553282	{}
4222124650659957	1688849860264053	1407374883553282	{}
4222124650659959	1688849860264055	1407374883553282	{}
4222124650659961	1688849860264057	1407374883553282	{}
4222124650659963	1688849860264059	1407374883553282	{}
4222124650659965	1688849860264061	1407374883553282	{}
4222124650659967	1688849860264063	1407374883553282	{}
4222124650659969	1688849860264065	1407374883553282	{}
4222124650659971	1688849860264067	1407374883553282	{}
4222124650659973	1688849860264069	1407374883553282	{}
4222124650659975	1688849860264071	1407374883553282	{}
4222124650659977	1688849860264073	1407374883553282	{}
4222124650659979	1688849860264075	1407374883553282	{}
4222124650659981	1688849860264077	1407374883553282	{}
4222124650659983	1688849860264079	1407374883553282	{}
4222124650659985	1688849860264081	1407374883553282	{}
4222124650659987	1688849860264083	1407374883553282	{}
4222124650659989	1688849860264085	1407374883553282	{}
4222124650659991	1688849860264087	1407374883553282	{}
4222124650659993	1688849860264089	1407374883553282	{}
4222124650659994	1688849860264090	1407374883553282	{}
4222124650659996	1688849860264092	1407374883553282	{}
4222124650659997	1688849860264093	1407374883553282	{}
4222124650659999	1688849860264095	1407374883553282	{}
4222124650660000	1688849860264096	1407374883553282	{}
4222124650660002	1688849860264098	1407374883553282	{}
4222124650660003	1688849860264099	1407374883553282	{}
4222124650660007	1688849860264103	1407374883553282	{}
4222124650660008	1688849860264104	1407374883553282	{}
4222124650660010	1688849860264106	1407374883553282	{}
4222124650660011	1688849860264107	1407374883553282	{}
4222124650660013	1688849860264109	1407374883553282	{}
4222124650660014	1688849860264110	1407374883553282	{}
\.


--
-- Data for Name: Reply; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."Reply" (id, properties) FROM stdin;
1688849860263937	{"id": 1, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263938	{"id": 2, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263939	{"id": 3, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263940	{"id": 4, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263941	{"id": 5, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263942	{"id": 6, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263943	{"id": 7, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263944	{"id": 8, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263945	{"id": 9, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263946	{"id": 10, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263947	{"id": 11, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263948	{"id": 12, "created_at": "2025-03-05T09:01:24.202915+05:30"}
1688849860263949	{"id": 14, "created_at": "2025-03-12T09:44:29.191607+05:30"}
1688849860263950	{"id": 15, "created_at": "2025-03-12T09:44:33.314172+05:30"}
1688849860263951	{"id": 17, "created_at": "2025-03-12T09:46:36.304058+05:30"}
1688849860263952	{"id": 18, "created_at": "2025-03-12T09:49:00.966636+05:30"}
1688849860263953	{"id": 19, "created_at": "2025-03-12T09:50:01.720768+05:30"}
1688849860263954	{"id": 20, "created_at": "2025-03-12T09:51:05.385450+05:30"}
1688849860263955	{"id": 21, "created_at": "2025-03-12T09:51:09.579549+05:30"}
1688849860263956	{"id": 22, "created_at": "2025-03-12T09:51:22.723128+05:30"}
1688849860263957	{"id": 23, "created_at": "2025-03-13T06:39:20.969698+05:30"}
1688849860263958	{"id": 25, "created_at": "2025-03-18T09:47:42.669801+05:30"}
1688849860263959	{"id": 26, "created_at": "2025-03-18T09:48:00.843510+05:30"}
1688849860263960	{"id": 27, "created_at": "2025-03-18T09:48:05.973502+05:30"}
1688849860263961	{"id": 28, "created_at": "2025-03-18T09:56:17.556663+05:30"}
1688849860263962	{"id": 29, "created_at": "2025-03-23T17:56:35.218877+05:30"}
1688849860263963	{"id": 35, "created_at": "2025-05-03T15:40:43.313783+05:30"}
1688849860263964	{"id": 36, "created_at": "2025-05-03T16:00:47.517651+05:30"}
1688849860263965	{"id": 37, "created_at": "2025-05-03T16:02:04.498859+05:30"}
1688849860263966	{"id": 38, "created_at": "2025-05-03T16:17:30.559524+05:30"}
1688849860263967	{"id": 39, "created_at": "2025-05-03T16:28:13.703338+05:30"}
1688849860263968	{"id": 40, "created_at": "2025-05-03T16:30:12.002011+05:30"}
1688849860263969	{"id": 41, "created_at": "2025-05-03T16:31:03.277811+05:30"}
1688849860263970	{"id": 42, "created_at": "2025-05-03T16:45:55.752579+05:30"}
1688849860263971	{"id": 43, "created_at": "2025-05-03T16:51:00.216304+05:30"}
1688849860263972	{"id": 44, "created_at": "2025-05-03T17:02:33.308366+05:30"}
1688849860263973	{"id": 45, "created_at": "2025-05-03T17:14:45.177866+05:30"}
1688849860263974	{"id": 46, "created_at": "2025-05-03T17:35:33.405693+05:30"}
1688849860263975	{"id": 47, "created_at": "2025-05-03T17:37:15.017541+05:30"}
1688849860263976	{"id": 48, "created_at": "2025-05-03T17:42:21.868731+05:30"}
1688849860263981	{"id": 53, "created_at": "2025-05-04T00:35:09.742654+05:30"}
1688849860263982	{"id": 54, "created_at": "2025-05-04T00:45:33.607314+05:30"}
1688849860263983	{"id": 55, "created_at": "2025-05-04T01:19:36.628426+05:30"}
1688849860263984	{"id": 56, "created_at": "2025-05-04T01:20:01.712949+05:30"}
1688849860263985	{"id": 57, "created_at": "2025-05-04T01:34:54.800097+05:30"}
1688849860263986	{"id": 58, "created_at": "2025-05-04T01:41:02.448232+05:30"}
1688849860264019	{"id": 91, "created_at": "2025-05-04T12:44:39.636275+05:30"}
1688849860264020	{"id": 94, "created_at": "2025-05-04T21:05:19.166710+05:30"}
1688849860264021	{"id": 95, "created_at": "2025-05-04T21:07:29.540563+05:30"}
1688849860264022	{"id": 96, "created_at": "2025-05-04T21:08:14.449345+05:30"}
1688849860264023	{"id": 97, "created_at": "2025-05-04T21:33:47.063303+05:30"}
1688849860264024	{"id": 98, "created_at": "2025-05-04T21:40:49.476557+05:30"}
1688849860264025	{"id": 99, "created_at": "2025-05-04T21:42:34.268362+05:30"}
1688849860264026	{"id": 100, "created_at": "2025-05-04T21:50:49.255698+05:30"}
1688849860264027	{"id": 101, "created_at": "2025-05-04T21:56:54.522497+05:30"}
1688849860264028	{"id": 102, "created_at": "2025-05-04T21:59:39.215676+05:30"}
1688849860264029	{"id": 103, "created_at": "2025-05-05T09:36:56.243481+05:30"}
1688849860264030	{"id": 104, "created_at": "2025-05-05T11:50:17.326467+05:30"}
1688849860264031	{"id": 105, "created_at": "2025-05-05T11:52:00.952131+05:30"}
1688849860264032	{"id": 106, "created_at": "2025-05-05T12:00:35.621518+05:30"}
1688849860264033	{"id": 107, "created_at": "2025-05-05T15:51:14.459206+05:30"}
1688849860264034	{"id": 108, "created_at": "2025-05-05T16:01:36.708150+05:30"}
1688849860264035	{"id": 109, "created_at": "2025-05-05T16:53:31.102823+05:30"}
1688849860264036	{"id": 110, "created_at": "2025-05-06T16:17:26.253687+05:30"}
1688849860264037	{"id": 111, "created_at": "2025-05-06T16:32:23.857254+05:30"}
1688849860264038	{"id": 112, "created_at": "2025-05-06T16:50:20.248782+05:30"}
1688849860264039	{"id": 113, "created_at": "2025-05-06T17:11:13.568918+05:30"}
1688849860264040	{"id": 114, "created_at": "2025-05-06T17:12:02.438310+05:30"}
1688849860264069	{"id": 143, "created_at": "2025-05-07T12:55:31.404298+05:30"}
1688849860264041	{"id": 115, "created_at": "2025-05-06T17:42:45.824149+05:30"}
1688849860264042	{"id": 116, "created_at": "2025-05-06T17:44:02.558028+05:30"}
1688849860264043	{"id": 117, "created_at": "2025-05-06T17:44:22.516226+05:30"}
1688849860264044	{"id": 118, "created_at": "2025-05-07T09:20:23.906467+05:30"}
1688849860264071	{"id": 145, "created_at": "2025-05-07T12:58:55.264128+05:30"}
1688849860264045	{"id": 119, "created_at": "2025-05-07T11:04:57.760306+05:30"}
1688849860264046	{"id": 120, "created_at": "2025-05-07T11:22:47.723335+05:30"}
1688849860264047	{"id": 121, "created_at": "2025-05-07T11:36:39.623878+05:30"}
1688849860264073	{"id": 147, "created_at": "2025-05-07T13:01:37.066683+05:30"}
1688849860264049	{"id": 123, "created_at": "2025-05-07T11:46:35.840691+05:30"}
1688849860264075	{"id": 149, "created_at": "2025-05-07T13:05:01.352805+05:30"}
1688849860264077	{"id": 151, "created_at": "2025-05-07T13:09:38.939115+05:30"}
1688849860264053	{"id": 127, "created_at": "2025-05-07T12:22:37.125373+05:30"}
1688849860264055	{"id": 129, "created_at": "2025-05-07T12:27:16.381184+05:30"}
1688849860264079	{"id": 153, "created_at": "2025-05-07T13:12:40.843337+05:30"}
1688849860264057	{"id": 131, "created_at": "2025-05-07T12:31:05.997034+05:30"}
1688849860264081	{"id": 155, "created_at": "2025-05-07T13:15:57.937926+05:30"}
1688849860264059	{"id": 133, "created_at": "2025-05-07T12:33:28.946471+05:30"}
1688849860264083	{"id": 157, "created_at": "2025-05-07T13:18:50.834141+05:30"}
1688849860264061	{"id": 135, "created_at": "2025-05-07T12:38:06.558121+05:30"}
1688849860264063	{"id": 137, "created_at": "2025-05-07T12:43:52.189156+05:30"}
1688849860264085	{"id": 159, "created_at": "2025-05-07T13:23:06.757864+05:30"}
1688849860264065	{"id": 139, "created_at": "2025-05-07T12:47:25.763334+05:30"}
1688849860264087	{"id": 161, "created_at": "2025-05-07T13:34:51.441243+05:30"}
1688849860264067	{"id": 141, "created_at": "2025-05-07T12:51:57.835324+05:30"}
1688849860264089	{"id": 163, "created_at": "2025-05-07T15:02:05.644298+05:30"}
1688849860264090	{"id": 164, "created_at": "2025-05-07T15:02:09.493806+05:30"}
1688849860264092	{"id": 166, "created_at": "2025-05-07T15:21:08.010725+05:30"}
1688849860264093	{"id": 167, "created_at": "2025-05-07T15:21:08.827013+05:30"}
1688849860264095	{"id": 169, "created_at": "2025-05-07T15:40:08.982100+05:30"}
1688849860264096	{"id": 170, "created_at": "2025-05-07T15:40:14.002044+05:30"}
1688849860264098	{"id": 172, "created_at": "2025-05-07T15:42:54.106735+05:30"}
1688849860264099	{"id": 173, "created_at": "2025-05-07T15:42:59.484014+05:30"}
1688849860264103	{"id": 177, "created_at": "2025-05-07T15:55:18.755801+05:30"}
1688849860264104	{"id": 178, "created_at": "2025-05-07T15:55:24.387169+05:30"}
1688849860264106	{"id": 180, "created_at": "2025-05-07T16:05:06.210126+05:30"}
1688849860264107	{"id": 181, "created_at": "2025-05-07T16:05:11.065887+05:30"}
1688849860264109	{"id": 183, "created_at": "2025-05-07T16:10:07.412849+05:30"}
1688849860264110	{"id": 184, "created_at": "2025-05-07T16:10:12.624525+05:30"}
\.


--
-- Data for Name: User; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."User" (id, properties) FROM stdin;
844424930131970	{"id": 3, "name": "Charlie Brown", "username": "charlieb"}
844424930131971	{"id": 7, "name": "x12e", "username": "x2412"}
844424930131972	{"id": 8, "name": "1", "username": "1"}
844424930131973	{"id": 10, "name": "lol", "username": "lol"}
844424930131974	{"id": 13, "name": "lol", "username": "lol5"}
844424930131975	{"id": 14, "name": "pqkd", "username": "jsk"}
844424930131976	{"id": 16, "name": "John Doe", "username": "johndoe"}
844424930131977	{"id": 1056, "name": "pranjay Kashyap", "username": "pranjay14"}
844424930131978	{"id": 4, "name": "Divansh Prasad", "username": "divansh", "image_path": "users/divansh/profile/f3f131e5-305b-4e7d-9bf7-a921a08fbceb.png"}
844424930131979	{"id": 5, "name": "Kanishk Prasad", "username": "kanishk", "image_path": "users/kanishk/profile/d076b203-1224-4bc5-98aa-9f1e6f8d5cee.jpg"}
844424930131980	{"id": 1, "name": "Alice Johnson", "username": "alicej", "image_path": "users/alicej/profile/89b9d93b-63d0-4950-8092-552c2353545f.png"}
844424930131981	{"id": 1054, "name": "Vineet Prasad", "username": "vineet"}
844424930131982	{"id": 1055, "name": "Shailesh Kumar Gupta", "username": "eskge", "image_path": "users/eskge/profile/70c315ec-9557-4962-8357-a94642a03041.jpg"}
844424930131969	{"id": 2, "name": "Bob Smith", "username": "bobsmith", "image_path": "users/bobsmith/profile/RaspberryPi.png"}
\.


--
-- Data for Name: VOTED; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."VOTED" (id, start_id, end_id, properties) FROM stdin;
3659174697238529	844424930131969	1407374883553281	{}
3659174697238530	844424930131970	1407374883553282	{}
3659174697238531	844424930131980	1407374883553283	{}
3659174697238532	844424930131970	1407374883553287	{}
3659174697238533	844424930131969	1407374883553290	{}
3659174697238534	844424930131976	1407374883553295	{}
3659174697238535	844424930131978	1407374883553296	{}
3659174697238536	844424930131978	1407374883553295	{}
3659174697238537	844424930131978	1407374883553289	{}
3659174697238538	844424930131978	1407374883553285	{}
3659174697238539	844424930131978	1407374883553286	{}
3659174697238540	844424930131978	1407374883553294	{}
3659174697238541	844424930131978	1407374883553293	{}
3659174697238542	844424930131978	1407374883553281	{}
3659174697238543	844424930131978	1407374883553290	{}
3659174697238544	844424930131978	1407374883553292	{}
3659174697238545	844424930131980	1407374883553295	{}
3659174697238546	844424930131980	1407374883553294	{}
3659174697238547	844424930131978	1407374883553297	{}
3659174697238548	844424930131979	1407374883553289	{}
3659174697238550	844424930131980	1407374883553296	{}
3659174697238551	844424930131980	1407374883553298	{}
3659174697238552	844424930131980	1407374883553287	{}
3659174697238554	844424930131970	1688849860263937	{}
3659174697238555	844424930131980	1688849860263938	{}
3659174697238556	844424930131969	1688849860263939	{}
3659174697238557	844424930131980	1688849860263940	{}
3659174697238558	844424930131970	1688849860263941	{}
3659174697238559	844424930131969	1688849860263942	{}
3659174697238560	844424930131980	1688849860263943	{}
3659174697238608	844424930131978	1688849860263937	{}
3659174697238561	844424930131980	1688849860263962	{"vote_type": true, "created_at": "2025-05-03T19:49:36.791660+00:00"}
3659174697238553	844424930131978	1407374883553299	{"vote_type": false, "created_at": "2025-05-03T20:04:54.946145+00:00"}
3659174697238562	844424930131978	1688849860263962	{"vote_type": true, "created_at": "2025-05-03T20:04:54.970374+00:00"}
3659174697238564	844424930131980	1688849860263986	{}
3659174697238549	844424930131980	1407374883553299	{"vote_type": true, "created_at": "2025-05-04T07:14:39.736391+00:00"}
3659174697238596	844424930131980	1688849860264019	{}
\.


--
-- Data for Name: WROTE; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore."WROTE" (id, start_id, end_id, properties) FROM stdin;
2814749767106561	844424930131980	1407374883553281	{}
2814749767106562	844424930131969	1407374883553282	{}
2814749767106563	844424930131970	1407374883553283	{}
2814749767106564	844424930131980	1407374883553284	{}
2814749767106565	844424930131969	1407374883553285	{}
2814749767106566	844424930131970	1407374883553286	{}
2814749767106567	844424930131980	1407374883553287	{}
2814749767106568	844424930131969	1407374883553288	{}
2814749767106569	844424930131970	1407374883553289	{}
2814749767106570	844424930131980	1407374883553290	{}
2814749767106571	844424930131976	1407374883553291	{}
2814749767106572	844424930131976	1407374883553292	{}
2814749767106573	844424930131976	1407374883553293	{}
2814749767106574	844424930131976	1407374883553294	{}
2814749767106575	844424930131976	1407374883553295	{}
2814749767106576	844424930131976	1407374883553296	{}
2814749767106577	844424930131980	1407374883553297	{}
2814749767106578	844424930131978	1407374883553298	{}
2814749767106579	844424930131979	1407374883553299	{}
2814749767106580	844424930131969	1688849860263937	{}
2814749767106581	844424930131970	1688849860263938	{}
2814749767106582	844424930131980	1688849860263939	{}
2814749767106583	844424930131969	1688849860263940	{}
2814749767106584	844424930131970	1688849860263941	{}
2814749767106585	844424930131980	1688849860263942	{}
2814749767106586	844424930131970	1688849860263943	{}
2814749767106587	844424930131969	1688849860263944	{}
2814749767106588	844424930131980	1688849860263945	{}
2814749767106589	844424930131970	1688849860263946	{}
2814749767106590	844424930131969	1688849860263947	{}
2814749767106591	844424930131970	1688849860263948	{}
2814749767106592	844424930131976	1688849860263949	{}
2814749767106593	844424930131976	1688849860263950	{}
2814749767106594	844424930131976	1688849860263951	{}
2814749767106595	844424930131979	1688849860263952	{}
2814749767106596	844424930131976	1688849860263953	{}
2814749767106597	844424930131976	1688849860263954	{}
2814749767106598	844424930131976	1688849860263955	{}
2814749767106599	844424930131976	1688849860263956	{}
2814749767106600	844424930131978	1688849860263957	{}
2814749767106601	844424930131978	1688849860263958	{}
2814749767106602	844424930131978	1688849860263959	{}
2814749767106603	844424930131978	1688849860263960	{}
2814749767106604	844424930131978	1688849860263961	{}
2814749767106605	844424930131980	1688849860263962	{}
2814749767106606	844424930131980	1688849860263963	{}
2814749767106607	844424930131980	1688849860263964	{}
2814749767106608	844424930131980	1688849860263965	{}
2814749767106609	844424930131980	1688849860263966	{}
2814749767106610	844424930131980	1688849860263967	{}
2814749767106611	844424930131980	1688849860263968	{}
2814749767106612	844424930131980	1688849860263969	{}
2814749767106613	844424930131980	1688849860263970	{}
2814749767106614	844424930131980	1688849860263971	{}
2814749767106615	844424930131980	1688849860263972	{}
2814749767106616	844424930131980	1688849860263973	{}
2814749767106617	844424930131980	1688849860263974	{}
2814749767106618	844424930131980	1688849860263975	{}
2814749767106619	844424930131980	1688849860263976	{}
2814749767106627	844424930131980	1407374883553303	{}
2814749767106628	844424930131980	1688849860263981	{}
2814749767106629	844424930131980	1407374883553304	{}
2814749767106630	844424930131980	1688849860263982	{}
2814749767106631	844424930131980	1407374883553305	{}
2814749767106632	844424930131980	1688849860263983	{}
2814749767106633	844424930131978	1407374883553306	{}
2814749767106634	844424930131978	1688849860263984	{}
2814749767106635	844424930131978	1407374883553307	{}
2814749767106636	844424930131978	1688849860263985	{}
2814749767106637	844424930131980	1407374883553308	{}
2814749767106638	844424930131980	1688849860263986	{}
2814749767106670	844424930131980	1407374883553341	{}
2814749767106671	844424930131980	1688849860264019	{}
2814749767106672	844424930131980	1407374883553342	{}
2814749767106673	844424930131980	1407374883553343	{}
2814749767106674	844424930131980	1407374883553344	{}
2814749767106675	844424930131980	1407374883553345	{}
2814749767106676	844424930131980	1688849860264020	{}
2814749767106677	844424930131980	1407374883553346	{}
2814749767106678	844424930131980	1688849860264021	{}
2814749767106679	844424930131980	1407374883553347	{}
2814749767106680	844424930131980	1688849860264022	{}
2814749767106681	844424930131980	1407374883553348	{}
2814749767106682	844424930131980	1688849860264023	{}
2814749767106683	844424930131980	1407374883553349	{}
2814749767106684	844424930131980	1688849860264024	{}
2814749767106685	844424930131980	1407374883553350	{}
2814749767106686	844424930131980	1688849860264025	{}
2814749767106687	844424930131980	1407374883553351	{}
2814749767106688	844424930131980	1688849860264026	{}
2814749767106689	844424930131980	1407374883553352	{}
2814749767106690	844424930131980	1688849860264027	{}
2814749767106691	844424930131980	1407374883553353	{}
2814749767106692	844424930131980	1688849860264028	{}
2814749767106693	844424930131980	1407374883553354	{}
2814749767106694	844424930131980	1688849860264029	{}
2814749767106695	844424930131980	1407374883553355	{}
2814749767106696	844424930131980	1688849860264030	{}
2814749767106697	844424930131978	1407374883553356	{}
2814749767106698	844424930131978	1688849860264031	{}
2814749767106699	844424930131980	1407374883553357	{}
2814749767106700	844424930131980	1688849860264032	{}
2814749767106701	844424930131980	1407374883553358	{}
2814749767106702	844424930131980	1688849860264033	{}
2814749767106703	844424930131980	1407374883553359	{}
2814749767106704	844424930131980	1688849860264034	{}
2814749767106705	844424930131980	1407374883553360	{}
2814749767106706	844424930131980	1688849860264035	{}
2814749767106707	844424930131980	1407374883553361	{}
2814749767106708	844424930131980	1407374883553362	{}
2814749767106709	844424930131980	1688849860264036	{}
2814749767106710	844424930131980	1407374883553363	{}
2814749767106711	844424930131980	1688849860264037	{}
2814749767106712	844424930131980	1407374883553364	{}
2814749767106713	844424930131980	1407374883553365	{}
2814749767106714	844424930131980	1688849860264038	{}
2814749767106715	844424930131980	1407374883553366	{}
2814749767106716	844424930131980	1688849860264039	{}
2814749767106717	844424930131980	1407374883553367	{}
2814749767106719	844424930131980	1688849860264040	{}
2814749767106720	844424930131980	1407374883553369	{}
2814749767106721	844424930131980	1688849860264041	{}
2814749767106722	844424930131980	1407374883553370	{}
2814749767106723	844424930131980	1688849860264042	{}
2814749767106724	844424930131980	1407374883553371	{}
2814749767106726	844424930131980	1688849860264043	{}
2814749767106727	844424930131980	1407374883553373	{}
2814749767106729	844424930131980	1407374883553375	{}
2814749767106730	844424930131980	1688849860264044	{}
2814749767106731	844424930131980	1407374883553376	{}
2814749767106732	844424930131980	1407374883553377	{}
2814749767106733	844424930131980	1688849860264045	{}
2814749767106734	844424930131980	1407374883553378	{}
2814749767106736	844424930131980	1688849860264046	{}
2814749767106737	844424930131980	1407374883553380	{}
2814749767106739	844424930131980	1688849860264047	{}
2814749767106741	844424930131980	1407374883553382	{}
2814749767106743	844424930131980	1688849860264049	{}
2814749767106749	844424930131980	1407374883553386	{}
2814749767106751	844424930131980	1688849860264053	{}
2814749767106753	844424930131980	1407374883553388	{}
2814749767106755	844424930131980	1688849860264055	{}
2814749767106757	844424930131980	1407374883553390	{}
2814749767106759	844424930131980	1688849860264057	{}
2814749767106761	844424930131980	1407374883553392	{}
2814749767106763	844424930131980	1688849860264059	{}
2814749767106765	844424930131980	1407374883553394	{}
2814749767106767	844424930131980	1688849860264061	{}
2814749767106769	844424930131980	1407374883553396	{}
2814749767106771	844424930131980	1688849860264063	{}
2814749767106773	844424930131980	1407374883553398	{}
2814749767106775	844424930131980	1688849860264065	{}
2814749767106777	844424930131980	1407374883553400	{}
2814749767106779	844424930131980	1688849860264067	{}
2814749767106781	844424930131980	1407374883553402	{}
2814749767106783	844424930131980	1688849860264069	{}
2814749767106785	844424930131980	1407374883553404	{}
2814749767106787	844424930131980	1688849860264071	{}
2814749767106789	844424930131980	1407374883553406	{}
2814749767106791	844424930131980	1688849860264073	{}
2814749767106793	844424930131980	1407374883553408	{}
2814749767106795	844424930131980	1688849860264075	{}
2814749767106797	844424930131980	1407374883553410	{}
2814749767106799	844424930131980	1688849860264077	{}
2814749767106801	844424930131980	1407374883553412	{}
2814749767106803	844424930131980	1688849860264079	{}
2814749767106805	844424930131980	1407374883553414	{}
2814749767106807	844424930131980	1688849860264081	{}
2814749767106809	844424930131980	1407374883553416	{}
2814749767106811	844424930131980	1688849860264083	{}
2814749767106813	844424930131980	1407374883553418	{}
2814749767106815	844424930131980	1688849860264085	{}
2814749767106817	844424930131980	1407374883553420	{}
2814749767106819	844424930131980	1688849860264087	{}
2814749767106821	844424930131980	1688849860264089	{}
2814749767106824	844424930131980	1688849860264090	{}
2814749767106826	844424930131980	1688849860264092	{}
2814749767106827	844424930131980	1688849860264093	{}
2814749767106829	844424930131980	1688849860264095	{}
2814749767106830	844424930131980	1407374883553424	{}
2814749767106832	844424930131980	1688849860264096	{}
2814749767106834	844424930131980	1688849860264098	{}
2814749767106835	844424930131980	1407374883553426	{}
2814749767106837	844424930131980	1688849860264099	{}
2814749767106841	844424930131980	1688849860264103	{}
2814749767106842	844424930131980	1407374883553428	{}
2814749767106844	844424930131980	1688849860264104	{}
2814749767106846	844424930131980	1688849860264106	{}
2814749767106847	844424930131980	1407374883553430	{}
2814749767106849	844424930131980	1688849860264107	{}
2814749767106851	844424930131980	1688849860264109	{}
2814749767106852	844424930131980	1407374883553432	{}
2814749767106854	844424930131980	1688849860264110	{}
\.


--
-- Data for Name: _ag_label_edge; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore._ag_label_edge (id, start_id, end_id, properties) FROM stdin;
\.


--
-- Data for Name: _ag_label_vertex; Type: TABLE DATA; Schema: fiore; Owner: -
--

COPY fiore._ag_label_vertex (id, properties) FROM stdin;
\.


--
-- Data for Name: chat_message_media; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.chat_message_media (message_id, media_id) FROM stdin;
1390	67
1391	93
1392	99
1393	105
1394	111
1395	117
1396	123
1397	129
1398	134
1399	141
1400	147
1401	153
1402	160
1403	167
1404	174
1405	180
1408	187
1414	190
1416	195
1418	200
1420	205
1422	210
1424	215
1426	220
1428	225
1430	230
1432	235
1434	240
1436	245
1438	250
1440	255
1442	260
1444	265
1446	270
1448	275
1450	280
1452	285
1454	290
1456	295
1458	300
1460	302
1462	304
1464	309
1466	314
1468	317
1470	319
1472	324
1474	329
\.


--
-- Data for Name: chat_messages; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.chat_messages (id, community_id, event_id, user_id, content, "timestamp") FROM stdin;
1	1	\N	1	Hi everyone! Looking forward to the AI talk.	2025-03-31 01:09:14.697765+05:30
2	1	\N	4	Me too! Should be interesting.	2025-03-31 01:09:14.697765+05:30
3	1	\N	1	The coding meetup is tomorrow, right?	2025-03-31 01:09:14.697765+05:30
4	1	\N	5	Yes, 10 AM in Room A.	2025-03-31 01:09:14.697765+05:30
5	\N	1	4	Is the Zoom link posted yet for the AI talk?	2025-03-31 01:09:14.708729+05:30
6	\N	1	1	I will post it soon!	2025-03-31 01:09:14.708729+05:30
7	\N	1	5	I can’t wait to hear about the latest in AI!	2025-03-31 01:09:14.708729+05:30
8	\N	1	4	I hope they discuss the ethical implications too.	2025-03-31 01:09:14.708729+05:30
9	\N	1	1	Absolutely! It’s a hot topic right now.	2025-03-31 01:09:14.708729+05:30
10	\N	2	1	I have a project I need help with.	2025-03-31 01:09:14.719818+05:30
11	\N	2	4	I can help! What’s the project about?	2025-03-31 01:09:14.719818+05:30
12	\N	2	1	It’s a web app using React and Node.js.	2025-03-31 01:09:14.719818+05:30
13	\N	2	4	Sounds cool! I love React.	2025-03-31 01:09:14.719818+05:30
14	2	\N	5	Anyone going for a run this evening?	2025-03-31 01:09:14.730962+05:30
15	2	\N	4	I might join! What time?	2025-03-31 01:09:14.730962+05:30
16	2	\N	5	How about 6 PM at the park?	2025-03-31 01:09:14.730962+05:30
17	2	\N	4	Sounds good!	2025-03-31 01:09:14.730962+05:30
18	1	\N	1	hi	2025-04-22 15:46:30.910835+05:30
19	\N	16	4	hi	2025-04-22 15:47:05.848577+05:30
20	1	\N	4	testing again	2025-04-22 16:33:46.110372+05:30
21	1	\N	1	testing again	2025-04-22 16:33:57.022761+05:30
22	1	\N	4	testing from flutter app	2025-04-23 12:58:28.255147+05:30
23	1	\N	1	Testing from flutter apk	2025-04-23 13:01:46.844231+05:30
24	1	\N	4	this is me from https://connections-flutter-fastapi.github.io/connections/	2025-04-23 13:24:30.65758+05:30
25	1	\N	1	This is also me from locally downloaded apk	2025-04-23 13:25:02.083573+05:30
26	4	\N	1	Aur Divansh kaisa hai	2025-04-23 13:32:13.149495+05:30
27	4	\N	1	Bhai chat kar na	2025-04-23 13:33:13.442695+05:30
28	4	\N	1	Abe	2025-04-23 13:35:11.208523+05:30
29	4	\N	1	Reload nhi hota	2025-04-23 13:35:16.1406+05:30
30	4	\N	1	Refresh karna padega	2025-04-23 13:35:21.147831+05:30
31	4	\N	1	Acha aesa kya	2025-04-23 13:35:29.353803+05:30
32	4	\N	1	Same account se kyu aa gaya	2025-04-23 13:35:36.257281+05:30
33	4	\N	4	Aa gya	2025-04-23 13:38:44.826607+05:30
34	4	\N	4	LoL	2025-04-23 13:38:47.901832+05:30
35	4	\N	1	Yess	2025-04-23 13:39:41.892139+05:30
1298	13	\N	4	??	2025-04-26 13:22:43.574308+05:30
37	4	\N	1	Ek baar ye chat wala dekhta hu ki kya issue hai	2025-04-23 13:39:57.457624+05:30
38	4	\N	4	Haan please dekh lena, agar backend change ho toh bata na	2025-04-23 14:15:40.713593+05:30
39	4	\N	1	hi	2025-04-23 15:16:10.457661+05:30
40	4	\N	4	Checking auto refresh	2025-04-23 15:17:05.369831+05:30
41	4	\N	1	failed lol	2025-04-23 15:17:13.618632+05:30
42	4	\N	1	trying again	2025-04-23 15:20:12.418563+05:30
43	4	\N	4	Ok, can you see this?	2025-04-23 15:20:30.038613+05:30
44	4	\N	1	only now	2025-04-23 15:28:14.889905+05:30
45	4	\N	4	.	2025-04-23 15:28:29.425182+05:30
46	4	\N	4	Ucyc	2025-04-23 15:28:37.169426+05:30
47	4	\N	4	Checking	2025-04-23 15:31:13.662996+05:30
48	4	\N	1	lol	2025-04-23 15:31:18.700294+05:30
1305	4	\N	1055	hi	2025-04-27 19:49:33.133747+05:30
1317	4	\N	1055	👙	2025-04-29 14:18:29.102841+05:30
1299	4	\N	1055	Gym @9pm?	2025-04-26 20:02:00.323794+05:30
1306	4	\N	1	hello	2025-04-27 19:49:40.445827+05:30
1318	4	\N	1055	👙	2025-04-29 14:18:54.355113+05:30
1300	4	\N	4	ok	2025-04-26 20:02:26.15577+05:30
1307	4	\N	1055	gym anyone?	2025-04-27 19:49:41.374093+05:30
1319	4	\N	1055	👙	2025-04-29 14:19:11.14622+05:30
1301	4	\N	4	meet me in parking	2025-04-26 20:02:46.934551+05:30
1308	4	\N	1055	rest day is for pussies	2025-04-27 19:49:56.963944+05:30
1320	4	\N	1055	🐹	2025-04-29 14:19:21.34213+05:30
1302	4	\N	1056	Hello	2025-04-26 20:40:40.378338+05:30
1309	4	\N	1	ok @9 pm?	2025-04-27 19:50:18.618961+05:30
1321	4	\N	1	lol	2025-04-29 14:19:56.232403+05:30
1303	4	\N	4	Hi	2025-04-26 20:41:07.523062+05:30
1310	4	\N	1056	hello again	2025-04-27 20:15:26.606079+05:30
1322	4	\N	5	Bhai isme thode functionality add Kara hai	2025-05-01 00:34:20.609998+05:30
1304	4	\N	5	eskge ..you are back!!	2025-04-27 00:31:40.917199+05:30
1311	4	\N	1	lol	2025-04-27 20:15:32.520222+05:30
1323	4	\N	5	Par purane code me already kuch cheeze already implemented the	2025-05-01 00:34:36.954638+05:30
1312	12	\N	4	testing	2025-04-28 15:04:46.695403+05:30
1324	4	\N	5	Hello guys	2025-05-01 14:07:15.725013+05:30
1313	12	\N	1	..	2025-04-28 15:06:48.971079+05:30
1325	4	\N	4	Hello	2025-05-01 15:18:45.686147+05:30
1314	12	\N	4	..	2025-04-28 15:06:51.176546+05:30
1326	4	\N	4	Bata kya kya functions add karne h	2025-05-01 15:19:21.285095+05:30
1315	4	\N	5	Oye chat chal raha hai	2025-04-29 12:52:24.492856+05:30
1316	4	\N	1055	👙	2025-04-29 14:04:43.336101+05:30
1249	4	\N	1	Oye online hai kya abhi	2025-04-24 01:58:40.568857+05:30
1250	4	\N	1	🥹🥹🥹	2025-04-24 01:58:54.877843+05:30
1251	4	\N	5	lol i am back	2025-04-24 12:00:20.171132+05:30
1252	4	\N	1	Nice	2025-04-24 12:05:44.088356+05:30
1253	4	\N	5	ikr	2025-04-24 12:09:09.879795+05:30
1254	4	\N	1	Testing	2025-04-24 12:12:13.202164+05:30
1255	4	\N	5	help?	2025-04-24 12:12:23.691508+05:30
1256	4	\N	1	Again	2025-04-24 12:12:39.114671+05:30
1257	4	\N	5	again 2	2025-04-24 12:12:49.327791+05:30
1258	4	\N	1	This is live	2025-04-24 12:14:24.124459+05:30
1259	4	\N	5	lol no it isnt	2025-04-24 12:14:32.22628+05:30
1260	4	\N	1	How about this	2025-04-24 12:17:50.587164+05:30
1261	4	\N	5	wait i think it worked	2025-04-24 12:18:02.706324+05:30
1262	4	\N	1	Really?	2025-04-24 12:18:20.551233+05:30
1263	4	\N	5	yeah	2025-04-24 12:18:25.01088+05:30
1264	4	\N	1	🔥	2025-04-24 12:36:42.905498+05:30
1265	4	\N	5	??	2025-04-24 12:36:58.141896+05:30
1266	4	\N	1	Website isn't rendering emojis lol 😂	2025-04-24 12:37:18.652906+05:30
1267	4	\N	5	wait i can see the lol face	2025-04-24 12:38:25.860234+05:30
1268	4	\N	1	Hi	2025-04-24 12:38:32.612982+05:30
1269	4	\N	5	speed is good	2025-04-24 12:39:07.635738+05:30
1270	4	\N	1	Is it bcoz same network?	2025-04-24 12:39:17.317356+05:30
1271	4	\N	1	Kya bro	2025-04-24 12:44:44.270288+05:30
1272	4	\N	5	hello	2025-04-24 12:44:52.039752+05:30
1274	4	\N	1	🤯🤯🤯	2025-04-24 12:45:25.094483+05:30
1275	4	\N	5	lol	2025-04-24 12:45:27.997682+05:30
1277	4	\N	1	🔥🔥🔥	2025-04-24 12:49:30.467921+05:30
1278	4	\N	4	yo	2025-04-24 12:50:17.743665+05:30
1279	4	\N	1	0	2025-04-24 12:52:24.627436+05:30
1282	4	\N	1	no u	2025-04-24 13:13:26.468881+05:30
1283	4	\N	1	Hello	2025-04-24 13:45:06.870189+05:30
1284	4	\N	1	Have you started your workout	2025-04-24 13:45:43.938377+05:30
1285	4	\N	1	Nope	2025-04-24 13:53:00.779224+05:30
1286	4	\N	1	great job building this guys...	2025-04-24 14:27:28.268847+05:30
1287	14	\N	1	Slayyy queen	2025-04-24 15:28:00.339367+05:30
1294	13	\N	1	💀💀💀	2025-04-25 00:20:57.262732+05:30
1295	4	\N	4	thanks	2025-04-25 13:58:46.512918+05:30
1296	4	\N	4	...	2025-04-25 13:59:01.998669+05:30
1327	1	\N	4	Test message from curl to community 1	2025-05-03 11:35:45.679709+05:30
1328	1	\N	1	Test HTTP message from script 2025-05-03 13:01:04.755556	2025-05-03 13:01:04.774079+05:30
1329	1	\N	1	Test HTTP message from script 2025-05-03 15:30:11.578906	2025-05-03 15:30:11.599612+05:30
1330	1	\N	4	Test HTTP message from script 2025-05-03 15:32:34.213099	2025-05-03 15:32:34.231965+05:30
1331	1	\N	1	Test HTTP message from script 2025-05-03 15:40:43.521693	2025-05-03 15:40:43.540714+05:30
1332	1	\N	1	Test HTTP message from script 2025-05-03 16:00:47.732799	2025-05-03 16:00:47.751908+05:30
1333	1	\N	1	Test HTTP message from script 2025-05-03 16:02:04.713453	2025-05-03 16:02:04.732976+05:30
1334	1	\N	1	Test HTTP message from script 2025-05-03 16:17:30.794134	2025-05-03 16:17:30.812945+05:30
1335	1	\N	1	Test HTTP message from script 2025-05-03 16:28:13.929756	2025-05-03 16:28:13.949497+05:30
1336	1	\N	1	Test HTTP message from script 2025-05-03 16:30:12.217083	2025-05-03 16:30:12.234764+05:30
1337	1	\N	1	Test HTTP message from script 2025-05-03 16:31:03.520590	2025-05-03 16:31:03.540495+05:30
1338	1	\N	1	Test HTTP message from script 2025-05-03 16:45:55.963081	2025-05-03 16:45:55.981113+05:30
1339	1	\N	1	Test HTTP message from script 2025-05-03 16:51:00.426290	2025-05-03 16:51:00.44462+05:30
1340	1	\N	1	Test HTTP message from script 2025-05-03 17:02:33.519815	2025-05-03 17:02:33.538967+05:30
1341	1	\N	1	Test HTTP message from script 2025-05-03 17:14:45.392654	2025-05-03 17:14:45.410978+05:30
1342	1	\N	1	Test HTTP message from script 2025-05-03 17:35:33.621333	2025-05-03 17:35:33.640195+05:30
1343	1	\N	1	Test HTTP message from script 2025-05-03 17:37:15.242243	2025-05-03 17:37:15.260562+05:30
1344	1	\N	1	Test HTTP message from script 2025-05-03 17:42:22.086194	2025-05-03 17:42:22.104807+05:30
1345	1	\N	1	Test HTTP message from script 2025-05-03 22:08:00.294100	2025-05-03 22:08:00.310107+05:30
1346	1	\N	1	Test HTTP message from script 2025-05-03 22:57:18.005973	2025-05-03 22:57:18.023249+05:30
1347	1	\N	1	Test HTTP message from script 2025-05-03 23:20:17.588324	2025-05-03 23:20:17.606069+05:30
1348	1	\N	1	Test HTTP message from script 2025-05-03 23:22:00.672179	2025-05-03 23:22:00.691777+05:30
1349	1	\N	1	Test HTTP message from script 2025-05-04 00:35:09.953885	2025-05-04 00:35:09.970779+05:30
1350	1	\N	1	Test HTTP message from script 2025-05-04 00:45:33.825112	2025-05-04 00:45:33.843157+05:30
1351	1	\N	1	Test HTTP message from script 2025-05-04 01:19:36.835818	2025-05-04 01:19:36.853932+05:30
1352	1	\N	4	Test HTTP message from script 2025-05-04 01:20:01.941896	2025-05-04 01:20:01.95976+05:30
1353	16	\N	4	Test HTTP message from script 2025-05-04 01:34:55.012120	2025-05-04 01:34:55.029233+05:30
1354	1	\N	1	Test Community HTTP msg 2025-05-04 01:41:02.692546	2025-05-04 01:41:02.709377+05:30
1355	\N	1	1	Test Event HTTP msg 2025-05-04 01:41:02.713906	2025-05-04 01:41:02.730929+05:30
1387	1	\N	1	Test Community HTTP msg 2025-05-04 12:44:39.868707	2025-05-04 12:44:39.884169+05:30
1388	\N	1	1	Test Event HTTP msg 2025-05-04 12:44:39.888645	2025-05-04 12:44:39.903216+05:30
1390	1	\N	1	Test Chat msg w/ media 2025-05-04 20:40:35.974872	2025-05-04 20:40:35.990989+05:30
1391	1	\N	1	Test Chat msg w/ media 2025-05-04 21:40:50.952900	2025-05-04 21:40:50.969421+05:30
1392	1	\N	1	Test Chat msg w/ media 2025-05-04 21:42:35.738532	2025-05-04 21:42:35.75508+05:30
1393	1	\N	1	Test Chat msg w/ media 2025-05-04 21:50:50.659694	2025-05-04 21:50:50.676153+05:30
1394	1	\N	1	Test Chat msg w/ media 2025-05-04 21:56:56.106634	2025-05-04 21:56:56.12449+05:30
1395	1	\N	1	Test Chat msg w/ media 2025-05-04 21:59:40.451559	2025-05-04 21:59:40.469234+05:30
1396	1	\N	1	Test Chat msg w/ media 2025-05-05 09:36:58.213360	2025-05-05 09:36:58.229829+05:30
1397	1	\N	1	Test Chat msg w/ media 2025-05-05 11:50:19.547056	2025-05-05 11:50:19.563793+05:30
1398	1	\N	4	Test Chat msg w/ media 2025-05-05 11:52:03.336125	2025-05-05 11:52:03.352813+05:30
1399	1	\N	1	Test Chat msg w/ media 2025-05-05 15:51:16.754484	2025-05-05 15:51:16.773965+05:30
1400	1	\N	1	Test Chat msg w/ media 2025-05-05 16:01:39.242555	2025-05-05 16:01:39.260753+05:30
1401	1	\N	1	Test Chat msg w/ media 2025-05-05 16:53:33.591405	2025-05-05 16:53:33.608466+05:30
1402	1	\N	1	Test Chat msg w/ media 2025-05-06 16:32:37.105674	2025-05-06 16:32:37.125914+05:30
1403	1	\N	1	Test Chat msg w/ media 2025-05-06 17:11:16.203639	2025-05-06 17:11:16.228793+05:30
1404	1	\N	1	Test Chat msg w/ media 2025-05-06 17:42:48.512031	2025-05-06 17:42:48.53193+05:30
1405	1	\N	1	Test Chat msg w/ media 2025-05-06 17:44:05.117193	2025-05-06 17:44:05.138553+05:30
1406	1	\N	1	Pytest HTTP Text Msg 174419	2025-05-06 17:44:19.173971+05:30
1407	1	\N	1	Pytest HTTP Text Msg 175705	2025-05-06 17:57:05.050255+05:30
1408	1	\N	1	Test Chat msg w/ media 2025-05-07 09:20:26.694178	2025-05-07 09:20:26.710543+05:30
1409	1	\N	1	Pytest HTTP Text Msg 105953	2025-05-07 10:59:53.350525+05:30
1410	1	\N	1	Pytest HTTP Text Msg 112244	2025-05-07 11:22:44.235673+05:30
1411	1	\N	1	Pytest HTTP Text Msg 113107	2025-05-07 11:31:07.333916+05:30
1413	1	\N	1	Pytest HTTP Text Msg 113621	2025-05-07 11:36:21.036874+05:30
1414	1	\N	1	Pytest Chat msg w/ media 113621	2025-05-07 11:36:21.061673+05:30
1415	1	\N	1	Pytest HTTP Text Msg 114619	2025-05-07 11:46:19.921417+05:30
1416	1	\N	1	Pytest Chat msg w/ media 114619	2025-05-07 11:46:19.946239+05:30
1417	1	\N	1	Pytest HTTP Text Msg 120742	2025-05-07 12:07:42.319652+05:30
1418	1	\N	1	Pytest Chat msg w/ media 120742	2025-05-07 12:07:42.353748+05:30
1419	1	\N	1	Pytest HTTP Text Msg 122218	2025-05-07 12:22:18.917354+05:30
1420	1	\N	1	Pytest Chat msg w/ media 122218	2025-05-07 12:22:18.941412+05:30
1421	1	\N	1	Pytest HTTP Text Msg 122659	2025-05-07 12:26:59.386455+05:30
1422	1	\N	1	Pytest Chat msg w/ media 122659	2025-05-07 12:26:59.411733+05:30
1423	1	\N	1	Pytest HTTP Text Msg 123049	2025-05-07 12:30:49.041724+05:30
1424	1	\N	1	Pytest Chat msg w/ media 123049	2025-05-07 12:30:49.065626+05:30
1425	1	\N	1	Pytest HTTP Text Msg 123311	2025-05-07 12:33:11.799903+05:30
1426	1	\N	1	Pytest Chat msg w/ media 123311	2025-05-07 12:33:11.824441+05:30
1427	1	\N	1	Pytest HTTP Text Msg 123750	2025-05-07 12:37:50.220521+05:30
1428	1	\N	1	Pytest Chat msg w/ media 123750	2025-05-07 12:37:50.249324+05:30
1429	1	\N	1	Pytest HTTP Text Msg 124334	2025-05-07 12:43:34.054157+05:30
1430	1	\N	1	Pytest Chat msg w/ media 124334	2025-05-07 12:43:34.079511+05:30
1431	1	\N	1	Pytest HTTP Text Msg 124709	2025-05-07 12:47:09.831023+05:30
1432	1	\N	1	Pytest Chat msg w/ media 124709	2025-05-07 12:47:09.85637+05:30
1433	1	\N	1	Pytest HTTP Text Msg 125140	2025-05-07 12:51:40.588042+05:30
1434	1	\N	1	Pytest Chat msg w/ media 125140	2025-05-07 12:51:40.617824+05:30
1435	1	\N	1	Pytest HTTP Text Msg 125515	2025-05-07 12:55:15.076804+05:30
1436	1	\N	1	Pytest Chat msg w/ media 125515	2025-05-07 12:55:15.100717+05:30
1437	1	\N	1	Pytest HTTP Text Msg 125838	2025-05-07 12:58:38.079362+05:30
1438	1	\N	1	Pytest Chat msg w/ media 125838	2025-05-07 12:58:38.104535+05:30
1439	1	\N	1	Pytest HTTP Text Msg 130120	2025-05-07 13:01:20.870433+05:30
1440	1	\N	1	Pytest Chat msg w/ media 130120	2025-05-07 13:01:20.895788+05:30
1441	1	\N	1	Pytest HTTP Text Msg 130444	2025-05-07 13:04:44.807574+05:30
1442	1	\N	1	Pytest Chat msg w/ media 130444	2025-05-07 13:04:44.832093+05:30
1443	1	\N	1	Pytest HTTP Text Msg 130920	2025-05-07 13:09:20.549599+05:30
1444	1	\N	1	Pytest Chat msg w/ media 130920	2025-05-07 13:09:20.574777+05:30
1445	1	\N	1	Pytest HTTP Text Msg 131224	2025-05-07 13:12:24.336927+05:30
1446	1	\N	1	Pytest Chat msg w/ media 131224	2025-05-07 13:12:24.364081+05:30
1447	1	\N	1	Pytest HTTP Text Msg 131540	2025-05-07 13:15:40.228315+05:30
1448	1	\N	1	Pytest Chat msg w/ media 131540	2025-05-07 13:15:40.256381+05:30
1449	1	\N	1	Pytest HTTP Text Msg 131833	2025-05-07 13:18:33.758477+05:30
1450	1	\N	1	Pytest Chat msg w/ media 131833	2025-05-07 13:18:33.784406+05:30
1451	1	\N	1	Pytest HTTP Text Msg 132251	2025-05-07 13:22:51.181863+05:30
1452	1	\N	1	Pytest Chat msg w/ media 132251	2025-05-07 13:22:51.20766+05:30
1453	1	\N	1	Pytest HTTP Text Msg 133427	2025-05-07 13:34:27.205508+05:30
1454	1	\N	1	Pytest Chat msg w/ media 133427	2025-05-07 13:34:27.230804+05:30
1455	1	\N	1	Pytest HTTP Text Msg 150155	2025-05-07 15:01:55.853302+05:30
1456	1	\N	1	Pytest Chat msg w/ media 150155	2025-05-07 15:01:55.880386+05:30
1457	1	\N	1	Pytest HTTP Text Msg 152103	2025-05-07 15:21:03.648086+05:30
1458	1	\N	1	Pytest Chat msg w/ media 152103	2025-05-07 15:21:03.675202+05:30
1459	1	\N	1	Pytest HTTP Text Msg 152727	2025-05-07 15:27:27.90426+05:30
1460	1	\N	1	Pytest Chat msg w/ media 152727	2025-05-07 15:27:27.932322+05:30
1461	1	\N	1	Pytest HTTP Text Msg 153956	2025-05-07 15:39:56.271176+05:30
1462	1	\N	1	Pytest Chat msg w/ media 153956	2025-05-07 15:39:56.299196+05:30
1463	1	\N	1	Pytest HTTP Text Msg 154242	2025-05-07 15:42:42.241054+05:30
1464	1	\N	1	Pytest Chat msg w/ media 154242	2025-05-07 15:42:42.270608+05:30
1465	1	\N	1	Pytest HTTP Text Msg 155013	2025-05-07 15:50:13.892471+05:30
1466	1	\N	1	Pytest Chat msg w/ media 155013	2025-05-07 15:50:13.921348+05:30
1467	1	\N	1	Pytest HTTP Text Msg 155303	2025-05-07 15:53:03.871566+05:30
1468	1	\N	1	Pytest Chat msg w/ media 155303	2025-05-07 15:53:03.90046+05:30
1469	1	\N	1	Pytest HTTP Text Msg 155503	2025-05-07 15:55:03.69294+05:30
1470	1	\N	1	Pytest Chat msg w/ media 155503	2025-05-07 15:55:03.725491+05:30
1471	1	\N	1	Pytest HTTP Text Msg 160454	2025-05-07 16:04:54.124703+05:30
1472	1	\N	1	Pytest Chat msg w/ media 160454	2025-05-07 16:04:54.156971+05:30
1473	1	\N	1	Pytest HTTP Text Msg 160956	2025-05-07 16:09:56.155861+05:30
1474	1	\N	1	Pytest Chat msg w/ media 160956	2025-05-07 16:09:56.188323+05:30
1475	4	\N	1	kuch nhi	2025-05-07 18:08:17.524629+05:30
\.


--
-- Data for Name: communities; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.communities (id, name, description, created_by, created_at, interest, location, location_address) FROM stdin;
1	Tech Enthusiasts	A community for tech lovers	1	2025-03-05 08:58:09.725786+05:30	Tech	\N	\N
2	Gaming Hub	Discuss latest games and updates	2	2025-03-05 08:58:09.725786+05:30	Gaming	\N	\N
3	Book Readers	Share and review books	3	2025-03-05 08:58:09.725786+05:30	Other	\N	\N
12	Kanisk Fan club	people who are die hard fans of kanishk	5	2025-03-31 18:29:40.977342+05:30	Social	\N	\N
4	Fitness Freaks	A place to discuss workouts and nutrition	1	2025-03-05 08:58:09.725786+05:30	Sports	\N	\N
5	AI & ML Researchers	Community for AI and ML discussions	2	2025-03-05 08:58:09.725786+05:30	Science	\N	\N
11	Star Wars	a starwars fan club event	5	2025-03-31 00:28:39.951593+05:30	Other	\N	\N
13	IPL Betting	We collectively make a informed decision by complex calculation and mathematical analysis and use startegic investment plans	5	2025-04-01 15:35:16.984086+05:30	Sports	\N	\N
14	White Girl Song Fan Club	Fans of Taylor Swift, Katy Perry, Miley Cyrus, Olivia Rodrigo and Sabrina Carpenter	5	2025-04-01 18:31:31.511088+05:30	Music	\N	\N
15	Content Creators	All content creators join for collab	5	2025-04-06 02:57:23.252936+05:30	Social	\N	\N
16	lol	...	4	2025-04-15 12:33:34.069313+05:30	Science	\N	\N
120	Pytest Community 175705063625	Test	1	2025-05-06 17:57:05.083744+05:30	Music	\N	\N
121	Pytest Community 105953369530	Test	1	2025-05-07 10:59:53.39297+05:30	Music	\N	\N
145	Pytest Community 152730452783	Test	1	2025-05-07 15:27:30.470872+05:30	Music	\N	\N
\.


--
-- Data for Name: community_logo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.community_logo (community_id, media_id, set_at) FROM stdin;
16	10	2025-05-04 01:34:52.045248+05:30
1	330	2025-05-07 16:09:59.172736+05:30
\.


--
-- Data for Name: community_members; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.community_members (id, user_id, community_id, joined_at) FROM stdin;
1	1	1	2025-03-12 10:57:33.176098+05:30
2	2	1	2025-03-12 10:57:33.176098+05:30
3	3	1	2025-03-12 10:57:33.176098+05:30
4	1	2	2025-03-12 10:57:33.176098+05:30
5	2	3	2025-03-12 10:57:33.176098+05:30
6	3	3	2025-03-12 10:57:33.176098+05:30
7	1	4	2025-03-12 10:57:33.176098+05:30
8	2	5	2025-03-12 10:57:33.176098+05:30
2846	1055	4	2025-04-26 20:01:37.671852+05:30
2826	5	4	2025-04-24 12:00:04.19824+05:30
2849	1	12	2025-04-28 15:06:32.270834+05:30
15	5	11	2025-03-31 12:20:44.841498+05:30
17	5	12	2025-03-31 18:29:40.977342+05:30
21	5	13	2025-04-01 15:35:16.984086+05:30
26	4	12	2025-04-02 11:53:42.490958+05:30
2844	4	13	2025-04-25 14:02:39.51306+05:30
47	4	16	2025-04-15 12:33:34.069313+05:30
54	1	14	2025-04-21 15:43:22.488577+05:30
56	4	1	2025-04-22 15:43:25.240319+05:30
57	4	4	2025-04-23 13:37:51.641731+05:30
2847	1056	4	2025-04-26 20:32:02.365403+05:30
2850	1055	16	2025-04-29 14:06:08.722995+05:30
2848	1056	13	2025-04-26 20:40:24.817139+05:30
2852	5	14	2025-04-30 18:23:09.054513+05:30
2855	4	14	2025-05-01 15:20:06.963982+05:30
2856	4	15	2025-05-01 15:20:09.342964+05:30
2857	4	2	2025-05-01 15:40:39.640447+05:30
2858	4	5	2025-05-01 15:40:39.707857+05:30
2825	1	16	2025-04-24 01:58:03.572901+05:30
2843	1	13	2025-04-25 00:11:52.495565+05:30
\.


--
-- Data for Name: community_posts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.community_posts (id, community_id, post_id, added_at) FROM stdin;
1	1	1	2025-03-12 10:58:37.331211+05:30
2	1	2	2025-03-12 10:58:37.331211+05:30
3	2	3	2025-03-12 10:58:37.331211+05:30
4	2	4	2025-03-12 10:58:37.331211+05:30
5	3	5	2025-03-12 10:58:37.331211+05:30
6	3	6	2025-03-12 10:58:37.331211+05:30
7	4	7	2025-03-12 10:58:37.331211+05:30
8	4	8	2025-03-12 10:58:37.331211+05:30
9	5	9	2025-03-12 10:58:37.331211+05:30
10	5	10	2025-03-12 10:58:37.331211+05:30
12	1	10	2025-03-12 11:13:56.695975+05:30
\.


--
-- Data for Name: event_participants; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.event_participants (id, event_id, user_id, joined_at) FROM stdin;
1	1	1	2025-03-31 01:09:14.664311+05:30
2	1	4	2025-03-31 01:09:14.664311+05:30
3	1	5	2025-03-31 01:09:14.664311+05:30
4	2	4	2025-03-31 01:09:14.675368+05:30
5	3	5	2025-03-31 01:09:14.686503+05:30
6	4	4	2025-03-31 12:00:54.461422+05:30
11	6	1	2025-04-02 11:56:24.914574+05:30
13	6	4	2025-04-02 11:57:00.567004+05:30
21	8	5	2025-04-03 22:48:17.3868+05:30
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.events (id, community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url, created_at, location_coords) FROM stdin;
1	1	1	Tech Talk: Future of AI	Discussing advancements in AI and ML.	Online (Zoom)	2025-04-03 01:09:14.605861+05:30	50	https://images.unsplash.com/photo-1593349114759-15e4b8a451a7	2025-03-31 01:09:14.605861+05:30	\N
2	1	4	Weekly Coding Meetup	Casual coding session, bring your projects!	Community Hub Room A	2025-04-01 11:09:14.605861+05:30	20	\N	2025-03-31 01:09:14.605861+05:30	\N
3	2	5	Morning Yoga Session	Relaxing yoga session to start the day.	Central Park (East Meadow)	2025-03-31 13:09:14.605861+05:30	15	https://images.unsplash.com/photo-1544367567-0f2fcb009e0b	2025-03-31 01:09:14.605861+05:30	\N
4	11	4	lol		lol	2025-04-01 12:00:00+05:30	5	\N	2025-03-31 12:00:54.461422+05:30	\N
6	14	4	xxx		1,1	2025-04-03 11:54:00+05:30	5	\N	2025-04-02 11:55:02.234448+05:30	\N
8	13	5	csk vs rcb		1,1	2025-04-04 22:48:00+05:30	5	\N	2025-04-03 22:48:17.3868+05:30	\N
345	1	1	Test Event w/ Image 145129	Event banner test!	Virtual	2025-05-11 14:51:29.410244+05:30	100	\N	2025-05-04 14:51:30.326181+05:30	\N
346	1	1	Test Event w/ Image 200358	Event banner test!	Virtual	2025-05-11 20:03:58.301056+05:30	100	\N	2025-05-04 20:03:59.230308+05:30	\N
347	1	1	Test Event w/ Img 215045	Banner test!	Virtual	2025-05-11 21:50:45.864876+05:30	100	media/communities/tech_enthusiasts/events/6dfdb6b7-571c-4b5a-b36d-ec99ed1fab09.png	2025-05-04 21:50:46.899435+05:30	\N
348	1	1	Test Event w/ Img 215651	Banner test!	Virtual	2025-05-11 21:56:51.318174+05:30	100	media/communities/tech_enthusiasts/events/fe0ece8b-3110-4973-8415-dec92d378f6d.png	2025-05-04 21:56:52.292204+05:30	\N
349	1	1	Test Event w/ Img 215935	Banner test!	Virtual	2025-05-11 21:59:35.103493+05:30	100	communities/tech_enthusiasts/events/e1096d26-1b78-435c-985a-763e065d399a.txt	2025-05-04 21:59:36.274938+05:30	\N
350	1	1	Test Event w/ Img 093650	Banner test!	Virtual	2025-05-12 09:36:50.188771+05:30	100	communities/tech_enthusiasts/events/ebf23f2a-37e8-44ed-891c-0e4da55e5731.txt	2025-05-05 09:36:51.937078+05:30	\N
351	1	1	Test Event w/ Img 115011	Banner test!	Virtual	2025-05-12 11:50:11.361152+05:30	100	communities/tech_enthusiasts/events/43a1b05c-3a4b-4a9c-b0ba-b237b92e6ab4.txt	2025-05-05 11:50:13.198323+05:30	\N
352	1	4	Test Event w/ Img 115154	Banner test!	Virtual	2025-05-12 11:51:54.87853+05:30	100	communities/tech_enthusiasts/events/eeb61dda-0534-40de-84b3-820d401b997f.txt	2025-05-05 11:51:56.80241+05:30	\N
353	1	1	Test Event w/ Img 155108	Banner test!	Virtual	2025-05-12 15:51:08.25981+05:30	100	communities/tech_enthusiasts/events/f52f922e-aa4d-446d-991d-117e7fdfbcf3.txt	2025-05-05 15:51:10.272179+05:30	\N
354	1	1	Test Event w/ Img 160130	Banner test!	Virtual	2025-05-12 16:01:30.260423+05:30	100	communities/tech_enthusiasts/events/d31424c6-3e67-485d-9acd-20a50f53d839.txt	2025-05-05 16:01:32.991297+05:30	\N
355	1	1	Test Event w/ Img 165324	Banner test!	Virtual	2025-05-12 16:53:24.749299+05:30	100	communities/tech_enthusiasts/events/5f0d4eb1-9ebe-4d45-ba51-8201b07839bc.txt	2025-05-05 16:53:26.853184+05:30	\N
356	1	1	Test Event w/ Img 163149	Banner test!	Virtual	2025-05-13 16:31:49.492749+05:30	100	communities/tech_enthusiasts/events/b87776df-4faf-43eb-9868-610f0e0097f9.txt	2025-05-06 16:32:06.645185+05:30	\N
357	1	1	Test Event w/ Img 171107	Banner test!	Virtual	2025-05-13 17:11:07.326515+05:30	100	communities/tech_enthusiasts/events/888bedde-a330-4938-a26f-4a8c5722a7d5.txt	2025-05-06 17:11:09.559246+05:30	\N
358	1	1	Test Event w/ Img 174239	Banner test!	Virtual	2025-05-13 17:42:39.003402+05:30	100	communities/tech_enthusiasts/events/681730f6-ec8e-49a9-9c27-42cfc5fdf649.txt	2025-05-06 17:42:41.328646+05:30	\N
359	1	1	Test Event w/ Img 174356	Banner test!	Virtual	2025-05-13 17:43:56.825738+05:30	100	communities/tech_enthusiasts/events/299fe218-3b6b-4b25-ade1-257b2064788b.txt	2025-05-06 17:43:59.037682+05:30	\N
360	1	1	Test Event w/ Img 092016	Banner test!	Virtual	2025-05-14 09:20:16.496348+05:30	100	communities/tech_enthusiasts/events/8c792a33-9f16-4941-a0b6-96b8eaf308c7.txt	2025-05-07 09:20:19.188556+05:30	\N
383	1	1	Pytest Event w/ Img 155020	Banner!	Virtual	2025-05-21 15:50:20.458144+05:30	50	media/communities/tech_enthusiasts/events/8a265cc1-32fd-4751-aeb1-cc51f78c90e8.png	2025-05-07 15:50:20.477722+05:30	\N
\.


--
-- Data for Name: media_items; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.media_items (id, uploader_user_id, minio_object_name, mime_type, file_size_bytes, original_filename, created_at, width, height, duration_seconds) FROM stdin;
225	1	media/communities/1/chat/1428/7cc5a99c-25b3-440c-a678-1af97a6abc95.png	image/png	172650	icon.png	2025-05-07 12:37:50.249324+05:30	\N	\N	\N
329	1	media/communities/1/chat/1474/b1e2265c-78ee-4dca-9804-721a03864d12.png	image/png	172650	icon.png	2025-05-07 16:09:56.188323+05:30	\N	\N	\N
4	1	media/posts/52/0fbe1d38-9417-4425-a8fe-9f3a80fdfdb7.png	image/png	46573	one-for-all.png	2025-05-04 00:35:08.330567+05:30	\N	\N	\N
6	1	media/posts/53/48fb25ea-9bd8-46d1-adf1-cf52a35d9a64.png	image/png	46573	one-for-all.png	2025-05-04 00:45:32.374212+05:30	\N	\N	\N
7	1	communities/tech_enthusiasts/logo/117cc9ea-9272-4dea-80eb-75343e95990f.png	image/png	46573	one-for-all.png	2025-05-04 01:19:34.355961+05:30	\N	\N	\N
8	1	media/posts/54/13a80e44-20b5-4824-a08d-04040f45dd97.png	image/png	46573	one-for-all.png	2025-05-04 01:19:35.437882+05:30	\N	\N	\N
9	4	media/posts/55/2c41fd64-9764-4261-bec4-d6f4642f4b4c.png	image/png	46573	one-for-all.png	2025-05-04 01:20:00.246311+05:30	\N	\N	\N
10	4	communities/lol/logo/fd7ae1c3-4e85-40d8-b1f9-83a0cc058681.png	image/png	46573	one-for-all.png	2025-05-04 01:34:52.045248+05:30	\N	\N	\N
11	4	media/posts/56/86ad7676-9616-44e5-ad5b-e9908a07af1b.png	image/png	46573	one-for-all.png	2025-05-04 01:34:53.393773+05:30	\N	\N	\N
12	1	communities/tech_enthusiasts/logo/e2d4636f-81c4-4478-b07f-3ffeda6fa060.png	image/png	46573	one-for-all.png	2025-05-04 01:40:59.478677+05:30	\N	\N	\N
13	1	media/posts/57/91fcc430-0055-411c-b757-fdc2a2744fee.png	image/png	46573	one-for-all.png	2025-05-04 01:41:00.956535+05:30	\N	\N	\N
45	1	communities/tech_enthusiasts/logo/5fd13f16-44c6-4056-8538-f66b7f95ad91.png	image/png	46573	one-for-all.png	2025-05-04 12:44:36.897616+05:30	\N	\N	\N
46	1	media/posts/90/c78738a4-a254-48c7-a771-194d258fae62.png	image/png	46573	one-for-all.png	2025-05-04 12:44:38.130397+05:30	\N	\N	\N
47	1	communities/tech_enthusiasts/logo/c9c07e54-e9e0-4a7c-9830-c6e78970c3f3.png	image/png	46573	one-for-all.png	2025-05-04 13:26:42.334242+05:30	\N	\N	\N
48	1	media/posts/91/cd3ca89a-bbf5-455d-9dc1-b93a85fd4d98.png	image/png	46573	one-for-all.png	2025-05-04 13:26:44.650481+05:30	\N	\N	\N
49	1	media/posts/91/dad23928-541a-42bf-a8b4-cd465ebbba9e.txt	text/plain	41	test_upload.txt	2025-05-04 13:26:44.650481+05:30	\N	\N	\N
50	1	communities/tech_enthusiasts/logo/20360bcd-eb28-447d-b472-64ff7ac13144.png	image/png	46573	one-for-all.png	2025-05-04 14:17:24.087489+05:30	\N	\N	\N
51	1	communities/tech_enthusiasts/logo/8fe7709a-fa97-419c-8000-a2f30d7d5729.png	image/png	46573	one-for-all.png	2025-05-04 14:37:28.880263+05:30	\N	\N	\N
52	1	communities/tech_enthusiasts/logo/0225cf31-5b42-4d39-9859-22fa545b8313.png	image/png	46573	one-for-all.png	2025-05-04 14:42:05.459474+05:30	\N	\N	\N
53	1	communities/tech_enthusiasts/logo/064a17e9-c7fc-4491-a14b-9a34860dcdcc.png	image/png	46573	one-for-all.png	2025-05-04 14:44:09.937894+05:30	\N	\N	\N
54	1	communities/tech_enthusiasts/logo/1012340e-1783-419f-a1fd-7f73d7f60dd4.png	image/png	46573	one-for-all.png	2025-05-04 14:45:38.256606+05:30	\N	\N	\N
55	1	users/alicej/profile/1a700237-cc57-42f4-9755-ee93fd912d93.png	image/png	46573	one-for-all.png	2025-05-04 14:51:25.532882+05:30	\N	\N	\N
56	1	communities/tech_enthusiasts/logo/4e50f86e-972f-45d5-8aa8-ed20480cf97f.png	image/png	46573	one-for-all.png	2025-05-04 14:51:27.893183+05:30	\N	\N	\N
57	1	media/posts/92/20ebd7f6-8728-44c0-a5f1-8cb26a9ab7cf.png	image/png	46573	one-for-all.png	2025-05-04 14:51:30.744853+05:30	\N	\N	\N
58	1	media/posts/92/6122f1c5-2c6f-4f37-8e80-f6e89b6d9693.txt	text/plain	41	test_upload.txt	2025-05-04 14:51:30.744853+05:30	\N	\N	\N
61	1	media/posts/93/02678629-2845-4bb5-9bee-e030894981e5.png	image/png	46573	one-for-all.png	2025-05-04 20:03:59.908235+05:30	\N	\N	\N
62	1	media/posts/93/caa73975-4be0-4eca-bc9c-c115f53e63a5.txt	text/plain	41	test_upload.txt	2025-05-04 20:03:59.908235+05:30	\N	\N	\N
67	1	media/communities/1/chat/1390/ef6c1962-79ed-43af-95a0-1d6f6aeab18b.png	image/png	46573	one-for-all.png	2025-05-04 20:40:35.990989+05:30	\N	\N	\N
70	1	media/posts/96/a408b81f-f0f8-4342-b659-13e376157d12.png	image/png	46573	one-for-all.png	2025-05-04 21:05:17.446385+05:30	\N	\N	\N
71	1	media/posts/96/7eeecaf9-0022-4980-a39a-aba525587a43.txt	text/plain	41	test_upload.txt	2025-05-04 21:05:17.446385+05:30	\N	\N	\N
72	1	media/replies/94/b4ba1ee7-764d-4018-ba0c-7e9af1583911.png	image/png	46573	one-for-all.png	2025-05-04 21:05:19.16671+05:30	\N	\N	\N
75	1	media/posts/97/cd483702-be59-4a90-a3f9-30c524ec1867.png	image/png	46573	one-for-all.png	2025-05-04 21:07:27.769258+05:30	\N	\N	\N
76	1	media/posts/97/3c425eb6-15c4-4e5c-8421-3f8bb978ab52.txt	text/plain	41	test_upload.txt	2025-05-04 21:07:27.769258+05:30	\N	\N	\N
77	1	media/replies/95/4e01acef-645c-49d6-97aa-f6a1dbb45945.png	image/png	46573	one-for-all.png	2025-05-04 21:07:29.540563+05:30	\N	\N	\N
80	1	media/posts/98/0f58d965-36d0-47ff-9c89-af25e6b606ec.png	image/png	46573	one-for-all.png	2025-05-04 21:08:12.599386+05:30	\N	\N	\N
81	1	media/posts/98/d40b138c-43a2-4343-894d-e38976a05e16.txt	text/plain	41	test_upload.txt	2025-05-04 21:08:12.599386+05:30	\N	\N	\N
82	1	media/replies/96/b8a41147-2004-4f76-aa59-71bee05cca66.png	image/png	46573	one-for-all.png	2025-05-04 21:08:14.449345+05:30	\N	\N	\N
84	1	communities/tech_enthusiasts/logo/a50c9320-353d-423a-b4bc-fae54f655489.png	image/png	46573	one-for-all.png	2025-05-04 21:33:43.418705+05:30	\N	\N	\N
85	1	media/posts/99/772cb979-190a-45cc-994b-48d0160846aa.png	image/png	46573	one-for-all.png	2025-05-04 21:33:45.3464+05:30	\N	\N	\N
86	1	media/posts/99/b1c08cc8-7203-4cb5-b4ad-cd84690d3c4c.txt	text/plain	41	test_upload.txt	2025-05-04 21:33:45.3464+05:30	\N	\N	\N
87	1	media/replies/97/3927bfd2-7b5e-4606-a235-9237ec7a229a.png	image/png	46573	one-for-all.png	2025-05-04 21:33:47.063303+05:30	\N	\N	\N
90	1	media/posts/100/566d78f3-6854-4923-ae95-e569c71b1346.png	image/png	46573	one-for-all.png	2025-05-04 21:40:47.277436+05:30	\N	\N	\N
91	1	media/posts/100/c50159ec-2b53-4758-9a96-bf1c07d16814.txt	text/plain	41	test_upload.txt	2025-05-04 21:40:47.277436+05:30	\N	\N	\N
92	1	media/replies/98/0fe58d75-aafb-440e-8d73-e309f800c2af.png	image/png	46573	one-for-all.png	2025-05-04 21:40:49.476557+05:30	\N	\N	\N
93	1	media/communities/1/chat/1391/d7110b3a-c2ff-4583-894f-d97340e4afe1.png	image/png	46573	one-for-all.png	2025-05-04 21:40:50.969421+05:30	\N	\N	\N
96	1	media/posts/101/d10903d7-d706-4d43-9474-be9dc119b0ae.png	image/png	46573	one-for-all.png	2025-05-04 21:42:32.335466+05:30	\N	\N	\N
97	1	media/posts/101/68a23c81-af29-495c-8c08-372d2afe1a1f.txt	text/plain	41	test_upload.txt	2025-05-04 21:42:32.335466+05:30	\N	\N	\N
98	1	media/replies/99/d9d87026-cd8d-4497-86d9-caa733ff4753.png	image/png	46573	one-for-all.png	2025-05-04 21:42:34.268362+05:30	\N	\N	\N
99	1	media/communities/1/chat/1392/3edfe7fd-274f-4e48-985c-4f9bb547b107.png	image/png	46573	one-for-all.png	2025-05-04 21:42:35.75508+05:30	\N	\N	\N
102	1	media/posts/102/296a53dd-97b1-4899-b300-d42149fe4a5c.png	image/png	46573	one-for-all.png	2025-05-04 21:50:47.01382+05:30	\N	\N	\N
103	1	media/posts/102/ccb9f935-0739-487d-86a9-22b1849f0d43.txt	text/plain	41	test_upload.txt	2025-05-04 21:50:47.01382+05:30	\N	\N	\N
104	1	media/replies/100/4f25a40c-7feb-4a89-8161-d3db34354fb1.png	image/png	46573	one-for-all.png	2025-05-04 21:50:49.255698+05:30	\N	\N	\N
105	1	media/communities/1/chat/1393/be594938-4e95-4cb1-a73c-7a1b74fc292f.png	image/png	46573	one-for-all.png	2025-05-04 21:50:50.676153+05:30	\N	\N	\N
330	1	communities/tech_enthusiasts/logo/7ac9c867-386d-46ca-b6fc-7b82d57c4672.png	image/png	172650	icon.png	2025-05-07 16:09:59.172736+05:30	\N	\N	\N
108	1	media/posts/103/51ed0117-c905-44e2-bd63-b833e1582789.png	image/png	46573	one-for-all.png	2025-05-04 21:56:52.773619+05:30	\N	\N	\N
109	1	media/posts/103/5039e469-3b8d-4428-9929-9ade43daa56a.txt	text/plain	41	test_upload.txt	2025-05-04 21:56:52.773619+05:30	\N	\N	\N
110	1	media/replies/101/804e6f1b-3db9-4401-b955-08858bcbbbf3.png	image/png	46573	one-for-all.png	2025-05-04 21:56:54.522497+05:30	\N	\N	\N
111	1	media/communities/1/chat/1394/adf24387-0874-4906-9893-a79122d9c63f.png	image/png	46573	one-for-all.png	2025-05-04 21:56:56.12449+05:30	\N	\N	\N
114	1	media/posts/104/f182c155-23db-4d5f-972b-5ebb8ff24805.png	image/png	46573	one-for-all.png	2025-05-04 21:59:37.495276+05:30	\N	\N	\N
115	1	media/posts/104/abd8fa55-fd8e-4b37-a925-8805d8f4a40f.txt	text/plain	41	test_upload.txt	2025-05-04 21:59:37.495276+05:30	\N	\N	\N
116	1	media/replies/102/b12be298-c577-47a9-bc7f-3bd521d224db.png	image/png	46573	one-for-all.png	2025-05-04 21:59:39.215676+05:30	\N	\N	\N
117	1	media/communities/1/chat/1395/1af01c8f-b0fe-4029-8337-a103745fce76.png	image/png	46573	one-for-all.png	2025-05-04 21:59:40.469234+05:30	\N	\N	\N
120	1	media/posts/105/a9a0b0a6-8ed7-46e3-bb07-4fc67b231cb5.png	image/png	46573	one-for-all.png	2025-05-05 09:36:53.504064+05:30	\N	\N	\N
121	1	media/posts/105/f7b9e725-bb55-407c-a2e4-0425d077a05d.txt	text/plain	41	test_upload.txt	2025-05-05 09:36:53.504064+05:30	\N	\N	\N
122	1	media/replies/103/b831464c-198c-431f-9665-731a5c339363.png	image/png	46573	one-for-all.png	2025-05-05 09:36:56.243481+05:30	\N	\N	\N
123	1	media/communities/1/chat/1396/583d9680-5bae-4c67-ba2b-281da05ce141.png	image/png	46573	one-for-all.png	2025-05-05 09:36:58.229829+05:30	\N	\N	\N
126	1	media/posts/106/f9e0de2c-8fab-44b2-9f22-c11f7895aa6a.png	image/png	172650	icon.png	2025-05-05 11:50:14.807717+05:30	\N	\N	\N
127	1	media/posts/106/2b083df1-a1f4-4186-ba60-6922632549bc.txt	text/plain	41	test_upload.txt	2025-05-05 11:50:14.807717+05:30	\N	\N	\N
128	1	media/replies/104/5b7c2d45-8bd2-4bbc-bd97-84975171d369.png	image/png	172650	icon.png	2025-05-05 11:50:17.326467+05:30	\N	\N	\N
129	1	media/communities/1/chat/1397/944c3554-82d0-4bb8-b5c8-e31da356ae52.png	image/png	172650	icon.png	2025-05-05 11:50:19.563793+05:30	\N	\N	\N
130	4	users/divansh/profile/becb7ab6-285c-41df-8aba-2e2f26a4364c.png	image/png	172650	icon.png	2025-05-05 11:51:51.695493+05:30	\N	\N	\N
131	4	media/posts/107/687b3a85-4c41-4941-8f4f-07a7345e3391.png	image/png	172650	icon.png	2025-05-05 11:51:58.050094+05:30	\N	\N	\N
132	4	media/posts/107/f24547f5-502f-44e8-9602-6af45c6a984a.txt	text/plain	41	test_upload.txt	2025-05-05 11:51:58.050094+05:30	\N	\N	\N
133	4	media/replies/105/5a0e327a-6b94-4591-bbcc-14210df992b6.png	image/png	172650	icon.png	2025-05-05 11:52:00.952131+05:30	\N	\N	\N
134	4	media/communities/1/chat/1398/685e29f4-33ec-48f2-8c06-826dc9803337.png	image/png	172650	icon.png	2025-05-05 11:52:03.352813+05:30	\N	\N	\N
138	1	media/posts/109/07ab05bc-ff64-4711-8bfc-d21b6f785e5e.png	image/png	172650	icon.png	2025-05-05 15:51:11.393963+05:30	\N	\N	\N
139	1	media/posts/109/0a263e4d-e6de-4d7d-a356-81b51dc51eb6.txt	text/plain	41	test_upload.txt	2025-05-05 15:51:11.393963+05:30	\N	\N	\N
140	1	media/replies/107/29746d42-99da-4368-a2dc-a931d7a6b5aa.png	image/png	172650	icon.png	2025-05-05 15:51:14.459206+05:30	\N	\N	\N
141	1	media/communities/1/chat/1399/86adb389-53bc-4023-844e-f569bef131b8.png	image/png	172650	icon.png	2025-05-05 15:51:16.773965+05:30	\N	\N	\N
144	1	media/posts/110/75bfb424-3a99-4c63-9632-8377fce92fc1.png	image/png	172650	icon.png	2025-05-05 16:01:33.967182+05:30	\N	\N	\N
145	1	media/posts/110/2fd9d08c-8e52-4dbb-9c07-3840c6165aa5.txt	text/plain	41	test_upload.txt	2025-05-05 16:01:33.967182+05:30	\N	\N	\N
146	1	media/replies/108/d6a2400e-7336-4195-be9b-31b2da8e47f3.png	image/png	172650	icon.png	2025-05-05 16:01:36.70815+05:30	\N	\N	\N
147	1	media/communities/1/chat/1400/6acf4d72-6359-428b-8344-e062fe1dd780.png	image/png	172650	icon.png	2025-05-05 16:01:39.260753+05:30	\N	\N	\N
150	1	media/posts/111/447f250e-0098-469c-b4a9-0427e4b8dafe.png	image/png	172650	icon.png	2025-05-05 16:53:28.152359+05:30	\N	\N	\N
151	1	media/posts/111/596c1144-fa47-4108-9c9a-212fd2301502.txt	text/plain	41	test_upload.txt	2025-05-05 16:53:28.152359+05:30	\N	\N	\N
152	1	media/replies/109/4d4cdfa2-671f-4a55-9691-2c9980ee62a8.png	image/png	172650	icon.png	2025-05-05 16:53:31.102823+05:30	\N	\N	\N
153	1	media/communities/1/chat/1401/75393f31-1ebd-4c13-b771-4a01cb630159.png	image/png	172650	icon.png	2025-05-05 16:53:33.608466+05:30	\N	\N	\N
154	1	media/posts/113/b0670c69-6eb3-468b-a8f0-10277aa11f63.txt	text/plain	56	test_upload_posts.txt	2025-05-06 16:12:24.786576+05:30	\N	\N	\N
157	1	media/posts/114/7dffb6fd-2976-4cf1-99fa-16600f362f41.png	image/png	172650	icon.png	2025-05-06 16:32:08.335287+05:30	\N	\N	\N
158	1	media/posts/114/f6342731-c59e-4d38-a95c-814d17549286.txt	text/plain	41	test_upload.txt	2025-05-06 16:32:08.335287+05:30	\N	\N	\N
159	1	media/replies/111/2b25775f-9394-4d13-bfd5-24899d2eca59.png	image/png	172650	icon.png	2025-05-06 16:32:23.857254+05:30	\N	\N	\N
160	1	media/communities/1/chat/1402/89216792-bb36-4449-9583-c3bfc496ce09.png	image/png	172650	icon.png	2025-05-06 16:32:37.125914+05:30	\N	\N	\N
161	1	media/posts/116/586abddc-3f3c-4bb4-87d0-49a89b2ac8a6.txt	text/plain	42	test_upload_posts.txt	2025-05-06 16:45:18.761372+05:30	\N	\N	\N
164	1	media/posts/117/a456c6cb-e7f0-4aea-acb1-a7c32fb97992.png	image/png	172650	icon.png	2025-05-06 17:11:10.682421+05:30	\N	\N	\N
165	1	media/posts/117/c7455b19-83ca-4237-986f-5a4bf2c840b8.txt	text/plain	41	test_upload.txt	2025-05-06 17:11:10.682421+05:30	\N	\N	\N
166	1	media/replies/113/6647d573-333a-41e5-9438-c4c4f169a128.png	image/png	172650	icon.png	2025-05-06 17:11:13.568918+05:30	\N	\N	\N
167	1	media/communities/1/chat/1403/ebff1f27-c2e7-4cdf-a83c-27081babfcf7.png	image/png	172650	icon.png	2025-05-06 17:11:16.228793+05:30	\N	\N	\N
171	1	media/posts/120/78aba259-0145-43e1-995d-36f8bdcaeedd.png	image/png	172650	icon.png	2025-05-06 17:42:42.738487+05:30	\N	\N	\N
172	1	media/posts/120/fad07a16-3988-43aa-a06b-0fee0f2bad47.txt	text/plain	41	test_upload.txt	2025-05-06 17:42:42.738487+05:30	\N	\N	\N
173	1	media/replies/115/441aa23c-1c6d-4466-914b-76a5e63b73fd.png	image/png	172650	icon.png	2025-05-06 17:42:45.824149+05:30	\N	\N	\N
174	1	media/communities/1/chat/1404/653df16e-8332-423c-bc7d-ec200329ade9.png	image/png	172650	icon.png	2025-05-06 17:42:48.53193+05:30	\N	\N	\N
177	1	media/posts/121/ab784481-a1d3-4e73-9d4d-8bb84aa95556.png	image/png	172650	icon.png	2025-05-06 17:43:59.987437+05:30	\N	\N	\N
178	1	media/posts/121/35617d50-400c-419b-8c4b-70cca97d8c10.txt	text/plain	41	test_upload.txt	2025-05-06 17:43:59.987437+05:30	\N	\N	\N
179	1	media/replies/116/d12d7997-d96a-4c80-8b5a-0ce21274177a.png	image/png	172650	icon.png	2025-05-06 17:44:02.558028+05:30	\N	\N	\N
180	1	media/communities/1/chat/1405/4ec5005b-f34a-43fe-9a45-c2cbd60ee58c.png	image/png	172650	icon.png	2025-05-06 17:44:05.138553+05:30	\N	\N	\N
182	1	users/alicej/profile/0bbcbe05-218a-4a2d-aee1-39ba85e9481d.png	image/png	172650	icon.png	2025-05-07 09:20:08.540481+05:30	\N	\N	\N
184	1	media/posts/126/38918183-c308-422c-9267-9b9ea33af851.png	image/png	172650	icon.png	2025-05-07 09:20:20.720609+05:30	\N	\N	\N
185	1	media/posts/126/4c728017-d1fa-46d7-a7af-da945804f980.txt	text/plain	41	test_upload.txt	2025-05-07 09:20:20.720609+05:30	\N	\N	\N
186	1	media/replies/118/a8eff7db-aea9-4e92-8a15-aaad1ff7c333.png	image/png	172650	icon.png	2025-05-07 09:20:23.906467+05:30	\N	\N	\N
187	1	media/communities/1/chat/1408/c703ca64-87ac-4380-aa9a-de249236b127.png	image/png	172650	icon.png	2025-05-07 09:20:26.710543+05:30	\N	\N	\N
188	1	media/posts/128/ff217b50-05a6-4e12-b2e1-206ced0160d3.txt	text/plain	42	test_upload_posts.txt	2025-05-07 10:59:55.415321+05:30	\N	\N	\N
230	1	media/communities/1/chat/1430/a3047e26-c15e-429d-bd0f-3f04e945550e.png	image/png	172650	icon.png	2025-05-07 12:43:34.079511+05:30	\N	\N	\N
190	1	media/communities/1/chat/1414/fef13de8-daa2-404a-9720-8e275b149ae9.png	image/png	172650	icon.png	2025-05-07 11:36:21.061673+05:30	\N	\N	\N
193	1	media/posts/132/7fb94c41-b0c1-4b74-a83c-a471d78ec095.txt	text/plain	42	test_upload_posts.txt	2025-05-07 11:36:35.433558+05:30	\N	\N	\N
195	1	media/communities/1/chat/1416/b5afd220-96b9-4e22-98e1-3587438ce5b5.png	image/png	172650	icon.png	2025-05-07 11:46:19.946239+05:30	\N	\N	\N
235	1	media/communities/1/chat/1432/676ffb7d-8c03-4f0c-bdac-0e062d864fff.png	image/png	172650	icon.png	2025-05-07 12:47:09.85637+05:30	\N	\N	\N
200	1	media/communities/1/chat/1418/48644dc5-5381-49a9-b9cd-83cdd598a486.png	image/png	172650	icon.png	2025-05-07 12:07:42.353748+05:30	\N	\N	\N
240	1	media/communities/1/chat/1434/78bd92ba-e056-4a4a-bd20-2f7225b5d8be.png	image/png	172650	icon.png	2025-05-07 12:51:40.617824+05:30	\N	\N	\N
205	1	media/communities/1/chat/1420/4140d8df-fc66-4d4f-9180-0d45104f4992.png	image/png	172650	icon.png	2025-05-07 12:22:18.941412+05:30	\N	\N	\N
245	1	media/communities/1/chat/1436/020dc7c7-1f66-4ca4-94d5-7f66b2a4030e.png	image/png	172650	icon.png	2025-05-07 12:55:15.100717+05:30	\N	\N	\N
210	1	media/communities/1/chat/1422/bf2c2bd1-f27d-4826-9106-6194a7c5fd93.png	image/png	172650	icon.png	2025-05-07 12:26:59.411733+05:30	\N	\N	\N
250	1	media/communities/1/chat/1438/ec1c89ae-8bd9-4a40-bdbb-ba15f69f9827.png	image/png	172650	icon.png	2025-05-07 12:58:38.104535+05:30	\N	\N	\N
215	1	media/communities/1/chat/1424/4aad5fa0-881f-4356-bd5d-09589cc06fa6.png	image/png	172650	icon.png	2025-05-07 12:30:49.065626+05:30	\N	\N	\N
220	1	media/communities/1/chat/1426/76666fda-9267-4f31-82c9-03077ae8b2e1.png	image/png	172650	icon.png	2025-05-07 12:33:11.824441+05:30	\N	\N	\N
255	1	media/communities/1/chat/1440/c1522187-79f7-4a28-a4f7-9131592d884e.png	image/png	172650	icon.png	2025-05-07 13:01:20.895788+05:30	\N	\N	\N
260	1	media/communities/1/chat/1442/c38eb6d1-ebd7-4439-b28e-2deedb4b8492.png	image/png	172650	icon.png	2025-05-07 13:04:44.832093+05:30	\N	\N	\N
265	1	media/communities/1/chat/1444/fb906e9c-667f-4b65-89f1-1bbdfc179099.png	image/png	172650	icon.png	2025-05-07 13:09:20.574777+05:30	\N	\N	\N
270	1	media/communities/1/chat/1446/b61ac7ab-8db7-4806-a0dd-d4477f119109.png	image/png	172650	icon.png	2025-05-07 13:12:24.364081+05:30	\N	\N	\N
275	1	media/communities/1/chat/1448/7c690e25-7497-4cd7-8c2a-e45762a70a12.png	image/png	172650	icon.png	2025-05-07 13:15:40.256381+05:30	\N	\N	\N
280	1	media/communities/1/chat/1450/7d52b541-211e-4098-82be-7ff2e084623f.png	image/png	172650	icon.png	2025-05-07 13:18:33.784406+05:30	\N	\N	\N
285	1	media/communities/1/chat/1452/164a6f60-2293-4c06-93fd-09fff9ee115a.png	image/png	172650	icon.png	2025-05-07 13:22:51.20766+05:30	\N	\N	\N
290	1	media/communities/1/chat/1454/9ec51950-0d8f-46d4-aa3e-694a4ae0fdb8.png	image/png	172650	icon.png	2025-05-07 13:34:27.230804+05:30	\N	\N	\N
295	1	media/communities/1/chat/1456/952c6706-e41f-481e-b41d-de634a7d35ed.png	image/png	172650	icon.png	2025-05-07 15:01:55.880386+05:30	\N	\N	\N
300	1	media/communities/1/chat/1458/4b29227b-4de6-43b7-8abe-d9239113653a.png	image/png	172650	icon.png	2025-05-07 15:21:03.675202+05:30	\N	\N	\N
302	1	media/communities/1/chat/1460/9461c98b-74d6-4e37-a21f-39fc77ad0dc7.png	image/png	172650	icon.png	2025-05-07 15:27:27.932322+05:30	\N	\N	\N
304	1	media/communities/1/chat/1462/d4cc6ddf-6899-4fc2-8e85-6be4378f30c8.png	image/png	172650	icon.png	2025-05-07 15:39:56.299196+05:30	\N	\N	\N
309	1	media/communities/1/chat/1464/60cd1bde-ddce-451b-9cc0-49a40b2b824b.png	image/png	172650	icon.png	2025-05-07 15:42:42.270608+05:30	\N	\N	\N
314	1	media/communities/1/chat/1466/555c520e-960e-4a9c-8e7d-181e22744b01.png	image/png	172650	icon.png	2025-05-07 15:50:13.921348+05:30	\N	\N	\N
317	1	media/communities/1/chat/1468/c25f4935-f765-441a-a60d-bacc94876892.png	image/png	172650	icon.png	2025-05-07 15:53:03.90046+05:30	\N	\N	\N
319	1	media/communities/1/chat/1470/1cdc9d50-c49c-4137-b863-974f02877eb3.png	image/png	172650	icon.png	2025-05-07 15:55:03.725491+05:30	\N	\N	\N
324	1	media/communities/1/chat/1472/38f81bf2-5f96-43ce-b510-efb5042b6d56.png	image/png	172650	icon.png	2025-05-07 16:04:54.156971+05:30	\N	\N	\N
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notifications (id, recipient_user_id, actor_user_id, type, related_entity_type, related_entity_id, content_preview, is_read, created_at) FROM stdin;
1	2	1	post_reply	post	2	alicej replied: "Test reply for notification generation!"	f	2025-05-07 15:02:05.644298+05:30
2	2	1	post_reply	post	2	alicej replied: "Pytest reply no media 150209"	f	2025-05-07 15:02:09.493806+05:30
3	2	1	post_reply	post	2	alicej replied: "Pytest reply w/ media 150209"	f	2025-05-07 15:02:09.531969+05:30
4	5	1	new_follower	user	1	alicej started following you.	f	2025-05-07 15:02:12.602872+05:30
5	2	1	post_reply	post	2	alicej replied: "Test reply for notification generation!"	f	2025-05-07 15:21:08.010725+05:30
6	2	1	post_reply	post	2	alicej replied: "Pytest reply no media 152108"	f	2025-05-07 15:21:08.827013+05:30
7	2	1	post_reply	post	2	alicej replied: "Pytest reply w/ media 152108"	f	2025-05-07 15:21:08.862453+05:30
8	5	1	new_follower	user	1	alicej started following you.	f	2025-05-07 15:21:12.385026+05:30
9	2	1	post_reply	post	2	alicej replied: "Test reply for notification generation!"	f	2025-05-07 15:40:08.9821+05:30
10	2	1	community_post	post	175	New post in Tech Enthusiasts: "Pytest Post NoMedia 154009..."	f	2025-05-07 15:40:09.585683+05:30
11	3	1	community_post	post	175	New post in Tech Enthusiasts: "Pytest Post NoMedia 154009..."	f	2025-05-07 15:40:09.585683+05:30
12	2	1	community_post	post	176	New post in Tech Enthusiasts: "Pytest Post MultiMedia 154009..."	f	2025-05-07 15:40:09.62523+05:30
13	3	1	community_post	post	176	New post in Tech Enthusiasts: "Pytest Post MultiMedia 154009..."	f	2025-05-07 15:40:09.62523+05:30
14	2	1	post_reply	post	2	alicej replied: "Pytest reply no media 154013"	f	2025-05-07 15:40:14.002044+05:30
15	2	1	post_reply	post	2	alicej replied: "Pytest reply w/ media 154014"	f	2025-05-07 15:40:14.0387+05:30
16	5	1	new_follower	user	1	alicej started following you.	f	2025-05-07 15:40:17.696236+05:30
17	2	1	post_reply	post	2	alicej replied: "Test reply for notification generation!"	f	2025-05-07 15:42:54.106735+05:30
18	2	1	community_post	post	177	New post in Tech Enthusiasts: "Pytest Post NoMedia 154254..."	f	2025-05-07 15:42:54.727589+05:30
19	3	1	community_post	post	177	New post in Tech Enthusiasts: "Pytest Post NoMedia 154254..."	f	2025-05-07 15:42:54.727589+05:30
20	2	1	community_post	post	178	New post in Tech Enthusiasts: "Pytest Post MultiMedia 154254..."	f	2025-05-07 15:42:54.774576+05:30
21	3	1	community_post	post	178	New post in Tech Enthusiasts: "Pytest Post MultiMedia 154254..."	f	2025-05-07 15:42:54.774576+05:30
22	2	1	post_reply	post	2	alicej replied: "Pytest reply no media 154259"	f	2025-05-07 15:42:59.484014+05:30
23	2	1	post_reply	post	2	alicej replied: "Pytest reply w/ media 154259"	f	2025-05-07 15:42:59.522399+05:30
24	5	1	new_follower	user	1	alicej started following you.	f	2025-05-07 15:43:03.090769+05:30
25	2	1	new_community_event	event	383	New event in Tech Enthusiasts: "Pytest Event w/ Img 155020..."	f	2025-05-07 15:50:20.477722+05:30
26	3	1	new_community_event	event	383	New event in Tech Enthusiasts: "Pytest Event w/ Img 155020..."	f	2025-05-07 15:50:20.477722+05:30
27	2	1	new_community_event	event	384	New event in Tech Enthusiasts: "Pytest Event w/ Img 155512..."	f	2025-05-07 15:55:12.31818+05:30
28	3	1	new_community_event	event	384	New event in Tech Enthusiasts: "Pytest Event w/ Img 155512..."	f	2025-05-07 15:55:12.31818+05:30
29	2	1	post_reply	post	2	alicej replied: "Test reply for notification generation!"	f	2025-05-07 15:55:18.755801+05:30
30	2	1	community_post	post	179	New post in Tech Enthusiasts: "Pytest Post NoMedia 155519..."	f	2025-05-07 15:55:19.391672+05:30
31	3	1	community_post	post	179	New post in Tech Enthusiasts: "Pytest Post NoMedia 155519..."	f	2025-05-07 15:55:19.391672+05:30
32	2	1	community_post	post	180	New post in Tech Enthusiasts: "Pytest Post MultiMedia 155519..."	f	2025-05-07 15:55:19.43573+05:30
33	3	1	community_post	post	180	New post in Tech Enthusiasts: "Pytest Post MultiMedia 155519..."	f	2025-05-07 15:55:19.43573+05:30
34	2	1	post_reply	post	2	alicej replied: "Pytest reply no media 155524"	f	2025-05-07 15:55:24.387169+05:30
35	2	1	post_reply	post	2	alicej replied: "Pytest reply w/ media 155524"	f	2025-05-07 15:55:24.435601+05:30
36	5	1	new_follower	user	1	alicej started following you.	f	2025-05-07 15:55:28.479389+05:30
37	2	1	new_community_event	event	385	New event in Tech Enthusiasts: "Pytest Event w/ Img 160501..."	f	2025-05-07 16:05:01.120426+05:30
38	3	1	new_community_event	event	385	New event in Tech Enthusiasts: "Pytest Event w/ Img 160501..."	f	2025-05-07 16:05:01.120426+05:30
39	2	1	post_reply	post	2	alicej replied: "Test reply for notification generation!"	f	2025-05-07 16:05:06.210126+05:30
40	2	1	community_post	post	181	New post in Tech Enthusiasts: "Pytest Post NoMedia 160506..."	f	2025-05-07 16:05:06.84811+05:30
41	3	1	community_post	post	181	New post in Tech Enthusiasts: "Pytest Post NoMedia 160506..."	f	2025-05-07 16:05:06.84811+05:30
42	2	1	community_post	post	182	New post in Tech Enthusiasts: "Pytest Post MultiMedia 160506..."	f	2025-05-07 16:05:06.892111+05:30
43	3	1	community_post	post	182	New post in Tech Enthusiasts: "Pytest Post MultiMedia 160506..."	f	2025-05-07 16:05:06.892111+05:30
44	2	1	post_reply	post	2	alicej replied: "Pytest reply no media 160511"	f	2025-05-07 16:05:11.065887+05:30
45	2	1	post_reply	post	2	alicej replied: "Pytest reply w/ media 160511"	f	2025-05-07 16:05:11.108209+05:30
46	5	1	new_follower	user	1	alicej started following you.	f	2025-05-07 16:05:14.780181+05:30
47	2	1	new_community_event	event	386	New event in Tech Enthusiasts: "Pytest Event w/ Img 161002..."	f	2025-05-07 16:10:02.607986+05:30
48	3	1	new_community_event	event	386	New event in Tech Enthusiasts: "Pytest Event w/ Img 161002..."	f	2025-05-07 16:10:02.607986+05:30
49	2	1	post_reply	post	2	alicej replied: "Test reply for notification generation!"	f	2025-05-07 16:10:07.412849+05:30
50	2	1	community_post	post	183	New post in Tech Enthusiasts: "Pytest Post NoMedia 161008..."	f	2025-05-07 16:10:08.057146+05:30
51	3	1	community_post	post	183	New post in Tech Enthusiasts: "Pytest Post NoMedia 161008..."	f	2025-05-07 16:10:08.057146+05:30
52	2	1	community_post	post	184	New post in Tech Enthusiasts: "Pytest Post MultiMedia 161008..."	f	2025-05-07 16:10:08.09942+05:30
53	3	1	community_post	post	184	New post in Tech Enthusiasts: "Pytest Post MultiMedia 161008..."	f	2025-05-07 16:10:08.09942+05:30
54	2	1	post_reply	post	2	alicej replied: "Pytest reply no media 161012"	f	2025-05-07 16:10:12.624525+05:30
55	2	1	post_reply	post	2	alicej replied: "Pytest reply w/ media 161012"	f	2025-05-07 16:10:12.666353+05:30
56	5	1	new_follower	user	1	alicej started following you.	f	2025-05-07 16:10:16.643417+05:30
\.


--
-- Data for Name: post_favorites; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.post_favorites (id, user_id, post_id, favorited_at) FROM stdin;
1	2	1	2025-03-12 10:58:37.337404+05:30
2	3	2	2025-03-12 10:58:37.337404+05:30
3	1	3	2025-03-12 10:58:37.337404+05:30
4	3	7	2025-03-12 10:58:37.337404+05:30
5	2	10	2025-03-12 10:58:37.337404+05:30
\.


--
-- Data for Name: post_media; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.post_media (post_id, media_id, display_order) FROM stdin;
52	4	0
53	6	0
54	8	0
55	9	0
56	11	0
57	13	0
90	46	0
91	48	0
91	49	0
92	57	0
92	58	0
93	61	0
93	62	0
96	70	0
96	71	0
97	75	0
97	76	0
98	80	0
98	81	0
99	85	0
99	86	0
100	90	0
100	91	0
101	96	0
101	97	0
102	102	0
102	103	0
103	108	0
103	109	0
104	114	0
104	115	0
105	120	0
105	121	0
106	126	0
106	127	0
107	131	0
107	132	0
109	138	0
109	139	0
110	144	0
110	145	0
111	150	0
111	151	0
113	154	0
114	157	0
114	158	0
116	161	0
117	164	0
117	165	0
120	171	0
120	172	0
121	177	0
121	178	0
126	184	0
126	185	0
128	188	0
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.posts (id, user_id, content, created_at, title) FROM stdin;
1	1	Check out the new AI advancements this year!	2025-03-05 08:59:17.753175+05:30	Latest in Tech
2	2	Exploring the future of computation.	2025-03-05 08:59:17.753175+05:30	Quantum Computing
3	3	What are your favorite first-person shooters?	2025-03-05 08:59:17.753175+05:30	Best FPS Games
4	1	Join our latest gaming competitions!	2025-03-05 08:59:17.753175+05:30	Gaming Tournaments
5	2	Here are 5 books that changed my life.	2025-03-05 08:59:17.753175+05:30	Must-Read Books
6	3	Which genre do you prefer?	2025-03-05 08:59:17.753175+05:30	Fantasy vs Sci-Fi
7	1	No gym? No problem! Try these routines.	2025-03-05 08:59:17.753175+05:30	Best Home Workouts
8	2	Which diet is better for muscle gain?	2025-03-05 08:59:17.753175+05:30	Keto vs Vegan
9	3	A beginner’s guide to deep learning.	2025-03-05 08:59:17.753175+05:30	Neural Networks Explained
10	1	The challenges of bias in machine learning.	2025-03-05 08:59:17.753175+05:30	AI Ethics
32	16	Testing post creation without community_id	2025-03-12 09:16:53.269166+05:30	Test Post
37	16	Testing post creation without community_id	2025-03-12 09:24:11.810475+05:30	Test Post
41	16	Testing post creation without community_id	2025-03-12 09:26:45.649699+05:30	Test Post
42	16	Testing post creation without community_id	2025-03-12 09:26:48.303579+05:30	Test Post
43	16	Testing post creation without community_id	2025-03-12 09:26:49.093318+05:30	Test Post
44	16	Testing post creation without community_id	2025-03-12 09:28:10.649226+05:30	Test Post
45	1	haha	2025-03-13 10:17:20.816993+05:30	lol
46	4	cjcicuc	2025-03-19 05:18:08.204896+05:30	cucici
47	5	New grok model is getting insane. What are your thoughts on that	2025-03-21 19:47:24.971766+05:30	Grok
52	1	Testing media!	2025-05-04 00:35:08.330567+05:30	Test Post 2025-05-04 00:35:08.314088
53	1	Testing media!	2025-05-04 00:45:32.374212+05:30	Test Post 2025-05-04 00:45:32.357097
54	1	Testing media!	2025-05-04 01:19:35.437882+05:30	Test Post 2025-05-04 01:19:35.418435
55	4	Testing media!	2025-05-04 01:20:00.246311+05:30	Test Post 2025-05-04 01:20:00.228456
56	4	Testing media!	2025-05-04 01:34:53.393773+05:30	Test Post 2025-05-04 01:34:53.375493
57	1	Testing media!	2025-05-04 01:41:00.956535+05:30	Test Post 2025-05-04 01:41:00.938752
90	1	Testing media!	2025-05-04 12:44:38.130397+05:30	Test Post 2025-05-04 12:44:38.113197
91	1	Two files!	2025-05-04 13:26:44.650481+05:30	Test Post Multi-Media 2025-05-04 13:26:44.634045
92	1	Two files!	2025-05-04 14:51:30.744853+05:30	Test Post Multi-Media 2025-05-04 14:51:30.728862
93	1	Two files!	2025-05-04 20:03:59.908235+05:30	Test Post Multi-Media 2025-05-04 20:03:59.889143
96	1	Two files!	2025-05-04 21:05:17.446385+05:30	Test Post Multi-Media 2025-05-04 21:05:17.429623
97	1	Two files!	2025-05-04 21:07:27.769258+05:30	Test Post Multi-Media 2025-05-04 21:07:27.752442
98	1	Two files!	2025-05-04 21:08:12.599386+05:30	Test Post Multi-Media 2025-05-04 21:08:12.582754
99	1	Two files!	2025-05-04 21:33:45.3464+05:30	Test Post Multi-Media 2025-05-04 21:33:45.328819
100	1	Two files!	2025-05-04 21:40:47.277436+05:30	Test Post Multi-Media 2025-05-04 21:40:47.251353
101	1	Two files!	2025-05-04 21:42:32.335466+05:30	Test Post Multi-Media 2025-05-04 21:42:32.319465
102	1	Two files!	2025-05-04 21:50:47.01382+05:30	Test Post Multi-Media 2025-05-04 21:50:46.997338
103	1	Two files!	2025-05-04 21:56:52.773619+05:30	Test Post Multi-Media 2025-05-04 21:56:52.757407
104	1	Two files!	2025-05-04 21:59:37.495276+05:30	Test Post Multi-Media 2025-05-04 21:59:37.479717
105	1	Two files!	2025-05-05 09:36:53.504064+05:30	Test Post Multi-Media 2025-05-05 09:36:53.488962
106	1	Two files!	2025-05-05 11:50:14.807717+05:30	Test Post Multi-Media 2025-05-05 11:50:14.791648
107	4	Two files!	2025-05-05 11:51:58.050094+05:30	Test Post Multi-Media 2025-05-05 11:51:58.030456
108	1	This post should trigger a WebSocket broadcast.	2025-05-05 11:59:53.399903+05:30	WS Test Post 1746426593
109	1	Two files!	2025-05-05 15:51:11.393963+05:30	Test Post Multi-Media 2025-05-05 15:51:11.374682
110	1	Two files!	2025-05-05 16:01:33.967182+05:30	Test Post Multi-Media 2025-05-05 16:01:33.947161
111	1	Two files!	2025-05-05 16:53:28.152359+05:30	Test Post Multi-Media 2025-05-05 16:53:28.133066
112	1	Testing post creation without any files.	2025-05-06 16:12:24.743917+05:30	Pytest Post NoMedia 161224
113	1	Testing multiple files!	2025-05-06 16:12:24.786576+05:30	Pytest Post MultiMedia 161224
114	1	Two files!	2025-05-06 16:32:08.335287+05:30	Test Post Multi-Media 2025-05-06 16:32:08.314181
115	1	Test.	2025-05-06 16:45:18.719773+05:30	Pytest Post NoMedia 164518
116	1	Files!	2025-05-06 16:45:18.761372+05:30	Pytest Post MultiMedia 164518
117	1	Two files!	2025-05-06 17:11:10.682421+05:30	Test Post Multi-Media 2025-05-06 17:11:10.662190
118	1	Test.	2025-05-06 17:12:00.745882+05:30	Pytest Post NoMedia 171200
120	1	Two files!	2025-05-06 17:42:42.738487+05:30	Test Post Multi-Media 2025-05-06 17:42:42.713217
121	1	Two files!	2025-05-06 17:43:59.987437+05:30	Test Post Multi-Media 2025-05-06 17:43:59.968147
122	1	Test.	2025-05-06 17:44:20.949636+05:30	Pytest Post NoMedia 174420
124	1	Test.	2025-05-06 17:57:06.83849+05:30	Pytest Post NoMedia 175706
126	1	Two files!	2025-05-07 09:20:20.720609+05:30	Test Post Multi-Media 2025-05-07 09:20:20.703996
127	1	Test.	2025-05-07 10:59:55.373737+05:30	Pytest Post NoMedia 105955
128	1	Files!	2025-05-07 10:59:55.415321+05:30	Pytest Post MultiMedia 105955
129	1	Test.	2025-05-07 11:22:45.943304+05:30	Pytest Post NoMedia 112245
131	1	Test.	2025-05-07 11:36:35.399807+05:30	Pytest Post NoMedia 113635
133	1	Test.	2025-05-07 11:46:32.097582+05:30	Pytest Post NoMedia 114632
137	1	Test.	2025-05-07 12:22:32.503252+05:30	Pytest Post NoMedia 122232
139	1	Test.	2025-05-07 12:27:11.980704+05:30	Pytest Post NoMedia 122711
141	1	Test.	2025-05-07 12:31:01.612428+05:30	Pytest Post NoMedia 123101
143	1	Test.	2025-05-07 12:33:24.592537+05:30	Pytest Post NoMedia 123324
145	1	Test.	2025-05-07 12:38:02.480895+05:30	Pytest Post NoMedia 123802
147	1	Test.	2025-05-07 12:43:48.101764+05:30	Pytest Post NoMedia 124348
149	1	Test.	2025-05-07 12:47:21.610913+05:30	Pytest Post NoMedia 124721
151	1	Test.	2025-05-07 12:51:54.000638+05:30	Pytest Post NoMedia 125153
153	1	Test.	2025-05-07 12:55:27.176102+05:30	Pytest Post NoMedia 125527
155	1	Test.	2025-05-07 12:58:50.814973+05:30	Pytest Post NoMedia 125850
157	1	Test.	2025-05-07 13:01:33.144714+05:30	Pytest Post NoMedia 130133
159	1	Test.	2025-05-07 13:04:57.43971+05:30	Pytest Post NoMedia 130457
161	1	Test.	2025-05-07 13:09:34.688205+05:30	Pytest Post NoMedia 130934
163	1	Test.	2025-05-07 13:12:36.016526+05:30	Pytest Post NoMedia 131235
165	1	Test.	2025-05-07 13:15:53.68722+05:30	Pytest Post NoMedia 131553
167	1	Test.	2025-05-07 13:18:46.5247+05:30	Pytest Post NoMedia 131846
169	1	Test.	2025-05-07 13:23:03.065875+05:30	Pytest Post NoMedia 132303
171	1	Test.	2025-05-07 13:34:47.055145+05:30	Pytest Post NoMedia 133447
175	1	Test.	2025-05-07 15:40:09.585683+05:30	Pytest Post NoMedia 154009
177	1	Test.	2025-05-07 15:42:54.727589+05:30	Pytest Post NoMedia 154254
179	1	Test.	2025-05-07 15:55:19.391672+05:30	Pytest Post NoMedia 155519
181	1	Test.	2025-05-07 16:05:06.84811+05:30	Pytest Post NoMedia 160506
183	1	Test.	2025-05-07 16:10:08.057146+05:30	Pytest Post NoMedia 161008
\.


--
-- Data for Name: replies; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.replies (id, post_id, user_id, content, parent_reply_id, created_at) FROM stdin;
1	1	2	AI is evolving so fast! What do you think about GPT-5?	\N	2025-03-05 09:01:24.202915+05:30
2	1	3	I wonder how AI will impact coding jobs.	\N	2025-03-05 09:01:24.202915+05:30
3	2	1	Quantum supremacy is still a long way off.	\N	2025-03-05 09:01:24.202915+05:30
4	2	2	Do you think we will have commercial quantum computers soon?	\N	2025-03-05 09:01:24.202915+05:30
5	3	3	CS:GO will always be my favorite!	\N	2025-03-05 09:01:24.202915+05:30
6	3	1	Call of Duty has better mechanics IMO.	\N	2025-03-05 09:01:24.202915+05:30
7	5	3	Have you read "Atomic Habits"?	\N	2025-03-05 09:01:24.202915+05:30
8	5	2	I loved "Sapiens"! One of the best history books.	\N	2025-03-05 09:01:24.202915+05:30
9	7	1	Bodyweight workouts are underrated!	\N	2025-03-05 09:01:24.202915+05:30
10	7	3	Which workout routine do you follow?	\N	2025-03-05 09:01:24.202915+05:30
11	10	2	Bias in AI is a real challenge.	\N	2025-03-05 09:01:24.202915+05:30
12	10	3	We need better regulations for AI development.	\N	2025-03-05 09:01:24.202915+05:30
14	43	16	This is a test reply!	\N	2025-03-12 09:44:29.191607+05:30
15	43	16	This is a test reply!	\N	2025-03-12 09:44:33.314172+05:30
17	43	16	This is a test reply!	\N	2025-03-12 09:46:36.304058+05:30
18	10	5	I totally agree! We need stricter rules.	12	2025-03-12 09:49:00.966636+05:30
19	43	16	This is a test reply!	\N	2025-03-12 09:50:01.720768+05:30
20	43	16	This is a test reply!	\N	2025-03-12 09:51:05.38545+05:30
21	43	16	This is a test reply!	12	2025-03-12 09:51:09.579549+05:30
22	43	16	This is a test reply!	21	2025-03-12 09:51:22.723128+05:30
23	44	4	lol	\N	2025-03-13 06:39:20.969698+05:30
25	6	4	hi	\N	2025-03-18 09:47:42.669801+05:30
26	5	4	hi	\N	2025-03-18 09:48:00.84351+05:30
27	5	4	bye	\N	2025-03-18 09:48:05.973502+05:30
28	42	4	...	\N	2025-03-18 09:56:17.556663+05:30
29	47	1	chutiya hai grok	\N	2025-03-23 17:56:35.218877+05:30
35	47	1	Test reply from script 2025-05-03 15:40:43.295360	\N	2025-05-03 15:40:43.313783+05:30
36	47	1	Test reply from script 2025-05-03 16:00:47.497592	\N	2025-05-03 16:00:47.517651+05:30
37	47	1	Test reply from script 2025-05-03 16:02:04.478928	\N	2025-05-03 16:02:04.498859+05:30
38	47	1	Test reply from script 2025-05-03 16:17:30.536980	\N	2025-05-03 16:17:30.559524+05:30
39	47	1	Test reply from script 2025-05-03 16:28:13.684111	\N	2025-05-03 16:28:13.703338+05:30
40	47	1	Test reply from script 2025-05-03 16:30:11.983610	\N	2025-05-03 16:30:12.002011+05:30
41	47	1	Test reply from script 2025-05-03 16:31:03.253606	\N	2025-05-03 16:31:03.277811+05:30
42	47	1	Test reply from script 2025-05-03 16:45:55.734924	\N	2025-05-03 16:45:55.752579+05:30
43	47	1	Test reply from script 2025-05-03 16:51:00.198581	\N	2025-05-03 16:51:00.216304+05:30
44	47	1	Test reply from script 2025-05-03 17:02:33.290280	\N	2025-05-03 17:02:33.308366+05:30
45	47	1	Test reply from script 2025-05-03 17:14:45.159549	\N	2025-05-03 17:14:45.177866+05:30
46	47	1	Test reply from script 2025-05-03 17:35:33.386792	\N	2025-05-03 17:35:33.405693+05:30
47	47	1	Test reply from script 2025-05-03 17:37:14.998120	\N	2025-05-03 17:37:15.017541+05:30
48	47	1	Test reply from script 2025-05-03 17:42:21.850162	\N	2025-05-03 17:42:21.868731+05:30
53	47	1	Test reply 2025-05-04 00:35:09.725126	\N	2025-05-04 00:35:09.742654+05:30
54	47	1	Test reply 2025-05-04 00:45:33.590298	\N	2025-05-04 00:45:33.607314+05:30
55	47	1	Test reply 2025-05-04 01:19:36.612103	\N	2025-05-04 01:19:36.628426+05:30
56	47	4	Test reply 2025-05-04 01:20:01.695820	\N	2025-05-04 01:20:01.712949+05:30
57	47	4	Test reply 2025-05-04 01:34:54.783715	\N	2025-05-04 01:34:54.800097+05:30
58	47	1	Test reply 2025-05-04 01:41:02.431429	\N	2025-05-04 01:41:02.448232+05:30
91	47	1	Test reply 2025-05-04 12:44:39.620081	\N	2025-05-04 12:44:39.636275+05:30
94	2	1	Test reply w/ media 2025-05-04 21:05:19.150880	\N	2025-05-04 21:05:19.16671+05:30
95	2	1	Test reply w/ media 2025-05-04 21:07:29.523498	\N	2025-05-04 21:07:29.540563+05:30
96	2	1	Test reply w/ media 2025-05-04 21:08:14.432883	\N	2025-05-04 21:08:14.449345+05:30
97	2	1	Test reply w/ media 2025-05-04 21:33:47.047277	\N	2025-05-04 21:33:47.063303+05:30
98	2	1	Test reply w/ media 2025-05-04 21:40:49.461045	\N	2025-05-04 21:40:49.476557+05:30
99	2	1	Test reply w/ media 2025-05-04 21:42:34.251940	\N	2025-05-04 21:42:34.268362+05:30
100	2	1	Test reply w/ media 2025-05-04 21:50:49.238401	\N	2025-05-04 21:50:49.255698+05:30
101	2	1	Test reply w/ media 2025-05-04 21:56:54.504546	\N	2025-05-04 21:56:54.522497+05:30
102	2	1	Test reply w/ media 2025-05-04 21:59:39.199647	\N	2025-05-04 21:59:39.215676+05:30
103	2	1	Test reply w/ media 2025-05-05 09:36:56.227117	\N	2025-05-05 09:36:56.243481+05:30
104	2	1	Test reply w/ media 2025-05-05 11:50:17.310758	\N	2025-05-05 11:50:17.326467+05:30
105	2	4	Test reply w/ media 2025-05-05 11:52:00.934084	\N	2025-05-05 11:52:00.952131+05:30
106	1	1	This is a reply broadcast test!	\N	2025-05-05 12:00:35.621518+05:30
107	2	1	Test reply w/ media 2025-05-05 15:51:14.440744	\N	2025-05-05 15:51:14.459206+05:30
108	2	1	Test reply w/ media 2025-05-05 16:01:36.689330	\N	2025-05-05 16:01:36.70815+05:30
109	2	1	Test reply w/ media 2025-05-05 16:53:31.086417	\N	2025-05-05 16:53:31.102823+05:30
110	2	1	Pytest reply no media 161354	\N	2025-05-06 16:17:26.253687+05:30
111	2	1	Test reply w/ media 2025-05-06 16:32:23.835070	\N	2025-05-06 16:32:23.857254+05:30
112	2	1	Pytest reply no media 164648	\N	2025-05-06 16:50:20.248782+05:30
113	2	1	Test reply w/ media 2025-05-06 17:11:13.549847	\N	2025-05-06 17:11:13.568918+05:30
114	2	1	Pytest reply no media 171202	\N	2025-05-06 17:12:02.43831+05:30
115	2	1	Test reply w/ media 2025-05-06 17:42:45.803883	\N	2025-05-06 17:42:45.824149+05:30
116	2	1	Test reply w/ media 2025-05-06 17:44:02.538021	\N	2025-05-06 17:44:02.558028+05:30
117	2	1	Pytest reply no media 174422	\N	2025-05-06 17:44:22.516226+05:30
118	2	1	Test reply w/ media 2025-05-07 09:20:23.891309	\N	2025-05-07 09:20:23.906467+05:30
119	2	1	Pytest reply no media 110125	\N	2025-05-07 11:04:57.760306+05:30
120	2	1	Pytest reply no media 112247	\N	2025-05-07 11:22:47.723335+05:30
121	2	1	Pytest reply no media 113639	\N	2025-05-07 11:36:39.623878+05:30
123	2	1	Pytest reply no media 114635	\N	2025-05-07 11:46:35.840691+05:30
127	2	1	Pytest reply no media 122237	\N	2025-05-07 12:22:37.125373+05:30
129	2	1	Pytest reply no media 122716	\N	2025-05-07 12:27:16.381184+05:30
131	2	1	Pytest reply no media 123105	\N	2025-05-07 12:31:05.997034+05:30
133	2	1	Pytest reply no media 123328	\N	2025-05-07 12:33:28.946471+05:30
135	2	1	Pytest reply no media 123806	\N	2025-05-07 12:38:06.558121+05:30
137	2	1	Pytest reply no media 124352	\N	2025-05-07 12:43:52.189156+05:30
139	2	1	Pytest reply no media 124725	\N	2025-05-07 12:47:25.763334+05:30
141	2	1	Pytest reply no media 125157	\N	2025-05-07 12:51:57.835324+05:30
143	2	1	Pytest reply no media 125531	\N	2025-05-07 12:55:31.404298+05:30
145	2	1	Pytest reply no media 125855	\N	2025-05-07 12:58:55.264128+05:30
147	2	1	Pytest reply no media 130137	\N	2025-05-07 13:01:37.066683+05:30
149	2	1	Pytest reply no media 130501	\N	2025-05-07 13:05:01.352805+05:30
151	2	1	Pytest reply no media 130938	\N	2025-05-07 13:09:38.939115+05:30
153	2	1	Pytest reply no media 131240	\N	2025-05-07 13:12:40.843337+05:30
155	2	1	Pytest reply no media 131557	\N	2025-05-07 13:15:57.937926+05:30
157	2	1	Pytest reply no media 131850	\N	2025-05-07 13:18:50.834141+05:30
159	2	1	Pytest reply no media 132306	\N	2025-05-07 13:23:06.757864+05:30
161	2	1	Pytest reply no media 133451	\N	2025-05-07 13:34:51.441243+05:30
163	2	1	Test reply for notification generation!	\N	2025-05-07 15:02:05.644298+05:30
164	2	1	Pytest reply no media 150209	\N	2025-05-07 15:02:09.493806+05:30
166	2	1	Test reply for notification generation!	\N	2025-05-07 15:21:08.010725+05:30
167	2	1	Pytest reply no media 152108	\N	2025-05-07 15:21:08.827013+05:30
169	2	1	Test reply for notification generation!	\N	2025-05-07 15:40:08.9821+05:30
170	2	1	Pytest reply no media 154013	\N	2025-05-07 15:40:14.002044+05:30
172	2	1	Test reply for notification generation!	\N	2025-05-07 15:42:54.106735+05:30
173	2	1	Pytest reply no media 154259	\N	2025-05-07 15:42:59.484014+05:30
177	2	1	Test reply for notification generation!	\N	2025-05-07 15:55:18.755801+05:30
178	2	1	Pytest reply no media 155524	\N	2025-05-07 15:55:24.387169+05:30
180	2	1	Test reply for notification generation!	\N	2025-05-07 16:05:06.210126+05:30
181	2	1	Pytest reply no media 160511	\N	2025-05-07 16:05:11.065887+05:30
183	2	1	Test reply for notification generation!	\N	2025-05-07 16:10:07.412849+05:30
184	2	1	Pytest reply no media 161012	\N	2025-05-07 16:10:12.624525+05:30
\.


--
-- Data for Name: reply_favorites; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reply_favorites (id, user_id, reply_id, favorited_at) FROM stdin;
1	3	1	2025-03-12 10:58:37.339852+05:30
2	1	2	2025-03-12 10:58:37.339852+05:30
3	2	3	2025-03-12 10:58:37.339852+05:30
4	1	4	2025-03-12 10:58:37.339852+05:30
5	3	5	2025-03-12 10:58:37.339852+05:30
6	2	6	2025-03-12 10:58:37.339852+05:30
7	1	7	2025-03-12 10:58:37.339852+05:30
\.


--
-- Data for Name: reply_media; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reply_media (reply_id, media_id, display_order) FROM stdin;
94	72	0
95	77	0
96	82	0
97	87	0
98	92	0
99	98	0
100	104	0
101	110	0
102	116	0
103	122	0
104	128	0
105	133	0
107	140	0
108	146	0
109	152	0
111	159	0
113	166	0
115	173	0
116	179	0
118	186	0
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: user_blocks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_blocks (blocker_id, blocked_id, created_at) FROM stdin;
\.


--
-- Data for Name: user_device_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_device_tokens (id, user_id, device_token, platform, last_used_at, created_at) FROM stdin;
\.


--
-- Data for Name: user_followers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_followers (follower_id, following_id, created_at) FROM stdin;
1	2	2025-04-28 16:08:30.326
1	3	2025-04-28 16:08:30.326
2	1	2025-04-28 16:08:30.326
3	1	2025-04-28 16:08:30.326
4	1	2025-04-28 16:08:30.326
5	1	2025-04-28 16:08:30.326
2	3	2025-04-28 16:08:30.326
3	4	2025-04-28 16:08:30.326
4	5	2025-04-28 16:08:30.326
1	4	2025-04-28 16:46:17.426931
1	5	2025-04-29 10:04:44.944635
\.


--
-- Data for Name: user_profile_picture; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_profile_picture (user_id, media_id, set_at) FROM stdin;
4	130	2025-05-05 11:51:51.695493+05:30
1	182	2025-05-07 09:20:08.540481+05:30
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, name, username, gender, email, password_hash, created_at, interest, college_email, college, interests, last_seen, current_location_address, notify_new_post_in_community, notify_new_reply_to_post, notify_new_event_in_community, notify_event_reminder, notify_direct_message, notify_event_update, location, location_last_updated, location_address) FROM stdin;
7	x12e	x2412	Male	x124124	$2b$10$v7ZeQnWlQHqRXKH2E5AUiOWPiV1hUa0vh515qU1mX7vwUVZAOfOP2	2025-03-05 09:22:43.861367+05:30	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N	t	t	t	t	f	t	\N	\N	\N
8	1	1	Male	1	$2b$10$TQeQmCfQ3YaIl48gJ3RCsO8vCNknEBELh0CcZWX0nqLY6HO3muSSC	2025-03-05 10:04:11.212485+05:30	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N	t	t	t	t	f	t	\N	\N	\N
10	lol	lol	Male	lol	$2b$12$NyPiU.qzTF67ye7b/2oq5utk055MlLnHp1vX9GrDUFpIv.nEeGLFe	2025-03-10 09:36:41.231915+05:30	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N	t	t	t	t	f	t	\N	\N	\N
13	lol	lol5	Male	lol5	$2b$12$mqT1RCQ8IvonmntYL8jQYej.REoXqjeRnkHFMyuz7aLJxiZvYkRlK	2025-03-10 09:39:51.840627+05:30	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N	t	t	t	t	f	t	\N	\N	\N
14	pqkd	jsk	Male	oak	$2b$12$/4KFxcXD7Ue1CMebGn1h0eOepufPEsjwJ8KMEjAtxeaauZTzNn5gW	2025-03-10 15:31:09.036156+05:30	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N	t	t	t	t	f	t	\N	\N	\N
16	John Doe	johndoe	Male	johndoe@example.com	$2b$12$N4tDK8n32Vy4PsHwy9nBAOvXNXusFS3JdQTmRfRTNfvJDBXRgWl3K	2025-03-12 08:26:00.954317+05:30	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N	t	t	t	t	f	t	\N	\N	\N
1056	pranjay Kashyap	pranjay14	Male	pranjay1423@gmail.com	$2b$12$Wuk300q/2ERS/7HV1tPk2eDMgBqelyIvy7GDFdNLTaggxvOKOk5fy	2025-04-26 20:30:56.712238+05:30	Cooking	\N	MIT Manipal	\N	2025-04-27 20:15:17.72424+05:30	\N	t	t	t	t	f	t	\N	\N	\N
1054	Vineet Prasad	vineet	Male	divanshvineet@gmail.com	$2b$12$q/iAfgyjY68zWvZlMkaV7OKN6GASpHesMc4.u9D8Wqn8OjkMLC53G	2025-04-25 20:01:42.648265+05:30	Gymming,Gaming	\N	Other	\N	2025-04-25 20:06:29.525967+05:30	\N	t	t	t	t	f	t	\N	\N	\N
1055	Shailesh Kumar Gupta	eskge	Male	bittuskg@gmail.com	$2b$10$ZT5VBdhk7PEByY59TrDSf.NDs14QUvxeKB0i445b4xkO32W5gj5Lu	2025-04-26 20:01:25.304254+05:30	Cooking	\N	MIT Manipal	\N	2025-04-30 13:45:17.07525+05:30	\N	t	t	t	t	f	t	\N	\N	\N
2	Bob Smith	bobsmith	Male	bob@example.com	$2a$06$18cmMhqNGZYsr315AuEjDOkAD0ALxI1ZZc0HqJFLl3l01Qi7FWbMS	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	2025-05-05 12:06:38.950087+05:30	\N	t	t	t	t	f	t	\N	\N	\N
5	Kanishk Prasad	kanishk	Male	kanishk.0030@gmail.com	$2b$12$b4GhlqETvglhS1Mx6jpPSOvjv10lTJaYZloS3PFZJNkLt8zJwWm8e	2025-03-05 08:58:09.721498+05:30	Movies,Coding,Gaming,Science,Travel,Music	\N	VIT Vellore	\N	2025-05-05 12:07:02.294343+05:30	\N	t	t	t	t	f	t	\N	\N	\N
1	Alice Johnson	alicej	Female	alice@example.com	$2b$12$RhHwvgup6zHJAb/U5AXYruXZ03UkT2Tyb7.MNAkB.kvEQS2XX4CO2	2025-03-05 08:58:09.721498+05:30	API,Testing	\N	Pytest College 55	\N	2025-05-07 18:08:31.750685+05:30	\N	t	t	t	t	f	t	\N	\N	\N
4	Divansh Prasad	divansh	Male	divanshthebest@gmail.com	$2a$06$Hv2JBsgYF5.8/S7YLgIzBugK1jDBY3PgUXf95ys82rO6lJSzAIdZK	2025-03-05 08:58:09.721498+05:30	API,Testing	\N	API Test College 51	\N	2025-05-05 11:52:05.388809+05:30	\N	f	t	t	f	t	t	\N	\N	\N
3	Charlie Brown	charlieb	Male	charlie@example.com	$2a$06$cwLWRg/f0OnrsZ1zulJCZeEK1dm.gaonY/we92J5BtvXsS9TRAJA.	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N	t	t	t	t	f	t	\N	\N	\N
\.


--
-- Data for Name: votes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.votes (id, user_id, post_id, reply_id, vote_type, created_at) FROM stdin;
1	2	1	\N	t	2025-03-05 09:02:35.111778+05:30
2	3	2	\N	t	2025-03-05 09:02:35.111778+05:30
3	1	3	\N	t	2025-03-05 09:02:35.111778+05:30
4	3	7	\N	t	2025-03-05 09:02:35.111778+05:30
5	2	10	\N	t	2025-03-05 09:02:35.111778+05:30
6	3	\N	1	t	2025-03-05 09:02:35.111778+05:30
7	1	\N	2	t	2025-03-05 09:02:35.111778+05:30
8	2	\N	3	t	2025-03-05 09:02:35.111778+05:30
9	1	\N	4	t	2025-03-05 09:02:35.111778+05:30
10	3	\N	5	t	2025-03-05 09:02:35.111778+05:30
11	2	\N	6	t	2025-03-05 09:02:35.111778+05:30
12	1	\N	7	t	2025-03-05 09:02:35.111778+05:30
25	16	43	\N	t	2025-03-12 09:42:06.915056+05:30
26	4	44	\N	t	2025-03-13 06:39:04.120915+05:30
27	4	43	\N	f	2025-03-13 06:39:07.894831+05:30
28	4	9	\N	t	2025-03-13 07:03:41.397585+05:30
29	4	5	\N	f	2025-03-13 07:03:44.302652+05:30
30	4	6	\N	t	2025-03-13 07:13:49.416637+05:30
31	4	42	\N	f	2025-03-13 07:13:53.197678+05:30
32	4	41	\N	f	2025-03-13 07:13:59.215768+05:30
33	4	1	\N	f	2025-03-13 07:14:02.445867+05:30
34	4	10	\N	t	2025-03-13 07:14:05.226155+05:30
36	4	37	\N	f	2025-03-13 09:05:06.14473+05:30
37	1	43	\N	t	2025-03-13 10:16:54.045042+05:30
38	1	42	\N	f	2025-03-13 10:16:55.509214+05:30
39	4	45	\N	t	2025-03-17 06:46:01.84509+05:30
40	5	9	\N	t	2025-03-21 19:47:42.09172+05:30
41	1	47	\N	t	2025-03-23 17:54:44.513055+05:30
42	1	44	\N	t	2025-03-23 17:54:49.761991+05:30
43	1	46	\N	t	2025-03-23 17:55:03.771678+05:30
44	1	7	\N	t	2025-03-23 17:55:09.922746+05:30
45	4	47	\N	t	2025-03-30 20:54:54.622673+05:30
\.


--
-- Name: CREATED_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."CREATED_id_seq"', 93, true);


--
-- Name: Community_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."Community_id_seq"', 44, true);


--
-- Name: Event_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."Event_id_seq"', 49, true);


--
-- Name: FAVORITED_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."FAVORITED_id_seq"', 188, true);


--
-- Name: FOLLOWS_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."FOLLOWS_id_seq"', 110, true);


--
-- Name: HAS_POST_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."HAS_POST_id_seq"', 246, true);


--
-- Name: MEMBER_OF_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."MEMBER_OF_id_seq"', 184, true);


--
-- Name: PARTICIPATED_IN_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."PARTICIPATED_IN_id_seq"', 122, true);


--
-- Name: Post_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."Post_id_seq"', 153, true);


--
-- Name: REPLIED_TO_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."REPLIED_TO_id_seq"', 175, true);


--
-- Name: Reply_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."Reply_id_seq"', 175, true);


--
-- Name: User_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."User_id_seq"', 14, true);


--
-- Name: VOTED_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."VOTED_id_seq"', 132, true);


--
-- Name: WROTE_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore."WROTE_id_seq"', 295, true);


--
-- Name: _ag_label_edge_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore._ag_label_edge_id_seq', 1, false);


--
-- Name: _ag_label_vertex_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore._ag_label_vertex_id_seq', 1, false);


--
-- Name: _label_id_seq; Type: SEQUENCE SET; Schema: fiore; Owner: -
--

SELECT pg_catalog.setval('fiore._label_id_seq', 16, true);


--
-- Name: chat_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chat_messages_id_seq', 1475, true);


--
-- Name: communities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.communities_id_seq', 152, true);


--
-- Name: community_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.community_members_id_seq', 2862, true);


--
-- Name: community_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.community_posts_id_seq', 12, true);


--
-- Name: event_participants_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.event_participants_id_seq', 2091, true);


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.events_id_seq', 386, true);


--
-- Name: media_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.media_items_id_seq', 333, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notifications_id_seq', 56, true);


--
-- Name: post_favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.post_favorites_id_seq', 8, true);


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.posts_id_seq', 184, true);


--
-- Name: replies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.replies_id_seq', 185, true);


--
-- Name: reply_favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.reply_favorites_id_seq', 8, true);


--
-- Name: user_device_tokens_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.user_device_tokens_id_seq', 7, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 1056, true);


--
-- Name: votes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.votes_id_seq', 45, true);


--
-- Name: _ag_label_edge _ag_label_edge_pkey; Type: CONSTRAINT; Schema: fiore; Owner: -
--
--

--ALTER TABLE ONLY fiore._ag_label_edge
--    ADD CONSTRAINT _ag_label_edge_pkey PRIMARY KEY (id);


--
-- Name: _ag_label_vertex _ag_label_vertex_pkey; Type: CONSTRAINT; Schema: fiore; Owner: -
--

--ALTER TABLE ONLY fiore._ag_label_vertex
--    ADD CONSTRAINT _ag_label_vertex_pkey PRIMARY KEY (id);


--
-- Name: chat_message_media chat_message_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_media
    ADD CONSTRAINT chat_message_media_pkey PRIMARY KEY (message_id, media_id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: communities communities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (id);


--
-- Name: community_logo community_logo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_logo
    ADD CONSTRAINT community_logo_pkey PRIMARY KEY (community_id);


--
-- Name: community_members community_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_pkey PRIMARY KEY (id);


--
-- Name: community_members community_members_user_id_community_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_community_id_key UNIQUE (user_id, community_id);


--
-- Name: community_posts community_posts_community_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_post_id_key UNIQUE (community_id, post_id);


--
-- Name: community_posts community_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_pkey PRIMARY KEY (id);


--
-- Name: event_participants event_participants_event_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_user_id_key UNIQUE (event_id, user_id);


--
-- Name: event_participants event_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: media_items media_items_minio_object_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_items
    ADD CONSTRAINT media_items_minio_object_name_key UNIQUE (minio_object_name);


--
-- Name: media_items media_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_items
    ADD CONSTRAINT media_items_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: post_favorites post_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_pkey PRIMARY KEY (id);


--
-- Name: post_favorites post_favorites_user_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_post_id_key UNIQUE (user_id, post_id);


--
-- Name: post_media post_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_pkey PRIMARY KEY (post_id, media_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: replies replies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_pkey PRIMARY KEY (id);


--
-- Name: reply_favorites reply_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_pkey PRIMARY KEY (id);


--
-- Name: reply_favorites reply_favorites_user_id_reply_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_reply_id_key UNIQUE (user_id, reply_id);


--
-- Name: reply_media reply_media_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_media
    ADD CONSTRAINT reply_media_pkey PRIMARY KEY (reply_id, media_id);


--
-- Name: votes unique_user_post_vote; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_post_vote UNIQUE (user_id, post_id);


--
-- Name: votes unique_user_reply_vote; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_reply_vote UNIQUE (user_id, reply_id);


--
-- Name: user_blocks user_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (blocker_id, blocked_id);


--
-- Name: user_device_tokens user_device_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_device_tokens
    ADD CONSTRAINT user_device_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_followers user_followers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_pkey PRIMARY KEY (follower_id, following_id);


--
-- Name: user_profile_picture user_profile_picture_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_picture
    ADD CONSTRAINT user_profile_picture_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: votes votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- Name: community_id_graph_idx; Type: INDEX; Schema: fiore; Owner: -
--

CREATE INDEX community_id_graph_idx ON fiore."Community" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));


--
-- Name: event_id_graph_idx; Type: INDEX; Schema: fiore; Owner: -
--

CREATE INDEX event_id_graph_idx ON fiore."Event" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));


--
-- Name: post_id_graph_idx; Type: INDEX; Schema: fiore; Owner: -
--

CREATE INDEX post_id_graph_idx ON fiore."Post" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));


--
-- Name: reply_id_graph_idx; Type: INDEX; Schema: fiore; Owner: -
--

CREATE INDEX reply_id_graph_idx ON fiore."Reply" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));


--
-- Name: user_id_graph_idx; Type: INDEX; Schema: fiore; Owner: -
--

CREATE INDEX user_id_graph_idx ON fiore."User" USING btree ((((properties OPERATOR(ag_catalog.->>) 'id'::text))::bigint));


--
-- Name: idx_chat_message_media_media; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_message_media_media ON public.chat_message_media USING btree (media_id);


--
-- Name: idx_chat_messages_community_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_community_id ON public.chat_messages USING btree (community_id) WHERE (community_id IS NOT NULL);


--
-- Name: idx_chat_messages_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_event_id ON public.chat_messages USING btree (event_id) WHERE (event_id IS NOT NULL);


--
-- Name: idx_chat_messages_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_chat_messages_timestamp ON public.chat_messages USING btree ("timestamp" DESC);


--
-- Name: idx_communities_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_communities_created_by ON public.communities USING btree (created_by);


--
-- Name: idx_communities_fts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_communities_fts ON public.communities USING gin (to_tsvector('english'::regconfig, ((COALESCE(name, ''::text) || ' '::text) || COALESCE(description, ''::text))));


--
-- Name: idx_communities_interest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_communities_interest ON public.communities USING btree (interest);


--
-- Name: idx_communities_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_communities_location ON public.communities USING gist (location);


--
-- Name: idx_community_logo_media; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_community_logo_media ON public.community_logo USING btree (media_id);


--
-- Name: idx_event_participants_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_event_participants_event_id ON public.event_participants USING btree (event_id);


--
-- Name: idx_event_participants_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_event_participants_user_id ON public.event_participants USING btree (user_id);


--
-- Name: idx_events_community_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_community_id ON public.events USING btree (community_id);


--
-- Name: idx_events_event_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_event_timestamp ON public.events USING btree (event_timestamp);


--
-- Name: idx_events_event_timestamp_desc; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_event_timestamp_desc ON public.events USING btree (event_timestamp DESC);


--
-- Name: idx_events_location_coords; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_location_coords ON public.events USING gist (location_coords);


--
-- Name: idx_followers_follower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_followers_follower ON public.user_followers USING btree (follower_id);


--
-- Name: idx_followers_following; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_followers_following ON public.user_followers USING btree (following_id);


--
-- Name: idx_media_items_minio_object; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_media_items_minio_object ON public.media_items USING btree (minio_object_name);


--
-- Name: idx_media_items_uploader; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_media_items_uploader ON public.media_items USING btree (uploader_user_id);


--
-- Name: idx_notifications_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_actor ON public.notifications USING btree (actor_user_id);


--
-- Name: idx_notifications_recipient_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_recipient_created ON public.notifications USING btree (recipient_user_id, created_at DESC);


--
-- Name: idx_notifications_recipient_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_recipient_unread ON public.notifications USING btree (recipient_user_id, is_read, created_at DESC);


--
-- Name: idx_notifications_related_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_related_entity ON public.notifications USING btree (related_entity_type, related_entity_id);


--
-- Name: idx_post_media_media; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_post_media_media ON public.post_media USING btree (media_id);


--
-- Name: idx_posts_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_created_at ON public.posts USING btree (created_at DESC);


--
-- Name: idx_posts_fts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_fts ON public.posts USING gin (to_tsvector('english'::regconfig, (((COALESCE(title, ''::character varying))::text || ' '::text) || COALESCE(content, ''::text))));


--
-- Name: idx_posts_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_posts_user_id ON public.posts USING btree (user_id);


--
-- Name: idx_replies_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_replies_created_at ON public.replies USING btree (created_at);


--
-- Name: idx_replies_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_replies_post_id ON public.replies USING btree (post_id);


--
-- Name: idx_reply_media_media; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reply_media_media ON public.reply_media USING btree (media_id);


--
-- Name: idx_user_blocks_blocked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_blocks_blocked ON public.user_blocks USING btree (blocked_id);


--
-- Name: idx_user_blocks_blocker; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_blocks_blocker ON public.user_blocks USING btree (blocker_id);


--
-- Name: idx_user_device_tokens_token_platform; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_user_device_tokens_token_platform ON public.user_device_tokens USING btree (device_token, platform);


--
-- Name: idx_user_device_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_device_tokens_user_id ON public.user_device_tokens USING btree (user_id);


--
-- Name: idx_user_profile_picture_media; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_profile_picture_media ON public.user_profile_picture USING btree (media_id);


--
-- Name: idx_users_college; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_college ON public.users USING btree (college);


--
-- Name: idx_users_fts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_fts ON public.users USING gin (to_tsvector('english'::regconfig, ((COALESCE(name, ''::text) || ' '::text) || COALESCE(username, ''::text))));


--
-- Name: idx_users_interest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_interest ON public.users USING btree (interest);


--
-- Name: idx_users_last_seen; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_last_seen ON public.users USING btree (last_seen DESC NULLS LAST);


--
-- Name: idx_users_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_location ON public.users USING gist (location);


--
-- Name: idx_votes_on_post; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_votes_on_post ON public.votes USING btree (post_id) WHERE (post_id IS NOT NULL);


--
-- Name: idx_votes_on_reply; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_votes_on_reply ON public.votes USING btree (reply_id) WHERE (reply_id IS NOT NULL);


--
-- Name: chat_message_media chat_message_media_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_media
    ADD CONSTRAINT chat_message_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE CASCADE;


--
-- Name: chat_message_media chat_message_media_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_message_media
    ADD CONSTRAINT chat_message_media_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.chat_messages(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: communities communities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: community_logo community_logo_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_logo
    ADD CONSTRAINT community_logo_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_logo community_logo_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_logo
    ADD CONSTRAINT community_logo_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE RESTRICT;


--
-- Name: community_members community_members_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_members community_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: community_posts community_posts_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_posts community_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: event_participants event_participants_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- Name: event_participants event_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: events events_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: events events_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: media_items media_items_uploader_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_items
    ADD CONSTRAINT media_items_uploader_user_id_fkey FOREIGN KEY (uploader_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: notifications notifications_recipient_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_recipient_user_id_fkey FOREIGN KEY (recipient_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: post_favorites post_favorites_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_favorites post_favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: post_media post_media_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE CASCADE;


--
-- Name: post_media post_media_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_media
    ADD CONSTRAINT post_media_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: replies replies_parent_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_parent_reply_id_fkey FOREIGN KEY (parent_reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- Name: replies replies_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: replies replies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reply_favorites reply_favorites_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- Name: reply_favorites reply_favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reply_media reply_media_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_media
    ADD CONSTRAINT reply_media_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE CASCADE;


--
-- Name: reply_media reply_media_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reply_media
    ADD CONSTRAINT reply_media_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocked_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocked_id_fkey FOREIGN KEY (blocked_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_blocks user_blocks_blocker_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_blocker_id_fkey FOREIGN KEY (blocker_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_device_tokens user_device_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_device_tokens
    ADD CONSTRAINT user_device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_followers user_followers_follower_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_followers user_followers_following_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_profile_picture user_profile_picture_media_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_picture
    ADD CONSTRAINT user_profile_picture_media_id_fkey FOREIGN KEY (media_id) REFERENCES public.media_items(id) ON DELETE RESTRICT;


--
-- Name: user_profile_picture user_profile_picture_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_profile_picture
    ADD CONSTRAINT user_profile_picture_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: votes votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: votes votes_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- Name: votes votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

