--
-- PostgreSQL database dump
--

-- Dumped from database version 15.12 (Debian 15.12-0+deb12u2)
-- Dumped by pg_dump version 15.12 (Debian 15.12-0+deb12u2)

-- Started on 2025-05-01 22:17:12 IST

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
-- TOC entry 2 (class 3079 OID 16390)
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- TOC entry 3581 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 234 (class 1259 OID 16906)
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: kanishk
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


ALTER TABLE public.chat_messages OWNER TO kanishk;

--
-- TOC entry 233 (class 1259 OID 16905)
-- Name: chat_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.chat_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chat_messages_id_seq OWNER TO kanishk;

--
-- TOC entry 3582 (class 0 OID 0)
-- Dependencies: 233
-- Name: chat_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.chat_messages_id_seq OWNED BY public.chat_messages.id;


--
-- TOC entry 215 (class 1259 OID 16427)
-- Name: communities; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.communities (
    id integer NOT NULL,
    name text NOT NULL,
    description text,
    created_by integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    primary_location point,
    interest text,
    logo_path text,
    CONSTRAINT check_interest CHECK ((interest = ANY (ARRAY['Gaming'::text, 'Tech'::text, 'Science'::text, 'Music'::text, 'Sports'::text, 'College Event'::text, 'Activities'::text, 'Social'::text, 'Other'::text])))
);


ALTER TABLE public.communities OWNER TO kanishk;

--
-- TOC entry 216 (class 1259 OID 16433)
-- Name: communities_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.communities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.communities_id_seq OWNER TO kanishk;

--
-- TOC entry 3583 (class 0 OID 0)
-- Dependencies: 216
-- Name: communities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.communities_id_seq OWNED BY public.communities.id;


--
-- TOC entry 217 (class 1259 OID 16434)
-- Name: community_members; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.community_members (
    id integer NOT NULL,
    user_id integer NOT NULL,
    community_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.community_members OWNER TO kanishk;

--
-- TOC entry 218 (class 1259 OID 16438)
-- Name: community_members_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.community_members_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_members_id_seq OWNER TO kanishk;

--
-- TOC entry 3584 (class 0 OID 0)
-- Dependencies: 218
-- Name: community_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.community_members_id_seq OWNED BY public.community_members.id;


--
-- TOC entry 219 (class 1259 OID 16439)
-- Name: community_posts; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.community_posts (
    id integer NOT NULL,
    community_id integer NOT NULL,
    post_id integer NOT NULL,
    added_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.community_posts OWNER TO kanishk;

--
-- TOC entry 220 (class 1259 OID 16443)
-- Name: community_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.community_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_posts_id_seq OWNER TO kanishk;

--
-- TOC entry 3585 (class 0 OID 0)
-- Dependencies: 220
-- Name: community_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.community_posts_id_seq OWNED BY public.community_posts.id;


--
-- TOC entry 238 (class 1259 OID 16959)
-- Name: event_participants; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.event_participants (
    id integer NOT NULL,
    event_id integer NOT NULL,
    user_id integer NOT NULL,
    joined_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.event_participants OWNER TO kanishk;

--
-- TOC entry 237 (class 1259 OID 16958)
-- Name: event_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.event_participants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.event_participants_id_seq OWNER TO kanishk;

--
-- TOC entry 3586 (class 0 OID 0)
-- Dependencies: 237
-- Name: event_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.event_participants_id_seq OWNED BY public.event_participants.id;


--
-- TOC entry 236 (class 1259 OID 16936)
-- Name: events; Type: TABLE; Schema: public; Owner: kanishk
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


ALTER TABLE public.events OWNER TO kanishk;

--
-- TOC entry 235 (class 1259 OID 16935)
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.events_id_seq OWNER TO kanishk;

--
-- TOC entry 3587 (class 0 OID 0)
-- Dependencies: 235
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- TOC entry 221 (class 1259 OID 16444)
-- Name: post_favorites; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.post_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    post_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.post_favorites OWNER TO kanishk;

--
-- TOC entry 222 (class 1259 OID 16448)
-- Name: post_favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.post_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.post_favorites_id_seq OWNER TO kanishk;

--
-- TOC entry 3588 (class 0 OID 0)
-- Dependencies: 222
-- Name: post_favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.post_favorites_id_seq OWNED BY public.post_favorites.id;


--
-- TOC entry 223 (class 1259 OID 16449)
-- Name: posts; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    title character varying(255) NOT NULL,
    image_path text
);


ALTER TABLE public.posts OWNER TO kanishk;

--
-- TOC entry 224 (class 1259 OID 16455)
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.posts_id_seq OWNER TO kanishk;

--
-- TOC entry 3589 (class 0 OID 0)
-- Dependencies: 224
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- TOC entry 225 (class 1259 OID 16456)
-- Name: replies; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.replies (
    id integer NOT NULL,
    post_id integer NOT NULL,
    user_id integer NOT NULL,
    content text NOT NULL,
    parent_reply_id integer,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.replies OWNER TO kanishk;

--
-- TOC entry 226 (class 1259 OID 16462)
-- Name: replies_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.replies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.replies_id_seq OWNER TO kanishk;

--
-- TOC entry 3590 (class 0 OID 0)
-- Dependencies: 226
-- Name: replies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.replies_id_seq OWNED BY public.replies.id;


--
-- TOC entry 227 (class 1259 OID 16463)
-- Name: reply_favorites; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.reply_favorites (
    id integer NOT NULL,
    user_id integer NOT NULL,
    reply_id integer NOT NULL,
    favorited_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.reply_favorites OWNER TO kanishk;

--
-- TOC entry 228 (class 1259 OID 16467)
-- Name: reply_favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.reply_favorites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reply_favorites_id_seq OWNER TO kanishk;

--
-- TOC entry 3591 (class 0 OID 0)
-- Dependencies: 228
-- Name: reply_favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.reply_favorites_id_seq OWNED BY public.reply_favorites.id;


--
-- TOC entry 239 (class 1259 OID 17010)
-- Name: user_followers; Type: TABLE; Schema: public; Owner: kanishk
--

CREATE TABLE public.user_followers (
    follower_id integer NOT NULL,
    following_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.user_followers OWNER TO kanishk;

--
-- TOC entry 229 (class 1259 OID 16468)
-- Name: users; Type: TABLE; Schema: public; Owner: kanishk
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
    current_location_address text,
    CONSTRAINT gender_check CHECK ((gender = ANY (ARRAY['Male'::text, 'Female'::text, 'Others'::text])))
);


ALTER TABLE public.users OWNER TO kanishk;

--
-- TOC entry 230 (class 1259 OID 16475)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO kanishk;

--
-- TOC entry 3592 (class 0 OID 0)
-- Dependencies: 230
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 231 (class 1259 OID 16476)
-- Name: votes; Type: TABLE; Schema: public; Owner: kanishk
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


ALTER TABLE public.votes OWNER TO kanishk;

--
-- TOC entry 232 (class 1259 OID 16480)
-- Name: votes_id_seq; Type: SEQUENCE; Schema: public; Owner: kanishk
--

CREATE SEQUENCE public.votes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.votes_id_seq OWNER TO kanishk;

--
-- TOC entry 3593 (class 0 OID 0)
-- Dependencies: 232
-- Name: votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kanishk
--

ALTER SEQUENCE public.votes_id_seq OWNED BY public.votes.id;


--
-- TOC entry 3314 (class 2604 OID 16909)
-- Name: chat_messages id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.chat_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_messages_id_seq'::regclass);


--
-- TOC entry 3295 (class 2604 OID 16481)
-- Name: communities id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.communities ALTER COLUMN id SET DEFAULT nextval('public.communities_id_seq'::regclass);


--
-- TOC entry 3297 (class 2604 OID 16482)
-- Name: community_members id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_members ALTER COLUMN id SET DEFAULT nextval('public.community_members_id_seq'::regclass);


--
-- TOC entry 3299 (class 2604 OID 16483)
-- Name: community_posts id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_posts ALTER COLUMN id SET DEFAULT nextval('public.community_posts_id_seq'::regclass);


--
-- TOC entry 3319 (class 2604 OID 16962)
-- Name: event_participants id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.event_participants ALTER COLUMN id SET DEFAULT nextval('public.event_participants_id_seq'::regclass);


--
-- TOC entry 3316 (class 2604 OID 16939)
-- Name: events id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- TOC entry 3301 (class 2604 OID 16484)
-- Name: post_favorites id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.post_favorites ALTER COLUMN id SET DEFAULT nextval('public.post_favorites_id_seq'::regclass);


--
-- TOC entry 3303 (class 2604 OID 16485)
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- TOC entry 3305 (class 2604 OID 16486)
-- Name: replies id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.replies ALTER COLUMN id SET DEFAULT nextval('public.replies_id_seq'::regclass);


--
-- TOC entry 3307 (class 2604 OID 16487)
-- Name: reply_favorites id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.reply_favorites ALTER COLUMN id SET DEFAULT nextval('public.reply_favorites_id_seq'::regclass);


--
-- TOC entry 3309 (class 2604 OID 16488)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 3312 (class 2604 OID 16489)
-- Name: votes id; Type: DEFAULT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.votes ALTER COLUMN id SET DEFAULT nextval('public.votes_id_seq'::regclass);


--
-- TOC entry 3570 (class 0 OID 16906)
-- Dependencies: 234
-- Data for Name: chat_messages; Type: TABLE DATA; Schema: public; Owner: kanishk
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
\.


--
-- TOC entry 3551 (class 0 OID 16427)
-- Dependencies: 215
-- Data for Name: communities; Type: TABLE DATA; Schema: public; Owner: kanishk
--

COPY public.communities (id, name, description, created_by, created_at, primary_location, interest, logo_path) FROM stdin;
1	Tech Enthusiasts	A community for tech lovers	1	2025-03-05 08:58:09.725786+05:30	(28.7041,77.1025)	Tech	\N
2	Gaming Hub	Discuss latest games and updates	2	2025-03-05 08:58:09.725786+05:30	(37.7749,-122.4194)	Gaming	\N
3	Book Readers	Share and review books	3	2025-03-05 08:58:09.725786+05:30	(51.5074,-0.1278)	Other	\N
12	Kanisk Fan club	people who are die hard fans of kanishk	5	2025-03-31 18:29:40.977342+05:30	(0,0)	Social	\N
4	Fitness Freaks	A place to discuss workouts and nutrition	1	2025-03-05 08:58:09.725786+05:30	(40.7128,-74.006)	Sports	\N
5	AI & ML Researchers	Community for AI and ML discussions	2	2025-03-05 08:58:09.725786+05:30	(34.0522,-118.2437)	Science	\N
11	Star Wars	a starwars fan club event	5	2025-03-31 00:28:39.951593+05:30	(1234,1234)	Other	\N
13	IPL Betting	We collectively make a informed decision by complex calculation and mathematical analysis and use startegic investment plans	5	2025-04-01 15:35:16.984086+05:30	(0,0)	Sports	\N
14	White Girl Song Fan Club	Fans of Taylor Swift, Katy Perry, Miley Cyrus, Olivia Rodrigo and Sabrina Carpenter	5	2025-04-01 18:31:31.511088+05:30	(0,0)	Music	\N
15	Content Creators	All content creators join for collab	5	2025-04-06 02:57:23.252936+05:30	(0,0)	Social	\N
16	lol	...	4	2025-04-15 12:33:34.069313+05:30	(0,0)	Science	\N
\.


--
-- TOC entry 3553 (class 0 OID 16434)
-- Dependencies: 217
-- Data for Name: community_members; Type: TABLE DATA; Schema: public; Owner: kanishk
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
-- TOC entry 3555 (class 0 OID 16439)
-- Dependencies: 219
-- Data for Name: community_posts; Type: TABLE DATA; Schema: public; Owner: kanishk
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
-- TOC entry 3574 (class 0 OID 16959)
-- Dependencies: 238
-- Data for Name: event_participants; Type: TABLE DATA; Schema: public; Owner: kanishk
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
-- TOC entry 3572 (class 0 OID 16936)
-- Dependencies: 236
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: kanishk
--

COPY public.events (id, community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url, created_at) FROM stdin;
1	1	1	Tech Talk: Future of AI	Discussing advancements in AI and ML.	Online (Zoom)	2025-04-03 01:09:14.605861+05:30	50	https://images.unsplash.com/photo-1593349114759-15e4b8a451a7	2025-03-31 01:09:14.605861+05:30
2	1	4	Weekly Coding Meetup	Casual coding session, bring your projects!	Community Hub Room A	2025-04-01 11:09:14.605861+05:30	20	\N	2025-03-31 01:09:14.605861+05:30
3	2	5	Morning Yoga Session	Relaxing yoga session to start the day.	Central Park (East Meadow)	2025-03-31 13:09:14.605861+05:30	15	https://images.unsplash.com/photo-1544367567-0f2fcb009e0b	2025-03-31 01:09:14.605861+05:30
4	11	4	lol		lol	2025-04-01 12:00:00+05:30	5	\N	2025-03-31 12:00:54.461422+05:30
6	14	4	xxx		1,1	2025-04-03 11:54:00+05:30	5	\N	2025-04-02 11:55:02.234448+05:30
8	13	5	csk vs rcb		1,1	2025-04-04 22:48:00+05:30	5	\N	2025-04-03 22:48:17.3868+05:30
\.


--
-- TOC entry 3557 (class 0 OID 16444)
-- Dependencies: 221
-- Data for Name: post_favorites; Type: TABLE DATA; Schema: public; Owner: kanishk
--

COPY public.post_favorites (id, user_id, post_id, favorited_at) FROM stdin;
1	2	1	2025-03-12 10:58:37.337404+05:30
2	3	2	2025-03-12 10:58:37.337404+05:30
3	1	3	2025-03-12 10:58:37.337404+05:30
4	3	7	2025-03-12 10:58:37.337404+05:30
5	2	10	2025-03-12 10:58:37.337404+05:30
\.


--
-- TOC entry 3559 (class 0 OID 16449)
-- Dependencies: 223
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: kanishk
--

COPY public.posts (id, user_id, content, created_at, title, image_path) FROM stdin;
1	1	Check out the new AI advancements this year!	2025-03-05 08:59:17.753175+05:30	Latest in Tech	\N
2	2	Exploring the future of computation.	2025-03-05 08:59:17.753175+05:30	Quantum Computing	\N
3	3	What are your favorite first-person shooters?	2025-03-05 08:59:17.753175+05:30	Best FPS Games	\N
4	1	Join our latest gaming competitions!	2025-03-05 08:59:17.753175+05:30	Gaming Tournaments	\N
5	2	Here are 5 books that changed my life.	2025-03-05 08:59:17.753175+05:30	Must-Read Books	\N
6	3	Which genre do you prefer?	2025-03-05 08:59:17.753175+05:30	Fantasy vs Sci-Fi	\N
7	1	No gym? No problem! Try these routines.	2025-03-05 08:59:17.753175+05:30	Best Home Workouts	\N
8	2	Which diet is better for muscle gain?	2025-03-05 08:59:17.753175+05:30	Keto vs Vegan	\N
9	3	A beginner’s guide to deep learning.	2025-03-05 08:59:17.753175+05:30	Neural Networks Explained	\N
10	1	The challenges of bias in machine learning.	2025-03-05 08:59:17.753175+05:30	AI Ethics	\N
32	16	Testing post creation without community_id	2025-03-12 09:16:53.269166+05:30	Test Post	\N
37	16	Testing post creation without community_id	2025-03-12 09:24:11.810475+05:30	Test Post	\N
41	16	Testing post creation without community_id	2025-03-12 09:26:45.649699+05:30	Test Post	\N
42	16	Testing post creation without community_id	2025-03-12 09:26:48.303579+05:30	Test Post	\N
43	16	Testing post creation without community_id	2025-03-12 09:26:49.093318+05:30	Test Post	\N
44	16	Testing post creation without community_id	2025-03-12 09:28:10.649226+05:30	Test Post	\N
45	1	haha	2025-03-13 10:17:20.816993+05:30	lol	\N
46	4	cjcicuc	2025-03-19 05:18:08.204896+05:30	cucici	\N
47	5	New grok model is getting insane. What are your thoughts on that	2025-03-21 19:47:24.971766+05:30	Grok	\N
\.


--
-- TOC entry 3561 (class 0 OID 16456)
-- Dependencies: 225
-- Data for Name: replies; Type: TABLE DATA; Schema: public; Owner: kanishk
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
-- TOC entry 3563 (class 0 OID 16463)
-- Dependencies: 227
-- Data for Name: reply_favorites; Type: TABLE DATA; Schema: public; Owner: kanishk
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
-- TOC entry 3575 (class 0 OID 17010)
-- Dependencies: 239
-- Data for Name: user_followers; Type: TABLE DATA; Schema: public; Owner: kanishk
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
-- TOC entry 3565 (class 0 OID 16468)
-- Dependencies: 229
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: kanishk
--

COPY public.users (id, name, username, gender, email, password_hash, current_location, created_at, interest, college_email, college, interests, image_path, last_seen, current_location_address) FROM stdin;
2	Bob Smith	bobsmith	Male	bob@example.com	$2a$06$18cmMhqNGZYsr315AuEjDOkAD0ALxI1ZZc0HqJFLl3l01Qi7FWbMS	(37.7749,-122.4194)	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
3	Charlie Brown	charlieb	Male	charlie@example.com	$2a$06$cwLWRg/f0OnrsZ1zulJCZeEK1dm.gaonY/we92J5BtvXsS9TRAJA.	(51.5074,-0.1278)	2025-03-05 08:58:09.721498+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
7	x12e	x2412	Male	x124124	$2b$10$v7ZeQnWlQHqRXKH2E5AUiOWPiV1hUa0vh515qU1mX7vwUVZAOfOP2	(0,0)	2025-03-05 09:22:43.861367+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
8	1	1	Male	1	$2b$10$TQeQmCfQ3YaIl48gJ3RCsO8vCNknEBELh0CcZWX0nqLY6HO3muSSC	(0,0)	2025-03-05 10:04:11.212485+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
10	lol	lol	Male	lol	$2b$12$NyPiU.qzTF67ye7b/2oq5utk055MlLnHp1vX9GrDUFpIv.nEeGLFe	(0,0)	2025-03-10 09:36:41.231915+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
13	lol	lol5	Male	lol5	$2b$12$mqT1RCQ8IvonmntYL8jQYej.REoXqjeRnkHFMyuz7aLJxiZvYkRlK	(0,0)	2025-03-10 09:39:51.840627+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
14	pqkd	jsk	Male	oak	$2b$12$/4KFxcXD7Ue1CMebGn1h0eOepufPEsjwJ8KMEjAtxeaauZTzNn5gW	(0,0)	2025-03-10 15:31:09.036156+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
16	John Doe	johndoe	Male	johndoe@example.com	$2b$12$N4tDK8n32Vy4PsHwy9nBAOvXNXusFS3JdQTmRfRTNfvJDBXRgWl3K	(12.34,56.78)	2025-03-12 08:26:00.954317+05:30	\N	\N	\N	\N	\N	2025-03-31 00:56:34.57811+05:30	\N
1056	pranjay Kashyap	pranjay14	Male	pranjay1423@gmail.com	$2b$12$Wuk300q/2ERS/7HV1tPk2eDMgBqelyIvy7GDFdNLTaggxvOKOk5fy	(0,0)	2025-04-26 20:30:56.712238+05:30	Cooking	\N	MIT Manipal	\N	\N	2025-04-27 20:15:17.72424+05:30	\N
4	Divansh Prasad	kanishk	Male	kanishkthebest@gmail.com	$2a$06$Hv2JBsgYF5.8/S7YLgIzBugK1jDBY3PgUXf95ys82rO6lJSzAIdZK	(77.490407,28.487721)	2025-03-05 08:58:09.721498+05:30		\N	MIT Manipal	\N	users/kanishk/profile/f3f131e5-305b-4e7d-9bf7-a921a08fbceb.png	2025-05-01 21:59:56.931403+05:30	\N
5	Kanishk Prasad	kanishk	Male	kanishk.0030@gmail.com	$2b$12$b4GhlqETvglhS1Mx6jpPSOvjv10lTJaYZloS3PFZJNkLt8zJwWm8e	(28.7041,77.1025)	2025-03-05 08:58:09.721498+05:30	Movies,Coding,Gaming,Science,Travel,Music	\N	VIT Vellore	\N	users/kanishk/profile/d076b203-1224-4bc5-98aa-9f1e6f8d5cee.jpg	2025-05-01 14:08:10.951092+05:30	\N
1	Alice Johnson	alicej	Female	alice@example.com	$2b$12$RhHwvgup6zHJAb/U5AXYruXZ03UkT2Tyb7.MNAkB.kvEQS2XX4CO2	(28.7041,77.1025)	2025-03-05 08:58:09.721498+05:30	Music,Art,Reading,Food	\N	IIT Delhi	\N	users/alicej/profile/89b9d93b-63d0-4950-8092-552c2353545f.png	2025-05-01 15:09:12.818552+05:30	\N
1054	Vineet Prasad	vineet	Male	kanishkvineet@gmail.com	$2b$12$q/iAfgyjY68zWvZlMkaV7OKN6GASpHesMc4.u9D8Wqn8OjkMLC53G	(0,0)	2025-04-25 20:01:42.648265+05:30	Gymming,Gaming	\N	Other	\N	\N	2025-04-25 20:06:29.525967+05:30	\N
1055	Shailesh Kumar Gupta	eskge	Male	bittuskg@gmail.com	$2b$10$ZT5VBdhk7PEByY59TrDSf.NDs14QUvxeKB0i445b4xkO32W5gj5Lu	(78.443361,17.453445)	2025-04-26 20:01:25.304254+05:30	Cooking	\N	MIT Manipal	\N	users/eskge/profile/70c315ec-9557-4962-8357-a94642a03041.jpg	2025-04-30 13:45:17.07525+05:30	\N
\.


--
-- TOC entry 3567 (class 0 OID 16476)
-- Dependencies: 231
-- Data for Name: votes; Type: TABLE DATA; Schema: public; Owner: kanishk
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
-- TOC entry 3594 (class 0 OID 0)
-- Dependencies: 233
-- Name: chat_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.chat_messages_id_seq', 1326, true);


--
-- TOC entry 3595 (class 0 OID 0)
-- Dependencies: 216
-- Name: communities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.communities_id_seq', 118, true);


--
-- TOC entry 3596 (class 0 OID 0)
-- Dependencies: 218
-- Name: community_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.community_members_id_seq', 2862, true);


--
-- TOC entry 3597 (class 0 OID 0)
-- Dependencies: 220
-- Name: community_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.community_posts_id_seq', 12, true);


--
-- TOC entry 3598 (class 0 OID 0)
-- Dependencies: 237
-- Name: event_participants_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.event_participants_id_seq', 2091, true);


--
-- TOC entry 3599 (class 0 OID 0)
-- Dependencies: 235
-- Name: events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.events_id_seq', 343, true);


--
-- TOC entry 3600 (class 0 OID 0)
-- Dependencies: 222
-- Name: post_favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.post_favorites_id_seq', 8, true);


--
-- TOC entry 3601 (class 0 OID 0)
-- Dependencies: 224
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.posts_id_seq', 48, true);


--
-- TOC entry 3602 (class 0 OID 0)
-- Dependencies: 226
-- Name: replies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.replies_id_seq', 30, true);


--
-- TOC entry 3603 (class 0 OID 0)
-- Dependencies: 228
-- Name: reply_favorites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.reply_favorites_id_seq', 8, true);


--
-- TOC entry 3604 (class 0 OID 0)
-- Dependencies: 230
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.users_id_seq', 1056, true);


--
-- TOC entry 3605 (class 0 OID 0)
-- Dependencies: 232
-- Name: votes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kanishk
--

SELECT pg_catalog.setval('public.votes_id_seq', 45, true);


--
-- TOC entry 3367 (class 2606 OID 16915)
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- TOC entry 3327 (class 2606 OID 16491)
-- Name: communities communities_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (id);


--
-- TOC entry 3329 (class 2606 OID 16493)
-- Name: community_members community_members_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_pkey PRIMARY KEY (id);


--
-- TOC entry 3331 (class 2606 OID 16495)
-- Name: community_members community_members_user_id_community_id_key; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_community_id_key UNIQUE (user_id, community_id);


--
-- TOC entry 3333 (class 2606 OID 16497)
-- Name: community_posts community_posts_community_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_post_id_key UNIQUE (community_id, post_id);


--
-- TOC entry 3335 (class 2606 OID 16499)
-- Name: community_posts community_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_pkey PRIMARY KEY (id);


--
-- TOC entry 3376 (class 2606 OID 16967)
-- Name: event_participants event_participants_event_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_user_id_key UNIQUE (event_id, user_id);


--
-- TOC entry 3378 (class 2606 OID 16965)
-- Name: event_participants event_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_pkey PRIMARY KEY (id);


--
-- TOC entry 3372 (class 2606 OID 16945)
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- TOC entry 3337 (class 2606 OID 16501)
-- Name: post_favorites post_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_pkey PRIMARY KEY (id);


--
-- TOC entry 3339 (class 2606 OID 16503)
-- Name: post_favorites post_favorites_user_id_post_id_key; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_post_id_key UNIQUE (user_id, post_id);


--
-- TOC entry 3342 (class 2606 OID 16505)
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- TOC entry 3346 (class 2606 OID 16507)
-- Name: replies replies_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_pkey PRIMARY KEY (id);


--
-- TOC entry 3348 (class 2606 OID 16509)
-- Name: reply_favorites reply_favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_pkey PRIMARY KEY (id);


--
-- TOC entry 3350 (class 2606 OID 16511)
-- Name: reply_favorites reply_favorites_user_id_reply_id_key; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_reply_id_key UNIQUE (user_id, reply_id);


--
-- TOC entry 3361 (class 2606 OID 16855)
-- Name: votes unique_user_post_vote; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_post_vote UNIQUE (user_id, post_id);


--
-- TOC entry 3363 (class 2606 OID 16867)
-- Name: votes unique_user_reply_vote; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT unique_user_reply_vote UNIQUE (user_id, reply_id);


--
-- TOC entry 3384 (class 2606 OID 17015)
-- Name: user_followers user_followers_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_pkey PRIMARY KEY (follower_id, following_id);


--
-- TOC entry 3353 (class 2606 OID 16515)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 3355 (class 2606 OID 16517)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 3357 (class 2606 OID 16519)
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- TOC entry 3365 (class 2606 OID 16521)
-- Name: votes votes_pkey; Type: CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- TOC entry 3368 (class 1259 OID 16932)
-- Name: idx_chat_messages_community_id; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_chat_messages_community_id ON public.chat_messages USING btree (community_id) WHERE (community_id IS NOT NULL);


--
-- TOC entry 3369 (class 1259 OID 16933)
-- Name: idx_chat_messages_event_id; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_chat_messages_event_id ON public.chat_messages USING btree (event_id) WHERE (event_id IS NOT NULL);


--
-- TOC entry 3370 (class 1259 OID 16931)
-- Name: idx_chat_messages_timestamp; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_chat_messages_timestamp ON public.chat_messages USING btree ("timestamp" DESC);


--
-- TOC entry 3379 (class 1259 OID 16978)
-- Name: idx_event_participants_event_id; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_event_participants_event_id ON public.event_participants USING btree (event_id);


--
-- TOC entry 3380 (class 1259 OID 16979)
-- Name: idx_event_participants_user_id; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_event_participants_user_id ON public.event_participants USING btree (user_id);


--
-- TOC entry 3373 (class 1259 OID 16956)
-- Name: idx_events_community_id; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_events_community_id ON public.events USING btree (community_id);


--
-- TOC entry 3374 (class 1259 OID 16957)
-- Name: idx_events_event_timestamp; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_events_event_timestamp ON public.events USING btree (event_timestamp);


--
-- TOC entry 3381 (class 1259 OID 17026)
-- Name: idx_followers_follower; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_followers_follower ON public.user_followers USING btree (follower_id);


--
-- TOC entry 3382 (class 1259 OID 17027)
-- Name: idx_followers_following; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_followers_following ON public.user_followers USING btree (following_id);


--
-- TOC entry 3340 (class 1259 OID 16926)
-- Name: idx_posts_created_at; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_posts_created_at ON public.posts USING btree (created_at DESC);


--
-- TOC entry 3343 (class 1259 OID 16928)
-- Name: idx_replies_created_at; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_replies_created_at ON public.replies USING btree (created_at);


--
-- TOC entry 3344 (class 1259 OID 16927)
-- Name: idx_replies_post_id; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_replies_post_id ON public.replies USING btree (post_id);


--
-- TOC entry 3351 (class 1259 OID 16934)
-- Name: idx_users_last_seen; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_users_last_seen ON public.users USING btree (last_seen DESC NULLS LAST);


--
-- TOC entry 3358 (class 1259 OID 16929)
-- Name: idx_votes_on_post; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_votes_on_post ON public.votes USING btree (post_id) WHERE (post_id IS NOT NULL);


--
-- TOC entry 3359 (class 1259 OID 16930)
-- Name: idx_votes_on_reply; Type: INDEX; Schema: public; Owner: kanishk
--

CREATE INDEX idx_votes_on_reply ON public.votes USING btree (reply_id) WHERE (reply_id IS NOT NULL);


--
-- TOC entry 3401 (class 2606 OID 16916)
-- Name: chat_messages chat_messages_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- TOC entry 3402 (class 2606 OID 16921)
-- Name: chat_messages chat_messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3385 (class 2606 OID 16522)
-- Name: communities communities_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3386 (class 2606 OID 16527)
-- Name: community_members community_members_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- TOC entry 3387 (class 2606 OID 16532)
-- Name: community_members community_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_members
    ADD CONSTRAINT community_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3388 (class 2606 OID 16537)
-- Name: community_posts community_posts_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- TOC entry 3389 (class 2606 OID 16542)
-- Name: community_posts community_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.community_posts
    ADD CONSTRAINT community_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- TOC entry 3405 (class 2606 OID 16968)
-- Name: event_participants event_participants_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- TOC entry 3406 (class 2606 OID 16973)
-- Name: event_participants event_participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.event_participants
    ADD CONSTRAINT event_participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3403 (class 2606 OID 16946)
-- Name: events events_community_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_community_id_fkey FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- TOC entry 3404 (class 2606 OID 16951)
-- Name: events events_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3390 (class 2606 OID 16547)
-- Name: post_favorites post_favorites_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- TOC entry 3391 (class 2606 OID 16552)
-- Name: post_favorites post_favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.post_favorites
    ADD CONSTRAINT post_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3392 (class 2606 OID 16557)
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3393 (class 2606 OID 16841)
-- Name: replies replies_parent_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_parent_reply_id_fkey FOREIGN KEY (parent_reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- TOC entry 3394 (class 2606 OID 16567)
-- Name: replies replies_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- TOC entry 3395 (class 2606 OID 16572)
-- Name: replies replies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.replies
    ADD CONSTRAINT replies_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3396 (class 2606 OID 16577)
-- Name: reply_favorites reply_favorites_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- TOC entry 3397 (class 2606 OID 16582)
-- Name: reply_favorites reply_favorites_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.reply_favorites
    ADD CONSTRAINT reply_favorites_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3407 (class 2606 OID 17016)
-- Name: user_followers user_followers_follower_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_follower_id_fkey FOREIGN KEY (follower_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3408 (class 2606 OID 17021)
-- Name: user_followers user_followers_following_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.user_followers
    ADD CONSTRAINT user_followers_following_id_fkey FOREIGN KEY (following_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 3398 (class 2606 OID 16856)
-- Name: votes votes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- TOC entry 3399 (class 2606 OID 16861)
-- Name: votes votes_reply_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_reply_id_fkey FOREIGN KEY (reply_id) REFERENCES public.replies(id) ON DELETE CASCADE;


--
-- TOC entry 3400 (class 2606 OID 16597)
-- Name: votes votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: kanishk
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


-- Completed on 2025-05-01 22:17:12 IST

--
-- PostgreSQL database dump complete
--

