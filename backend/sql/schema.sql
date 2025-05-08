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

CREATE SCHEMA ag_catalog;


--
-- Name: fiore; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA fiore;


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

CREATE TABLE fiore._ag_label_edge (
    id ag_catalog.graphid NOT NULL,
    start_id ag_catalog.graphid NOT NULL,
    end_id ag_catalog.graphid NOT NULL,
    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
);


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

CREATE TABLE fiore._ag_label_vertex (
    id ag_catalog.graphid NOT NULL,
    properties ag_catalog.agtype DEFAULT ag_catalog.agtype_build_map() NOT NULL
);


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

CREATE SEQUENCE fiore._ag_label_edge_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: _ag_label_edge_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore._ag_label_edge_id_seq OWNED BY fiore._ag_label_edge.id;


--
-- Name: _ag_label_vertex_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore._ag_label_vertex_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 281474976710655
    CACHE 1;


--
-- Name: _ag_label_vertex_id_seq; Type: SEQUENCE OWNED BY; Schema: fiore; Owner: -
--

ALTER SEQUENCE fiore._ag_label_vertex_id_seq OWNED BY fiore._ag_label_vertex.id;


--
-- Name: _label_id_seq; Type: SEQUENCE; Schema: fiore; Owner: -
--

CREATE SEQUENCE fiore._label_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 65535
    CACHE 1
    CYCLE;


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
-- Name: _ag_label_edge _ag_label_edge_pkey; Type: CONSTRAINT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore._ag_label_edge
    ADD CONSTRAINT _ag_label_edge_pkey PRIMARY KEY (id);


--
-- Name: _ag_label_vertex _ag_label_vertex_pkey; Type: CONSTRAINT; Schema: fiore; Owner: -
--

ALTER TABLE ONLY fiore._ag_label_vertex
    ADD CONSTRAINT _ag_label_vertex_pkey PRIMARY KEY (id);


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

