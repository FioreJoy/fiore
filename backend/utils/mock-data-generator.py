# backend/utils/mock-data-generator.py

import os
import io
import random
import uuid
import bcrypt
import psycopg2
from psycopg2.extras import execute_values, RealDictCursor # Added RealDictCursor
import json
from dotenv import load_dotenv
from faker import Faker
from minio import Minio
from minio.error import S3Error
from PIL import Image, ImageDraw, ImageFont
from datetime import datetime, timedelta, timezone
from tqdm import tqdm
import math
import re
from pathlib import Path # Added Path
import sys

# --- Configuration ---
dotenv_path_options = [
    Path(os.path.dirname(__file__)).parent / '.env',
    Path(os.path.dirname(__file__)).parent.parent / '.env'
]
dotenv_path = next((path for path in dotenv_path_options if path.is_file()), None)
if dotenv_path:
    print(f"Loading .env for mock data generator from: {dotenv_path}")
    load_dotenv(dotenv_path=dotenv_path)
else:
    print("Warning: .env file not found by mock data gen. Relying on Docker ENV or pre-set environment.")

fake = Faker()

NUM_USERS = int(os.getenv("MOCK_USERS", 100)) # Reduced for faster testing initially
NUM_COMMUNITIES = int(os.getenv("MOCK_COMMUNITIES", 20))
NUM_EVENTS_APPROX_PER_COMMUNITY = int(os.getenv("MOCK_EVENTS_PER_COMM", 2))
NUM_POSTS_PER_ACTIVE_USER_AVG = int(os.getenv("MOCK_POSTS_PER_USER", 3))
NUM_REPLIES_PER_POST_AVG = int(os.getenv("MOCK_REPLIES_PER_POST", 2))
NUM_CHAT_MESSAGES = int(os.getenv("MOCK_CHAT_MESSAGES", 200))
MEDIA_ATTACH_PROBABILITY = 0.3 # Probability a post/reply gets media

# --- Database Configuration ---
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "postgres_age") # Default to service name
DB_NAME = os.getenv("DB_NAME")
DB_PORT = os.getenv("DB_PORT", 5432)

# --- MinIO Configuration ---
MINIO_ENDPOINT_FULL = os.getenv("MINIO_ENDPOINT") # e.g., minio:9000 or http://localhost:9000
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "fiore")
MINIO_USE_SSL = os.getenv("MINIO_USE_SSL", "false").lower() == "true"

# --- Mock Data Lists ---
GENDERS = ['Male', 'Female', 'Others']
COLLEGES = ['VIT Vellore', 'MIT Manipal', 'SRM Chennai', 'IIT Delhi', 'BITS Pilani', 'NSUT', 'DTU', 'IIIT Hyderabad', 'Stanford', 'Harvard', 'UC Berkeley', 'Cambridge', 'Oxford', 'Community College', 'Online University']
INTERESTS = ['Gaming', 'Tech', 'Science', 'Music', 'Sports', 'College Event', 'Activities', 'Social', 'Other']
COMMUNITY_ADJECTIVES = ['Awesome', 'Creative', 'Digital', 'Global', 'Innovative', 'Local', 'Virtual', 'Dynamic', 'Future', 'United', 'Open', 'Collaborative', 'Sustainable', 'Academic', 'Research']
COMMUNITY_NOUNS = ['Network', 'Hub', 'Collective', 'Space', 'Zone', 'Society', 'Crew', 'Labs', 'Circle', 'Forum', 'Initiative', 'Group', 'Project', 'Association', 'Guild']
EVENT_TYPES = ['Meetup', 'Workshop', 'Conference', 'Hackathon', 'Talk', 'Social', 'Competition', 'Webinar', 'Party', 'Game Night', 'Study Session', 'AMA', 'Panel', 'Presentation', 'Demo Day']
LOCATIONS_TEXT = ['Online', 'Campus Green', 'Library Cafe', 'Room 404', 'Discord Server', 'Zoom', 'Local Park', 'Tech Hub Auditorium', 'City Center Plaza', 'Rooftop Bar', 'VR Space', 'Co-working Space', 'University Hall']
CHAT_LINES = [ 'Hello everyone!', 'Anyone free later?', 'What did you think of the last event?', 'Looking forward to the next session.', 'Can someone share the link?', 'Great point!', 'I agree.', 'That sounds interesting.', 'Maybe we can collaborate?', 'Any updates?', 'See you there!', 'Thanks for sharing!', 'What time does it start?', 'Let me know if you need help.', 'Working on a cool project right now.', 'Just checking in.', 'How is everyone doing?', 'That was fun!', 'Learned a lot today.', 'Let’s brainstorm some ideas.' ]
DEFAULT_PASSWORD_HASH = bcrypt.hashpw(b'password', bcrypt.gensalt()).decode('utf-8')
PLACEHOLDER_TEXT_TYPES = ["general_text", "code_snippet", "question", "announcement", "story_part"]
PLACEHOLDER_IMAGE_SIZES = [(800,600), (600,800), (1024,768), (768,1024), (400,300)]


# --- Helper Functions ---
def get_db_connection():
    try:
        conn = psycopg2.connect(dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD, host=DB_HOST, port=DB_PORT, cursor_factory=RealDictCursor)
        return conn
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed for mock data generator: {e}")
        exit(1)

minio_client_instance = None
def get_minio_client_singleton():
    global minio_client_instance
    if minio_client_instance: return minio_client_instance
    if not all([MINIO_ENDPOINT_FULL, MINIO_ACCESS_KEY, MINIO_SECRET_KEY]):
        print("⚠️ MinIO env vars not set for mock data. Image upload disabled.")
        return None
    try:
        endpoint_cleaned = MINIO_ENDPOINT_FULL.replace('http://','').replace('https://','')
        client = Minio(endpoint_cleaned, access_key=MINIO_ACCESS_KEY, secret_key=MINIO_SECRET_KEY, secure=MINIO_USE_SSL)
        if not client.bucket_exists(MINIO_BUCKET): client.make_bucket(MINIO_BUCKET); print(f"✅ MinIO Bucket '{MINIO_BUCKET}' created.")
        else: print(f"✅ MinIO Bucket '{MINIO_BUCKET}' exists.")
        minio_client_instance = client
        print(f"✅ Connected to MinIO at {MINIO_ENDPOINT_FULL} by mock data generator.")
        return client
    except Exception as e: print(f"❌ Failed to init MinIO client for mock data: {e}"); return None

def generate_placeholder_image(text="?", size=(200, 200), bg_color=None) -> bytes:
    img = Image.new('RGB', size, color=bg_color or (random.randint(100,200), random.randint(100,200), random.randint(100,200)))
    d = ImageDraw.Draw(img); font = ImageFont.load_default()
    try: font = ImageFont.truetype("arial.ttf", size[1] // 3)
    except IOError: pass # Use default if arial not found
    text_bbox = d.textbbox((0,0), text, font=font); text_width = text_bbox[2]-text_bbox[0]; text_height = text_bbox[3]-text_bbox[1]
    pos = ((size[0]-text_width)/2, (size[1]-text_height)/2 - size[1]//10)
    d.text(pos, text, fill=(255,255,255), font=font); img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='PNG'); return img_byte_arr.getvalue()

def upload_placeholder_to_minio(uploader_user_id: int, item_type: str, item_id: int, filename_prefix: str, text_on_image: str, size=(800,600)) -> dict | None:
    minio_client = get_minio_client_singleton()
    if not minio_client: return None

    img_data = generate_placeholder_image(text=text_on_image, size=size)
    object_name_suffix = f"{filename_prefix}_{uuid.uuid4()}.png"
    object_name = f"media/{item_type}/{item_id}/{object_name_suffix}" # e.g. media/posts/123/image_xyz.png

    if upload_to_minio_sync(img_data, object_name):
        return {
            "uploader_user_id": uploader_user_id,
            "minio_object_name": object_name,
            "mime_type": "image/png",
            "file_size_bytes": len(img_data),
            "original_filename": object_name_suffix,
            "width": size[0],
            "height": size[1],
            "duration_seconds": None
        }
    return None

def upload_to_minio_sync(data: bytes, object_name: str, content_type='image/png') -> bool:
    client = get_minio_client_singleton()
    if not client: return False
    try:
        client.put_object(MINIO_BUCKET, object_name, io.BytesIO(data), length=len(data), content_type=content_type)
        return True
    except Exception as e: print(f"❌ MinIO Upload Error (mock data) for {object_name}: {e}", file=sys.stderr); return False

def sanitize_for_path(name: str) -> str:
    name = name.strip(); name = re.sub(r'[\\/:*?"<>|\s]+', '_', name)
    name = re.sub(r'[^\w_.-]+', '', name); return name[:50] or "generic_item"

def main():
    conn = get_db_connection()
    cursor = conn.cursor()
    minio_client_ref = get_minio_client_singleton()

    generated_user_ids_map = {}
    generated_community_ids_map = {}
    generated_event_ids = []
    generated_post_ids_map = {} # post_id -> author_id
    generated_reply_ids_map = {} # reply_id -> author_id
    community_members_map = {}
    event_participants_map = {}
    batch_size = 100

    try:
        print("--- Starting Mock Data Generation ---")

        # 1. Users
        print(f"\nGenerating {NUM_USERS} users...")
        users_data_tuples = []
        # ... (user generation loop as before, creating tuples for users_data_tuples)
        for i in tqdm(range(NUM_USERS), desc="Generating Users"):
            first_name = fake.first_name(); last_name = fake.last_name()
            username = f"{first_name.lower()}{random.choice(['_','.',''])}{last_name.lower()}{random.randint(100,9999)}".replace(' ','')[:30]
            while username in generated_user_ids_map: username += str(random.randint(0,9)) # Basic uniqueness
            email = fake.unique.email()
            name = f"{first_name} {last_name}"; gender = random.choice(GENDERS)
            college = random.choice(COLLEGES); interest_text = random.choice(INTERESTS)
            num_json_interests = random.randint(1, 3)
            interests_json_list = random.sample(INTERESTS, k=min(num_json_interests, len(INTERESTS)))
            interests_jsonb_str = json.dumps(interests_json_list)
            lon, lat = fake.longitude(), fake.latitude()
            location_address_text = fake.address().replace('\n', ', ')
            created_at = fake.date_time_between(start_date="-2y", end_date="now", tzinfo=timezone.utc)
            last_seen = fake.date_time_between(start_date=created_at, end_date="now", tzinfo=timezone.utc)
            location_last_updated = fake.date_time_between(start_date=created_at, end_date=last_seen, tzinfo=timezone.utc)
            users_data_tuples.append((
                name, username, gender, email, DEFAULT_PASSWORD_HASH, created_at, interest_text,
                None, college, interests_jsonb_str, last_seen, location_address_text,
                True, True, True, True, True, True, # notify flags
                lon, lat, location_last_updated, location_address_text # last one is for public.users.location_address
            ))

        user_cols = "(name, username, gender, email, password_hash, created_at, interest, college_email, college, interests, last_seen, current_location_address, notify_new_post_in_community, notify_new_reply_to_post, notify_new_event_in_community, notify_event_reminder, notify_direct_message, notify_event_update, location, location_last_updated, location_address)"
        # Corrected to pass lon, lat for ST_MakePoint, and location_address_text again for the actual location_address column.
        insert_query_users = f"INSERT INTO users {user_cols} VALUES %s RETURNING id, username, interest;"

        print(f"  Inserting {len(users_data_tuples)} user records...")
        # execute_values expects a template string with %s for each column, not for the VALUES keyword.
        # This requires dynamically building the template or using a different approach for ST_MakePoint.
        # For simplicity with execute_values, we'll pre-format the WKT string for location.

        users_data_for_exec_values = []
        for u_tuple in users_data_tuples:
            # (name, username, ..., lon, lat, loc_last_upd, loc_addr_text)
            # The last three are lon, lat, location_last_updated, location_address
            # location = ST_SetSRID(ST_MakePoint(lon, lat), 4326)
            # location_address is the last text field
            users_data_for_exec_values.append(u_tuple[:-4] + (f"SRID=4326;POINT({u_tuple[-4]} {u_tuple[-3]})", u_tuple[-2], u_tuple[-1]))

        user_cols_exec_values = "(name, username, gender, email, password_hash, created_at, interest, college_email, college, interests, last_seen, current_location_address, notify_new_post_in_community, notify_new_reply_to_post, notify_new_event_in_community, notify_event_reminder, notify_direct_message, notify_event_update, location, location_last_updated, location_address)"
        insert_query_users_exec_values = f"INSERT INTO users {user_cols_exec_values} VALUES %s RETURNING id, username, interest;"

        for i in tqdm(range(0, len(users_data_for_exec_values), batch_size), desc="User Batch Insert"):
            batch = users_data_for_exec_values[i:i+batch_size]
            inserted_user_rows = execute_values(cursor, insert_query_users_exec_values, batch, fetch=True, page_size=batch_size)
            for row in inserted_user_rows:
                generated_user_ids_map[row['id']] = {'username': row['username'], 'interest_text': row['interest']}
        conn.commit(); print(f"✅ Inserted {len(generated_user_ids_map)} users.")

        # 1.1 User Profile Pictures (as before)
        if minio_client_ref:
            # ... (profile pic generation and linking logic unchanged, ensure it uses generated_user_ids_map)
            print("\nGenerating user profile pictures...")
            media_items_user_data = []
            profile_pic_links_data = []
            for user_id, user_info in tqdm(generated_user_ids_map.items(), desc="User Profile Pics"):
                media_info = upload_placeholder_to_minio(user_id, "users", user_id, f"{user_info['username']}_profile", user_info['username'][0].upper())
                if media_info: media_items_user_data.append(tuple(media_info.values()))

            if media_items_user_data:
                media_cols = "(uploader_user_id, minio_object_name, mime_type, file_size_bytes, original_filename, width, height, duration_seconds)"
                insert_media_query = f"INSERT INTO media_items {media_cols} VALUES %s RETURNING id, uploader_user_id;"
                for i in tqdm(range(0, len(media_items_user_data), batch_size), desc="MediaItem for ProfilePics"):
                    batch = media_items_user_data[i:i+batch_size]
                    inserted_media_rows = execute_values(cursor, insert_media_query, batch, fetch=True, page_size=batch_size)
                    for row in inserted_media_rows: profile_pic_links_data.append((row['uploader_user_id'], row['id'], datetime.now(timezone.utc)))
                conn.commit()
                if profile_pic_links_data:
                    insert_profile_pic_link_query = "INSERT INTO user_profile_picture (user_id, media_id, set_at) VALUES %s ON CONFLICT (user_id) DO UPDATE SET media_id = EXCLUDED.media_id, set_at = EXCLUDED.set_at;"
                    execute_values(cursor, insert_profile_pic_link_query, profile_pic_links_data, page_size=batch_size)
                    conn.commit(); print("✅ User profile pictures linked.")
        else: print("Skipping user profile picture gen (MinIO client not available).")


        # 2. Communities (Corrected SQL for execute_values)
        print(f"\nGenerating {NUM_COMMUNITIES} communities...")
        communities_data_tuples = []
        user_id_list_for_creators = list(generated_user_ids_map.keys())
        if not user_id_list_for_creators: print("No users to create communities."); return
        # ... (community generation loop as before, creating tuples)
        for i in tqdm(range(NUM_COMMUNITIES), desc="Generating Communities"):
            base_name = f"{random.choice(COMMUNITY_ADJECTIVES)} {random.choice(COMMUNITY_NOUNS)} {i+1}"
            interest = random.choice(INTERESTS)
            creator_id = random.choice(user_id_list_for_creators)
            description = f"A community for {interest} enthusiasts. Join us!"
            lon, lat = fake.longitude(), fake.latitude()
            location_address_text = fake.address().replace('\n',', ')
            created_at = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
            communities_data_tuples.append(( base_name, description, creator_id, created_at, interest, location_address_text, f"SRID=4326;POINT({lon} {lat})" )) # Pre-format WKT

        community_cols = "(name, description, created_by, created_at, interest, location_address, location)"
        insert_query_communities = f"INSERT INTO communities {community_cols} VALUES %s RETURNING id, name, interest, created_by;"
        print(f"  Inserting {len(communities_data_tuples)} community records...")
        for i in tqdm(range(0, len(communities_data_tuples), batch_size), desc="Community Batch Insert"):
            batch = communities_data_tuples[i:i+batch_size]
            inserted_community_rows = execute_values(cursor, insert_query_communities, batch, fetch=True, page_size=batch_size)
            for row in inserted_community_rows: generated_community_ids_map[row['id']] = {'name': row['name'], 'interest_text': row['interest'], 'creator_id': row['created_by']}
        conn.commit(); print(f"✅ Inserted {len(generated_community_ids_map)} communities.")

        # 2.1 Community Logos (as before, ensure it uses generated_community_ids_map)
        if minio_client_ref:
            # ... (community logo generation and linking logic unchanged, uses media_items & community_logo tables)
            print("\nGenerating community logos...")
            media_items_comm_data = []
            comm_logo_links_data = []
            for comm_id, comm_info in tqdm(generated_community_ids_map.items(), desc="Community Logos"):
                media_info = upload_placeholder_to_minio(comm_info['creator_id'], "communities", comm_id, f"{sanitize_for_path(comm_info['name'])}_logo", comm_info['name'][0].upper(), size=(300,300))
                if media_info: media_items_comm_data.append(tuple(media_info.values()) + (comm_id,)) # Add comm_id for linking

            if media_items_comm_data:
                media_cols = "(uploader_user_id, minio_object_name, mime_type, file_size_bytes, original_filename, width, height, duration_seconds)"
                insert_media_query_comm = f"INSERT INTO media_items {media_cols} VALUES %s RETURNING id;"

                media_insert_batch_tuples = [(d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7]) for d in media_items_comm_data]
                original_comm_ids_for_media = [d[8] for d in media_items_comm_data]

                for i in tqdm(range(0, len(media_insert_batch_tuples), batch_size), desc="MediaItem for CommLogos"):
                    current_batch_media_tuples = media_insert_batch_tuples[i:i+batch_size]
                    current_batch_comm_ids = original_comm_ids_for_media[i:i+batch_size]
                    inserted_media_ids_only = execute_values(cursor, insert_media_query_comm, current_batch_media_tuples, fetch=True, page_size=batch_size)
                    for idx, row in enumerate(inserted_media_ids_only):
                        comm_logo_links_data.append((current_batch_comm_ids[idx], row['id'], datetime.now(timezone.utc)))
                conn.commit()
                if comm_logo_links_data:
                    insert_comm_logo_link_query = "INSERT INTO community_logo (community_id, media_id, set_at) VALUES %s ON CONFLICT (community_id) DO UPDATE SET media_id = EXCLUDED.media_id, set_at = EXCLUDED.set_at;"
                    execute_values(cursor, insert_comm_logo_link_query, comm_logo_links_data, page_size=batch_size)
                    conn.commit(); print("✅ Community logos linked.")
        else: print("Skipping community logo gen (MinIO client not available).")


        # 3. Community Memberships (as before)
        # ... (unchanged, uses community_members_map and generated_user_ids_map)
        print(f"\nGenerating community memberships...")
        memberships_data = []
        community_members_map = {cid: set() for cid in generated_community_ids_map.keys()}
        for comm_id, comm_info in generated_community_ids_map.items():
            creator_id = comm_info['creator_id']
            join_time = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
            memberships_data.append((creator_id, comm_id, join_time))
            community_members_map[comm_id].add(creator_id)
        user_ids_list = list(generated_user_ids_map.keys())
        for user_id in tqdm(user_ids_list, desc="Evaluating Memberships"):
            user_int_text = generated_user_ids_map[user_id]['interest_text']
            for comm_id, comm_info in generated_community_ids_map.items():
                if user_id in community_members_map[comm_id]: continue
                comm_int_text = comm_info['interest_text']
                join_probability = 0.15 # Increased probability
                if user_int_text and comm_int_text and user_int_text == comm_int_text: join_probability = 0.40
                if random.random() < join_probability:
                    joined_at = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
                    memberships_data.append((user_id, comm_id, joined_at))
                    community_members_map[comm_id].add(user_id)
        if memberships_data:
            insert_query_members = "INSERT INTO community_members (user_id, community_id, joined_at) VALUES %s ON CONFLICT (user_id, community_id) DO NOTHING;"
            execute_values(cursor, insert_query_members, memberships_data, page_size=batch_size*2) # Larger page for simple inserts
            conn.commit(); print(f"✅ Inserted/Updated {len(memberships_data)} community memberships.")


        # backend/utils/mock-data-generator.py
        # [Previous parts of the file remain the same as in the last good version]
        # ... (Imports, Configuration, Helper Functions, User Gen, Community Gen, Membership Gen) ...

        # 4. Generate Events
        print(f"\nGenerating events...")
        events_data_tuples = [] # Store tuples for execute_values
        event_community_map = {}  # event_id -> community_id
        event_creators = {}       # event_id -> creator_id
        event_creation_times = {} # event_id -> created_at_timestamp
        # Ensure generated_event_ids is initialized if not already
        if 'generated_event_ids' not in locals() and 'generated_event_ids' not in globals():
            generated_event_ids = []


        community_ids_list_for_events = list(generated_community_ids_map.keys())
        if not community_ids_list_for_events:
            print("ℹ️ No communities to create events for.")
        else:
            for comm_id in tqdm(community_ids_list_for_events, desc="Generating Events per Comm"):
                num_events_for_comm = max(1, math.ceil(random.gauss(NUM_EVENTS_APPROX_PER_COMMUNITY, 1.5)))
                members_of_this_comm = list(community_members_map.get(comm_id, []))
                creator_fallback = generated_community_ids_map[comm_id]['creator_id']

                for _ in range(num_events_for_comm):
                    creator_id = random.choice(members_of_this_comm) if members_of_this_comm else creator_fallback
                    # Use .get() with a fallback for interest_text
                    interest_for_event = generated_community_ids_map[comm_id].get('interest_text', random.choice(INTERESTS))
                    event_type_text = random.choice(EVENT_TYPES)
                    title = f"{interest_for_event} {event_type_text} - {fake.catch_phrase()[:30]}"
                    description = fake.paragraph(nb_sentences=random.randint(2,5))
                    location_text_address = random.choice(LOCATIONS_TEXT) + f", {fake.city()}"
                    lon_e, lat_e = fake.longitude(), fake.latitude()
                    event_timestamp = fake.date_time_between(start_date="-60d",end_date="+90d",tzinfo=timezone.utc)
                    max_participants = random.randint(15,150)
                    created_at_event = fake.date_time_between(start_date="-1y", end_date=min(event_timestamp, datetime.now(timezone.utc)), tzinfo=timezone.utc)

                    events_data_tuples.append((
                        comm_id, creator_id, title, description, location_text_address,
                        event_timestamp, max_participants, None, created_at_event, # image_url is None
                        f"SRID=4326;POINT({lon_e} {lat_e})" # Pre-format WKT for location_coords
                    ))

            if events_data_tuples:
                event_cols = "(community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url, created_at, location_coords)"
                insert_query_events = f"INSERT INTO events {event_cols} VALUES %s RETURNING id, community_id, creator_id, created_at;"
                print(f"  Inserting {len(events_data_tuples)} event records...")

                current_event_index = 0
                for i in tqdm(range(0, len(events_data_tuples), batch_size), desc="Event Batch Insert"):
                    batch = events_data_tuples[i:i+batch_size]
                    inserted_event_rows = execute_values(cursor, insert_query_events, batch, fetch=True, page_size=batch_size)
                    for row in inserted_event_rows:
                        generated_event_ids.append(row['id'])
                        event_community_map[row['id']] = row['community_id']
                        event_creators[row['id']] = row['creator_id']
                        event_creation_times[row['id']] = row['created_at']
                conn.commit()
                print(f"✅ Inserted {len(generated_event_ids)} events.")
            else:
                print("ℹ️ No event data tuples were generated.")


        # 5. Event Participants
        print(f"\nGenerating event participants...")
        participants_data = []
        event_participants_map = {eid: set() for eid in generated_event_ids} # Initialize for all generated events

        # Add creators as participants first
        for event_id, creator_id in event_creators.items():
            if event_id in event_creation_times: # Ensure the event was successfully created and has a creation time
                participants_data.append((event_id, creator_id, event_creation_times[event_id]))
                event_participants_map[event_id].add(creator_id)

        # Then add other random participants
        for event_id in tqdm(generated_event_ids, desc="Evaluating Participants"):
            comm_id = event_community_map.get(event_id)
            if not comm_id:
                continue

            community_members = list(community_members_map.get(comm_id, []))
            if not community_members: # Corrected Syntax
                continue

            cursor.execute("SELECT max_participants FROM events WHERE id = %s", (event_id,))
            event_details_db = cursor.fetchone()
            max_p_event = event_details_db['max_participants'] if event_details_db else 100

            for member_id in community_members:
                if member_id in event_participants_map[event_id]:
                    continue
                if len(event_participants_map[event_id]) >= max_p_event:
                    break
                if random.random() < 0.30:
                    event_created_time = event_creation_times.get(event_id, datetime.now(timezone.utc) - timedelta(days=1))
                    # Ensure joined_at is not before event_created_time
                    start_join_date = event_created_time
                    end_join_date = datetime.now(timezone.utc)
                    if start_join_date > end_join_date : # Should not happen if event is in past/present
                        start_join_date = end_join_date - timedelta(hours=1)

                    try:
                        joined_at = fake.date_time_between(start_date=start_join_date, end_date=end_join_date, tzinfo=timezone.utc)
                    except ValueError: # Handle rare case where start_date might be equal to end_date due to precision
                        joined_at = end_join_date

                    participants_data.append((event_id, member_id, joined_at))
                    event_participants_map[event_id].add(member_id)

        if participants_data:
            insert_query_participants = "INSERT INTO event_participants (event_id, user_id, joined_at) VALUES %s ON CONFLICT (event_id, user_id) DO NOTHING;"
            execute_values(cursor, insert_query_participants, participants_data, page_size=batch_size*2)
            conn.commit()
            print(f"✅ Inserted/Updated {len(participants_data)} event participants.")
        else:
            print("ℹ️ No new event participants to insert.")


        # 6. Posts
        print(f"\nGenerating posts...")
        posts_data_tuples = []
        media_items_post_data = [] # Stores tuples for media_items table + post_id for linking
        post_media_links_data = [] # Stores tuples for post_media table

        user_id_list_for_posts = list(generated_user_ids_map.keys()) # Use this consistent list
        NUM_POSTS_PER_USER_AVG=3
        for user_id in tqdm(user_id_list_for_posts, desc="Generating Posts per User"):
            num_posts = max(0, math.ceil(random.gauss(NUM_POSTS_PER_USER_AVG, 1.5))) # Slightly more variance
            for _ in range(num_posts):
                title = fake.sentence(nb_words=random.randint(4,10))[:-1]
                content = fake.paragraph(nb_sentences=random.randint(2,6))
                created_at_post = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
                posts_data_tuples.append((user_id, content, created_at_post, title))

        post_cols = "(user_id, content, created_at, title)"
        insert_query_posts = f"INSERT INTO posts {post_cols} VALUES %s RETURNING id, user_id, created_at;" # Fetch created_at for media
        print(f"  Inserting {len(posts_data_tuples)} post records...")
        for i in tqdm(range(0, len(posts_data_tuples), batch_size), desc="Post Batch Insert"):
            batch = posts_data_tuples[i:i+batch_size]
            inserted_post_rows = execute_values(cursor, insert_query_posts, batch, fetch=True, page_size=batch_size)
            for row in inserted_post_rows:
                post_id = row['id']
                author_id = row['user_id']
                post_created_at = row['created_at'] # Get created_at for media linking
                generated_post_ids_map[post_id] = {'author_id': author_id, 'created_at': post_created_at}

                if minio_client_ref and random.random() < MEDIA_ATTACH_PROBABILITY:
                    num_media_for_post = random.randint(1,2)
                    for _ in range(num_media_for_post):
                        media_info = upload_placeholder_to_minio(
                            author_id, "posts", post_id, "post_img",
                            random.choice(PLACEHOLDER_TEXT_TYPES),
                            size=random.choice(PLACEHOLDER_IMAGE_SIZES)
                        )
                        if media_info:
                            media_items_post_data.append(tuple(media_info.values()) + (post_id,))
        conn.commit()
        print(f"✅ Inserted {len(generated_post_ids_map)} posts.")

        if media_items_post_data:
            media_cols_def = "(uploader_user_id, minio_object_name, mime_type, file_size_bytes, original_filename, width, height, duration_seconds)"
            insert_media_query = f"INSERT INTO media_items {media_cols_def} VALUES %s RETURNING id;"

            media_insert_tuples_for_posts = [(d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]) for d in media_items_post_data]
            original_post_ids_for_media_linking = [d[8] for d in media_items_post_data] # post_id was appended

            current_media_item_idx = 0
            for i in tqdm(range(0, len(media_insert_tuples_for_posts), batch_size), desc="Media Items for Posts"):
                batch_media_tuples = media_insert_tuples_for_posts[i:i+batch_size]
                inserted_media_ids_only = execute_values(cursor, insert_media_query, batch_media_tuples, fetch=True, page_size=batch_size)
                for row_media_id in inserted_media_ids_only:
                    # Link using the original_post_ids_for_media_linking list
                    post_id_to_link = original_post_ids_for_media_linking[current_media_item_idx]
                    post_media_links_data.append((post_id_to_link, row_media_id['id'], random.randint(0,1)))
                    current_media_item_idx += 1
            conn.commit()

            if post_media_links_data:
                insert_post_media_link_query = "INSERT INTO post_media (post_id, media_id, display_order) VALUES %s ON CONFLICT DO NOTHING;"
                execute_values(cursor, insert_post_media_link_query, post_media_links_data, page_size=batch_size)
                conn.commit()
                print(f"✅ {len(post_media_links_data)} Post media items linked.")


        # 7. Replies
        print(f"\nGenerating replies...")
        replies_data_tuples = []
        media_items_reply_data = [] # Stores tuples for media_items table + reply_id for linking
        reply_media_links_data = [] # Stores tuples for reply_media table

        post_ids_list_for_replies = list(generated_post_ids_map.keys())

        if post_ids_list_for_replies:
            for post_id in tqdm(post_ids_list_for_replies, desc="Generating Replies per Post"):
                num_replies = max(0, math.ceil(random.gauss(NUM_REPLIES_PER_POST_AVG, 1.5)))
                # Get post creation time to ensure replies are after post
                post_info = generated_post_ids_map.get(post_id)
                if not post_info: continue
                post_created_at = post_info['created_at']

                parent_reply_candidates_for_this_post = [] # reply_id -> created_at

                for _ in range(num_replies):
                    user_id_reply = random.choice(user_id_list_for_creators)
                    content_reply = fake.sentence(nb_words=random.randint(3,15))

                    # Ensure reply_created_at is after post_created_at
                    # And if it's a sub-reply, after parent_reply_created_at
                    min_reply_time = post_created_at
                    parent_id_for_this_reply = None

                    if parent_reply_candidates_for_this_post and random.random() < 0.3:
                        parent_reply_id_choice, parent_reply_created_at = random.choice(parent_reply_candidates_for_this_post)
                        parent_id_for_this_reply = parent_reply_id_choice
                        min_reply_time = parent_reply_created_at

                    # Ensure min_reply_time is not in the future if post/parent reply is very recent
                    if min_reply_time > datetime.now(timezone.utc):
                        created_at_reply = datetime.now(timezone.utc)
                    else:
                        created_at_reply = fake.date_time_between(start_date=min_reply_time, end_date="now", tzinfo=timezone.utc)

                    replies_data_tuples.append((post_id, user_id_reply, content_reply, parent_id_for_this_reply, created_at_reply))

            reply_cols = "(post_id, user_id, content, parent_reply_id, created_at)"
            insert_query_replies = f"INSERT INTO replies {reply_cols} VALUES %s RETURNING id, user_id, created_at, parent_reply_id;"
            print(f"  Inserting {len(replies_data_tuples)} reply records...")

            for i in tqdm(range(0, len(replies_data_tuples), batch_size), desc="Reply Batch Insert"):
                batch = replies_data_tuples[i:i+batch_size]
                inserted_reply_rows = execute_values(cursor, insert_query_replies, batch, fetch=True, page_size=batch_size)
                for row in inserted_reply_rows:
                    reply_id = row['id']
                    author_id_reply = row['user_id']
                    reply_created_at = row['created_at']
                    parent_reply_id_val = row['parent_reply_id'] # Get this from the RETURNING clause

                    generated_reply_ids_map[reply_id] = {'author_id': author_id_reply, 'created_at': reply_created_at}

                    # If this reply is a top-level reply (no parent_reply_id), add it as a candidate for sub-replies
                    # This assumes we are still within the loop for a specific post_id
                    if parent_reply_id_val is None:
                        parent_reply_candidates_for_this_post.append((reply_id, reply_created_at))

                    # Media attachment logic (remains the same)
                    if minio_client_ref and random.random() < MEDIA_ATTACH_PROBABILITY / 2:
                        media_info_reply = upload_placeholder_to_minio(
                            author_id_reply, "replies", reply_id, "reply_img",
                            random.choice(PLACEHOLDER_TEXT_TYPES), size=(random.randint(300,600),random.randint(200,400))
                        )
                        if media_info_reply:
                            media_items_reply_data.append(tuple(media_info_reply.values()) + (reply_id,))
            conn.commit()
            print(f"✅ Inserted {len(generated_reply_ids_map)} replies.")

            if media_items_reply_data:
                media_cols_reply_def = "(uploader_user_id, minio_object_name, mime_type, file_size_bytes, original_filename, width, height, duration_seconds)"
                insert_media_query_reply = f"INSERT INTO media_items {media_cols_reply_def} VALUES %s RETURNING id;"
                media_insert_tuples_for_replies = [(d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7]) for d in media_items_reply_data]
                original_reply_ids_for_media_linking = [d[8] for d in media_items_reply_data]

                current_media_item_idx_reply = 0
                for i in tqdm(range(0, len(media_insert_tuples_for_replies), batch_size), desc="Media Items for Replies"):
                    batch_media_tuples_reply = media_insert_tuples_for_replies[i:i+batch_size]
                    inserted_media_ids_only_reply = execute_values(cursor, insert_media_query_reply, batch_media_tuples_reply, fetch=True, page_size=batch_size)
                    for row_media_id_reply in inserted_media_ids_only_reply:
                        reply_id_to_link = original_reply_ids_for_media_linking[current_media_item_idx_reply]
                        reply_media_links_data.append((reply_id_to_link, row_media_id_reply['id'], 0))
                        current_media_item_idx_reply +=1
                conn.commit()

                if reply_media_links_data:
                    insert_reply_media_link_query = "INSERT INTO reply_media (reply_id, media_id, display_order) VALUES %s ON CONFLICT DO NOTHING;"
                    execute_values(cursor, insert_reply_media_link_query, reply_media_links_data, page_size=batch_size)
                    conn.commit()
                    print(f"✅ {len(reply_media_links_data)} Reply media items linked.")
        else:
            print("ℹ️ No posts available to generate replies for.")


        # 8. Chat Messages
        print(f"\nGenerating {NUM_CHAT_MESSAGES} chat messages...")
        chat_messages_data = []
        all_comm_event_ids_chat = list(generated_community_ids_map.keys()) + generated_event_ids
        if not all_comm_event_ids_chat or not generated_user_ids_map:
            print("ℹ️ Cannot generate chat messages: missing communities, events, or users.")
        else:
            for _ in tqdm(range(NUM_CHAT_MESSAGES), desc="Generating Chat Msgs"):
                target_id_chat = random.choice(all_comm_event_ids_chat)
                is_comm_chat = target_id_chat in generated_community_ids_map
                comm_id_chat = target_id_chat if is_comm_chat else None
                event_id_chat = target_id_chat if not is_comm_chat else None

                user_pool_chat = list(community_members_map.get(target_id_chat, [])) if is_comm_chat else list(event_participants_map.get(target_id_chat, []))
                user_id_chat_msg = random.choice(user_pool_chat) if user_pool_chat else random.choice(user_id_list_for_posts) # Fallback to any user

                chat_messages_data.append((
                    comm_id_chat, event_id_chat, user_id_chat_msg,
                    random.choice(CHAT_LINES),
                    fake.date_time_between(start_date="-30d", end_date="now", tzinfo=timezone.utc)
                ))
        if chat_messages_data:
            insert_query_chat = """INSERT INTO chat_messages (community_id, event_id, user_id, content, "timestamp") VALUES %s;"""
            execute_values(cursor, insert_query_chat, chat_messages_data, page_size=batch_size*5)
            conn.commit()
            print(f"✅ Inserted {len(chat_messages_data)} chat messages.")


        # 9. Votes
        print(f"\nGenerating votes...")
        votes_data = []
        all_post_ids_for_votes = list(generated_post_ids_map.keys())
        all_reply_ids_for_votes = list(generated_reply_ids_map.keys())

        if (all_post_ids_for_votes or all_reply_ids_for_votes) and user_id_list_for_posts:
            # Calculate total possible votable items
            num_votable_items = len(all_post_ids_for_votes) + len(all_reply_ids_for_votes)
            num_votes_to_gen = int(num_votable_items * len(user_id_list_for_posts) * 0.15) # 15% of possible votes

            for _ in tqdm(range(num_votes_to_gen), desc="Generating Votes"):
                user_id_vote = random.choice(user_id_list_for_posts)
                vote_on_post = random.random() < 0.7 # 70% chance to vote on post, 30% on reply

                target_content_id_vote = None
                if vote_on_post and all_post_ids_for_votes:
                    target_content_id_vote = random.choice(all_post_ids_for_votes)
                elif not vote_on_post and all_reply_ids_for_votes:
                    target_content_id_vote = random.choice(all_reply_ids_for_votes)
                elif all_post_ids_for_votes: # Fallback if replies are empty
                    target_content_id_vote = random.choice(all_post_ids_for_votes)
                elif all_reply_ids_for_votes: # Fallback if posts are empty
                    target_content_id_vote = random.choice(all_reply_ids_for_votes)

                if target_content_id_vote is None: continue

                is_post_vote = target_content_id_vote in generated_post_ids_map
                vote_post_id = target_content_id_vote if is_post_vote else None
                vote_reply_id = target_content_id_vote if not is_post_vote else None
                vote_type = random.choice([True, False])
                created_at_vote = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
                votes_data.append((user_id_vote, vote_post_id, vote_reply_id, vote_type, created_at_vote))

        if votes_data:
            # Filter out duplicates (user, post_id) and (user, reply_id) before insert if ON CONFLICT is not robust enough
            unique_votes_set = set()
            unique_votes_data = []
            for v_tuple in votes_data:
                key = (v_tuple[0], v_tuple[1]) if v_tuple[1] is not None else (v_tuple[0], v_tuple[2]) # (user, post_id) or (user, reply_id)
                if key not in unique_votes_set:
                    unique_votes_set.add(key)
                    unique_votes_data.append(v_tuple)

            insert_query_votes = "INSERT INTO votes (user_id, post_id, reply_id, vote_type, created_at) VALUES %s ON CONFLICT DO NOTHING;"
            execute_values(cursor, insert_query_votes, unique_votes_data, page_size=batch_size*2)
            conn.commit(); print(f"✅ Inserted {len(unique_votes_data)} unique votes.")

        # 10. Favorites
        print(f"\nGenerating favorites...")
        post_favorites_data = []
        reply_favorites_data = []
        if (all_post_ids_for_votes or all_reply_ids_for_votes) and user_id_list_for_posts:
            num_favs_to_gen = int((len(all_post_ids_for_votes) + len(all_reply_ids_for_votes)) * len(user_id_list_for_posts) * 0.08) # 8% chance

            for _ in tqdm(range(num_favs_to_gen), desc="Generating Favorites Data"):
                user_id_fav = random.choice(user_id_list_for_posts)
                fav_on_post = random.random() < 0.7
                target_content_id_fav = None

                if fav_on_post and all_post_ids_for_votes:
                    target_content_id_fav = random.choice(all_post_ids_for_votes)
                elif not fav_on_post and all_reply_ids_for_votes:
                    target_content_id_fav = random.choice(all_reply_ids_for_votes)
                elif all_post_ids_for_votes: target_content_id_fav = random.choice(all_post_ids_for_votes)
                elif all_reply_ids_for_votes: target_content_id_fav = random.choice(all_reply_ids_for_votes)

                if target_content_id_fav is None: continue

                favorited_at_fav = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
                if target_content_id_fav in generated_post_ids_map:
                    post_favorites_data.append((user_id_fav, target_content_id_fav, favorited_at_fav))
                elif target_content_id_fav in generated_reply_ids_map:
                    reply_favorites_data.append((user_id_fav, target_content_id_fav, favorited_at_fav))

        if post_favorites_data:
            insert_query_post_fav = "INSERT INTO post_favorites (user_id, post_id, favorited_at) VALUES %s ON CONFLICT DO NOTHING;"
            execute_values(cursor, insert_query_post_fav, post_favorites_data, page_size=batch_size)
            conn.commit(); print(f"✅ Inserted {len(post_favorites_data)} post favorites.")
        if reply_favorites_data:
            insert_query_reply_fav = "INSERT INTO reply_favorites (user_id, reply_id, favorited_at) VALUES %s ON CONFLICT DO NOTHING;"
            execute_values(cursor, insert_query_reply_fav, reply_favorites_data, page_size=batch_size)
            conn.commit(); print(f"✅ Inserted {len(reply_favorites_data)} reply favorites.")


        # 11. User Followers
        print(f"\nGenerating user followers...")
        followers_data = []
        if len(user_id_list_for_posts) > 1:
            num_follows_to_gen = int(NUM_USERS * random.uniform(1.5, max(2.0, NUM_USERS * 0.05))) # Each user follows a few, up to 5% of users
            for _ in tqdm(range(num_follows_to_gen), desc="Generating Follows"):
                follower_id, following_id = random.sample(user_id_list_for_posts, 2) # Ensure different
                followed_at_follow = fake.date_time_between(start_date="-2y", end_date="now", tzinfo=timezone.utc)
                followers_data.append((follower_id, following_id, followed_at_follow))
        if followers_data:
            insert_query_followers = "INSERT INTO user_followers (follower_id, following_id, created_at) VALUES %s ON CONFLICT DO NOTHING;"
            execute_values(cursor, insert_query_followers, followers_data, page_size=batch_size*2)
            conn.commit(); print(f"✅ Inserted {len(followers_data)} follow relationships.")

        # 12. Link Posts to Communities
        print(f"\nLinking posts to communities...")
        community_posts_data = []
        if generated_post_ids_map and generated_community_ids_map:
            for post_id, post_info_val in tqdm(generated_post_ids_map.items(), desc="Linking Posts to Comms"):
                author_id_post = post_info_val['author_id']
                author_joined_comms = [cid for cid, members in community_members_map.items() if author_id_post in members]
                target_comm_id_link = None
                if author_joined_comms and random.random() < 0.8: # 80% chance to post in joined comm
                    target_comm_id_link = random.choice(author_joined_comms)
                elif random.random() < 0.4: # 40% of remaining to post in a random community
                    target_comm_id_link = random.choice(list(generated_community_ids_map.keys()))

                if target_comm_id_link:
                    added_at_cp_link = fake.date_time_between(start_date=post_info_val['created_at'], end_date="now", tzinfo=timezone.utc)
                    community_posts_data.append((target_comm_id_link, post_id, added_at_cp_link))

        if community_posts_data:
            insert_query_comm_posts = "INSERT INTO community_posts (community_id, post_id, added_at) VALUES %s ON CONFLICT DO NOTHING;"
            execute_values(cursor, insert_query_comm_posts, community_posts_data, page_size=batch_size)
            conn.commit(); print(f"✅ Linked {len(community_posts_data)} posts to communities.")

        print("\n--- Mock Data Generation Finished Successfully! ---")

    except (Exception, psycopg2.Error) as error:
        print(f"\n❌ An error occurred during mock data generation: {error}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        if conn: conn.rollback(); print("DB transaction rolled back.")
    finally:
        if conn: cursor.close(); conn.close(); print("Database connection closed.")

if __name__ == "__main__":
    main()