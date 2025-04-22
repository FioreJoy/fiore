--
-- PostgreSQL database dump
--

-- Dumped from database version 15.12 (Debian 15.12-0+deb12u2)
-- Dumped by pg_dump version 15.12 (Debian 15.12-0+deb12u2)

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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: divansh
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


ALTER TABLE public.chat_messages OWNER TO divansh;

--
-- Name: chat_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.chat_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chat_messages_id_seq OWNER TO divansh;

--
-- Name: chat_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;


--
-- Name: communities; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.communities (
    id integer NOT NULL,
    name text NOT NULL,
    description text,
    created_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    primary_location point,
    interest text,
    CONSTRAINT check_interest CHECK ((interest = ANY (ARRAY['Gaming'::text, 'Tech'::text, 'Science'::text, 'Music'::text, 'Sports'::text, 'College Event'::text, 'Activities'::text, 'Social'::text, 'Other'::text])))
);


ALTER TABLE public.communities OWNER TO divansh;

--
-- Name: communities_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.communities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.communities_id_seq OWNER TO divansh;

--
-- Name: communities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.communities_id_seq OWNED BY public.communities.id;


--
-- Name: community_members; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.community_members (
    id integer NOT NULL,
    user_id integer NOT NULL,
    community_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.community_members OWNER TO divansh;

--
-- Name: community_members_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.community_members_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_members_id_seq OWNER TO divansh;

--
-- Name: community_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.community_members_id_seq OWNED BY public.community_members.id;


--
-- Name: community_posts; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.community_posts (
    id integer NOT NULL,
    community_id integer NOT NULL,
    post_id integer NOT NULL,
    added_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.community_posts OWNER TO divansh;

--
-- Name: community_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.community_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_posts_id_seq OWNER TO divansh;

--
-- Name: community_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.community_posts_id_seq OWNED BY public.community_posts.id;


--
-- Name: event_participants; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.event_participants (
    id integer NOT NULL,
    event_id integer NOT NULL,
    user_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.event_participants OWNER TO divansh;

--
-- Name: event_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.event_participants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_participants_id_seq OWNER TO divansh;

--
-- Name: event_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.event_participants_id_seq OWNED BY public.event_participants.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: divansh
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
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.events OWNER TO divansh;

--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.events_id_seq OWNER TO divansh;

--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: post_favorites; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.post_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.post_favorites OWNER TO divansh;

--
-- Name: post_favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.post_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.post_favorites_id_seq OWNER TO divansh;

--
-- Name: post_favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.post_favorites_id_seq OWNED BY public.post_favorites.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    title character varying(255) NOT NULL
);


ALTER TABLE public.posts OWNER TO divansh;

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.posts_id_seq OWNER TO divansh;

--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: replies; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.replies (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    parent_reply_id integer,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.replies OWNER TO divansh;

--
-- Name: replies_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.replies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.replies_id_seq OWNER TO divansh;

--
-- Name: replies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.replies_id_seq OWNED BY public.replies.id;


--
-- Name: reply_favorites; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.reply_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reply_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.reply_favorites OWNER TO divansh;

--
-- Name: reply_favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.reply_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reply_favorites_id_seq OWNER TO divansh;

--
-- Name: reply_favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.reply_favorites_id_seq OWNED BY public.reply_favorites.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: divansh
--

CREATE TABLE public.users (
    id integer NOT NULL,
    name text NOT NULL,
    username text NOT NULL,
    gender text NOT NULL,
    email text NOT NULL,
    password_hash text NOT NULL,
    current_location point,
    created_at timestamp with time zone DEFAULT now(),
    interest text,
    college_email text,
    college character varying(255),
    interests jsonb,
    image_path character varying(255),
    last_seen timestamp with time zone DEFAULT now(),
    CONSTRAINT gender_check CHECK ((gender = ANY (ARRAY['Male'::text, 'Female'::text, 'Others'::text])))
);


ALTER TABLE public.users OWNER TO divansh;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO divansh;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: votes; Type: TABLE; Schema: public; Owner: divansh
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


ALTER TABLE public.votes OWNER TO divansh;

--
-- Name: votes_id_seq; Type: SEQUENCE; Schema: public; Owner: divansh
--

CREATE SEQUENCE public.votes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.votes_id_seq OWNER TO divansh;

--
-- Name: votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: divansh
--

ALTER SEQUENCE public.votes_id_seq OWNED BY public.votes.id;


--
-- Name: chat_messages id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);


--
-- Name: communities id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.communities ALTER COLUMN id SET DEFAULT nextval('public.communities_id_seq'::regclass);


--
-- Name: community_members id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_members ALTER COLUMN id SET DEFAULT nextval('public.community_members_id_seq'::regclass);


--
-- Name: community_posts id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_posts ALTER COLUMN id SET DEFAULT nextval('public.community_posts_id_seq'::regclass);


--
-- Name: event_participants id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.event_participants ALTER COLUMN id SET DEFAULT nextval('public.event_participants_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: post_favorites id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.post_favorites ALTER COLUMN id SET DEFAULT nextval('public.post_favorites_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: replies id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.replies ALTER COLUMN id SET DEFAULT nextval('public.replies_id_seq'::regclass);


--
-- Name: reply_favorites id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.reply_favorites ALTER COLUMN id SET DEFAULT nextval('public.reply_favorites_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: votes id; Type: DEFAULT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.votes ALTER COLUMN id SET DEFAULT nextval('public.votes_id_seq'::regclass);


--
-- Data for Name: chat_messages; Type: TABLE DATA; Schema: public; Owner: divansh
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
\.


--
-- Data for Name: communities; Type: TABLE DATA; Schema: public; Owner: divansh
--

COPY public.communities (id, name, description, created_by, created_at, primary_location, interest) FROM stdin;
1	Tech Enthusiasts	A community for tech lovers	1	2025-03-05 08:58:09.725786+05:30	(28.7041,77.1025)	Tech
2	Gaming Hub	Discuss latest games and updates	2	2025-03-05 08:58:09.725786+05:30	(37.7749,-122.4194)	Gaming
3	Book Readers	Share and review books	3	2025-03-05 08:58:09.725786+05:30	(51.5074,-0.1278)	Other
8	x	x	4	2025-03-12 11:23:55.056978+05:30	(12,12)	Other
12	Kanisk Fan club	people who are die hard fans of kanishk	5	2025-03-31 18:29:40.977342+05:30	(0,0)	Social
4	Fitness Freaks	A place to discuss workouts and nutrition	1	2025-03-05 08:58:09.725786+05:30	(40.7128,-74.006)	Sports
5	AI & ML Researchers	Community for AI and ML discussions	2	2025-03-05 08:58:09.725786+05:30	(34.0522,-118.2437)	Science
11	Star Wars	a starwars fan club event	5	2025-03-31 00:28:39.951593+05:30	(1234,1234)	Other
13	IPL Betting	We collectively make a informed decision by complex calculation and mathematical analysis and use startegic investment plans	5	2025-04-01 15:35:16.984086+05:30	(0,0)	Sports
14	White Girl Song Fan Club	Fans of Taylor Swift, Katy Perry, Miley Cyrus, Olivia Rodrigo and Sabrina Carpenter	5	2025-04-01 18:31:31.511088+05:30	(0,0)	Music
15	Content Creators	All content creators join for collab	5	2025-04-06 02:57:23.252936+05:30	(0,0)	Social
16	lol	...	4	2025-04-15 12:33:34.069313+05:30	(0,0)	Science
17	Snooker/Pool	people who wants to play snooker or pool can join this coomunity	33	2025-04-16 02:09:49.927349+05:30	(0,0)	Activities
\.


--
-- Data for Name: community_members; Type: TABLE DATA; Schema: public; Owner: divansh
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
12	4	8	2025-03-30 20:55:19.275987+05:30
15	5	11	2025-03-31 12:20:44.841498+05:30
17	5	12	2025-03-31 18:29:40.977342+05:30
21	5	13	2025-04-01 15:35:16.984086+05:30
22	5	14	2025-04-01 18:31:31.511088+05:30
26	4	12	2025-04-02 11:53:42.490958+05:30
27	5	2	2025-04-03 19:37:55.50591+05:30
33	33	14	2025-04-04 02:29:54.395184+05:30
34	39	14	2025-04-06 02:50:10.307936+05:30
35	39	13	2025-04-06 02:53:43.26876+05:30
36	5	15	2025-04-06 02:57:23.252936+05:30
38	33	15	2025-04-06 02:57:41.466061+05:30
40	33	11	2025-04-06 02:58:01.555162+05:30
43	33	12	2025-04-14 02:26:26.439559+05:30
45	33	3	2025-04-14 02:26:31.622447+05:30
47	4	16	2025-04-15 12:33:34.069313+05:30
48	33	17	2025-04-16 02:09:49.927349+05:30
52	33	16	2025-04-16 17:14:04.04501+05:30
53	33	13	2025-04-16 17:14:29.88461+05:30
\.


--
-- Data for Name: community_posts; Type: TABLE DATA; Schema: public; Owner: divansh
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
-- Data for Name: event_participants; Type: TABLE DATA; Schema: public; Owner: divansh
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
15	6	32	2025-04-02 15:28:09.729286+05:30
17	6	33	2025-04-03 19:57:26.878876+05:30
18	7	33	2025-04-03 19:58:19.727596+05:30
21	8	5	2025-04-03 22:48:17.3868+05:30
23	9	39	2025-04-06 02:52:30.553668+05:30
25	9	33	2025-04-06 02:55:20.575581+05:30
26	9	5	2025-04-06 02:56:09.879666+05:30
27	7	5	2025-04-10 17:21:04.042551+05:30
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: divansh
--

COPY public.events (id, community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url, created_at) FROM stdin;
1	1	1	Tech Talk: Future of AI	Discussing advancements in AI and ML.	Online (Zoom)	2025-04-03 01:09:14.605861+05:30	50	https://images.unsplash.com/photo-1593349114759-15e4b8a451a7	2025-03-31 01:09:14.605861+05:30
2	1	4	Weekly Coding Meetup	Casual coding session, bring your projects!	Community Hub Room A	2025-04-01 11:09:14.605861+05:30	20	\N	2025-03-31 01:09:14.605861+05:30
3	2	5	Morning Yoga Session	Relaxing yoga session to start the day.	Central Park (East Meadow)	2025-03-31 13:09:14.605861+05:30	15	https://images.unsplash.com/photo-1544367567-0f2fcb009e0b	2025-03-31 01:09:14.605861+05:30
4	11	4	lol		lol	2025-04-01 12:00:00+05:30	5	\N	2025-03-31 12:00:54.461422+05:30
6	14	4	xxx		1,1	2025-04-03 11:54:00+05:30	5	\N	2025-04-02 11:55:02.234448+05:30
7	14	33	Simping on Sabrina Carpenter	Simp	1,1	2025-04-04 19:57:00+05:30	5	\N	2025-04-03 19:58:19.727596+05:30
8	13	5	csk vs rcb		1,1	2025-04-04 22:48:00+05:30	5	\N	2025-04-03 22:48:17.3868+05:30
9	14	39	Katy Pery Concert	pls join	9,9	2025-04-16 02:51:00+05:30	10	\N	2025-04-06 02:52:30.553668+05:30
10	17	4	xxx		1,1	2025-04-17 14:02:00+05:30	69	\N	2025-04-16 14:02:53.568258+05:30
\.


--
-- Data for Name: post_favorites; Type: TABLE DATA; Schema: public; Owner: divansh
--

COPY public.post_favorites (id, user_id, post_id, favorited_at) FROM stdin;
1	2	1	2025-03-12 10:58:37.337404+05:30
2	3	2	2025-03-12 10:58:37.337404+05:30
3	1	3	2025-03-12 10:58:37.337404+05:30
4	3	7	2025-03-12 10:58:37.337404+05:30
5	2	10	2025-03-12 10:58:37.337404+05:30
\.


--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: divansh
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
\.


--
-- Data for Name: replies; Type: TABLE DATA; Schema: public; Owner: divansh
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
\.


--
-- Data for Name: reply_favorites; Type: TABLE DATA; Schema: public; Owner: divansh
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
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: divansh
--

COPY public.users (id, name, username, gender, email, password_hash, current_location, created_at, interest, college_email, college, interests, image_path, last_seen) FROM stdin;
2	Bob Smith	bobsmith	Male	bob@example.com	$2a$06$18cmMhqNGZYsr315AuEjDOkAD0ALxI1ZZc0HqJFLl3l01Qi7FWbMS	(37.7749,-122.4194)	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
3	Charlie Brown	charlieb	Male	charlie@example.com	$2a$06$cwLWRg/f0OnrsZ1zulJCZeEK1dm.gaonY/we92J5BtvXsS9TRAJA.	(51.5074,-0.1278)	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
7	x12e	x2412	Male	x124124	$2b$10$v7ZeQnWlQHqRXKH2E5AUiOWPiV1hUa0vh515qU1mX7vwUVZAOfOP2	(0,0)	2025-03-05 09:22:43.861367+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
8	1	1	Male	1	$2b$10$TQeQmCfQ3YaIl48gJ3RCsO8vCNknEBELh0CcZWX0nqLY6HO3muSSC	(0,0)	2025-03-05 10:04:11.212485+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
10	lol	lol	Male	lol	$2b$12$NyPiU.qzTF67ye7b/2oq5utk055MlLnHp1vX9GrDUFpIv.nEeGLFe	(0,0)	2025-03-10 09:36:41.231915+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
13	lol	lol5	Male	lol5	$2b$12$mqT1RCQ8IvonmntYL8jQYej.REoXqjeRnkHFMyuz7aLJxiZvYkRlK	(0,0)	2025-03-10 09:39:51.840627+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
14	pqkd	jsk	Male	oak	$2b$12$/4KFxcXD7Ue1CMebGn1h0eOepufPEsjwJ8KMEjAtxeaauZTzNn5gW	(0,0)	2025-03-10 15:31:09.036156+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
16	John Doe	johndoe	Male	johndoe@example.com	$2b$12$N4tDK8n32Vy4PsHwy9nBAOvXNXusFS3JdQTmRfRTNfvJDBXRgWl3K	(12.34,56.78)	2025-03-12 08:26:00.954317+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
19	John Doe	johndoe1	Male	johndoe1@example.com	$2b$12$iBt8qIQyKn4zFLav8pajUOzWi6wSwoYLl.mOKBuazD8c4cP0q8EUy	(37.7749,-122.4194)	2025-03-12 09:04:50.74422+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
24	x	xxx	Others	xxx	x	(28.7041,77.1025)	2025-03-13 07:13:00.194274+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30
29	xs	sx	Female	xs@sx.xs	$2b$12$NIjCNk0qmfy9Yb0tTTwnNeRhE4ncb7eG6KWgdB96YEXw1fiM9aLrK	(1,1)	2025-03-18 05:36:00.111311+05:30	\N	\N	NSUT	\N	user_images/sx_8f73ae03-0564-4240-8a79-e8ca11f36586.webp	2025-03-31 00:56:34.57811+05:30
30	xwq	xqw	Male	a@b.c	$2b$12$RfQwDGr2z42FXvs5u5kKcu7W/z.jOXFNUAtH4/VgwW6a9aj3W3bke	(2,2)	2025-03-18 05:39:58.944204+05:30	\N	\N	VIT Vellore	\N	user_images/xqw_5a852f0c-c581-4600-a028-68d37ada6c5b.webp	2025-03-31 00:56:34.57811+05:30
33	ad	k30	Female	k@1	$2b$12$rwIEsZ2HolxcBaF9Sjqqhe6FWZGDNKAOk0uMqLsqTxKKAIVytyZy6	(1,1)	2025-04-03 19:56:36.068985+05:30	Movies	\N	VIT Vellore	\N	\N	2025-04-18 23:22:54.889799+05:30
36	lo	ol	Female	lo@m.n	$2b$12$CMS3nocdPqoi2SnrQDiEYuaodeAIBX811riXaKKMM.oEDNF4aQNui	(1,1)	2025-04-04 20:34:18.437863+05:30	Gymming	\N	MIT Manipal	\N	\N	2025-04-04 20:34:18.437863+05:30
37	Shawn	S29	Male	s@vit	$2b$12$33sy7fho1kspzTbb732lN.0s1TwBD60PM/TRKjlWIPmBp8yOyE4TO	(1,1)	2025-04-04 22:14:02.439451+05:30	Gardening	\N	VIT Vellore	\N	\N	2025-04-04 22:14:02.439451+05:30
32	lol1	lol1	Others	lol1@example.com	$2b$12$ReQnX7VKyAVhXeAdGYlaxe6/0HxAg9H11Eo8MiiKrSFsdrj1Ox3Ai	(1,1)	2025-04-02 15:26:12.240858+05:30	Coding	\N	IIT Delhi	\N	\N	2025-04-02 15:28:09.657667+05:30
1	Alice Johnson	alicej	Female	alice@example.com	$2a$06$/tBglqJKbJvIcwuSwRU75eNDHngPmyLDNryhpawSl/thLFdcpUjlS	(28.7041,77.1025)	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	\N	2025-04-05 19:03:26.339828+05:30
35	lol	lol9	Male	lol@lol.lol	$2b$12$W/vLE2.aLWNuCwGG6C1a/.v0WcNxe21.cwBeTNONvDWuxhEf6.obq	(1,1)	2025-04-03 22:12:27.879964+05:30	Video Games	\N	IIT Delhi	\N	\N	2025-04-03 22:12:27.879964+05:30
39	fuck-all name	ligma	Male	sane@abc	$2b$12$EGmsPDNwWFYP6OgE2dpqlOpcc9kjgJupraFuCsl.A0enGHNvEKOA2	(0,0)	2025-04-06 02:40:03.596321+05:30	Reading	\N	SRM Chennai	\N	\N	2025-04-06 16:32:57.319082+05:30
5	Kanishk Prasad	kanishk	Male	kanishk.0030@gmail.com	$2a$06$Mw5KgOS9TLc2vvctHz8qT.n6CKU08/otWjMD7Z3jf8c0kPerO/ZGO	(28.7041,77.1025)	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	\N	2025-04-10 17:21:03.999905+05:30
4	Divansh Prasad	divansh	Male	divanshthebest@gmail.com	$2a$06$Hv2JBsgYF5.8/S7YLgIzBugK1jDBY3PgUXf95ys82rO6lJSzAIdZK	(28.7041,77.1025)	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	user_images/Passport-photo.png	2025-04-16 14:03:07.325917+05:30
\.


--
-- Data for Name: votes; Type: TABLE DATA; Schema: public; Owner: divansh
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
-- Name: chat_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.chat_messages_id_seq', 17, true);


--
-- Name: communities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.communities_id_seq', 17, true);


--
-- Name: community_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.community_members_id_seq', 53, true);


--
-- Name: community_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.community_posts_id_seq', 12, true);


--
-- Name: event_participants_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.event_participants_id_seq', 42, true);


--
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.events_id_seq', 10, true);


--
-- Name: post_favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.post_favorites_id_seq', 8, true);


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.posts_id_seq', 48, true);


--
-- Name: replies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.replies_id_seq', 30, true);


--
-- Name: reply_favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.reply_favorites_id_seq', 8, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.users_id_seq', 39, true);


--
-- Name: votes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: divansh
--

SELECT pg_catalog.setval('public.votes_id_seq', 45, true);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: communities communities_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (id);


--
-- Name: community_members community_members_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_pkey PRIMARY KEY (id);


--
-- Name: community_members community_members_user_id_community_id_key; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_community_id_key UNIQUE (user_id, community_id);


--
-- Name: community_posts community_posts_community_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_post_id_key UNIQUE (community_id, post_id);


--
-- Name: community_posts community_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_pkey PRIMARY KEY (id);


--
-- Name: event_participants event_participants_event_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_user_id_key UNIQUE (event_id, user_id);


--
-- Name: event_participants event_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: post_favorites post_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_pkey PRIMARY KEY (id);


--
-- Name: post_favorites post_favorites_user_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_post_id_key UNIQUE (user_id, post_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: replies replies_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_pkey PRIMARY KEY (id);


--
-- Name: reply_favorites reply_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_pkey PRIMARY KEY (id);


--
-- Name: reply_favorites reply_favorites_user_id_reply_id_key; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_reply_id_key UNIQUE (user_id, reply_id);


--
-- Name: votes unique_user_post_vote; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_post_vote UNIQUE (user_id, post_id);


--
-- Name: votes unique_user_reply_vote; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_reply_vote UNIQUE (user_id, reply_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: votes votes_pkey; Type: CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- Name: idx_chat_messages_community_id; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_chat_messages_community_id ON public.chat_messages USING btree (community_id) WHERE (community_id IS NOT NULL);


--
-- Name: idx_chat_messages_event_id; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_chat_messages_event_id ON public.chat_messages USING btree (event_id) WHERE (event_id IS NOT NULL);


--
-- Name: idx_chat_messages_timestamp; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_chat_messages_timestamp ON public.chat_messages USING btree ("timestamp" DESC);


--
-- Name: idx_event_participants_event_id; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_event_participants_event_id ON public.event_participants USING btree (event_id);


--
-- Name: idx_event_participants_user_id; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_event_participants_user_id ON public.event_participants USING btree (user_id);


--
-- Name: idx_events_community_id; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_events_community_id ON public.events USING btree (community_id);


--
-- Name: idx_events_event_timestamp; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_events_event_timestamp ON public.events USING btree (event_timestamp);


--
-- Name: idx_posts_created_at; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_posts_created_at ON public.posts USING btree (created_at DESC);


--
-- Name: idx_replies_created_at; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_replies_created_at ON public.replies USING btree (created_at);


--
-- Name: idx_replies_post_id; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_replies_post_id ON public.replies USING btree (post_id);


--
-- Name: idx_users_last_seen; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_users_last_seen ON public.users USING btree (last_seen DESC NULLS LAST);


--
-- Name: idx_votes_on_post; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_votes_on_post ON public.votes USING btree (post_id) WHERE (post_id IS NOT NULL);


--
-- Name: idx_votes_on_reply; Type: INDEX; Schema: public; Owner: divansh
--

CREATE INDEX idx_votes_on_reply ON public.votes USING btree (reply_id) WHERE (reply_id IS NOT NULL);


--
-- Name: chat_messages chat_messages_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: chat_messages chat_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: communities communities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: community_members community_members_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_members community_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: community_posts community_posts_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_posts community_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: event_participants event_participants_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- Name: event_participants event_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: events events_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: events events_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: post_favorites post_favorites_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_favorites post_favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: replies replies_parent_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_parent_reply_id_fkey FOREIGN KEY (parent_reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- Name: replies replies_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: replies replies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reply_favorites reply_favorites_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- Name: reply_favorites reply_favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: votes votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: votes votes_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- Name: votes votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: divansh
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

