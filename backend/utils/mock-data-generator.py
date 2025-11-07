# backend/generate_mock_data.py

import os
import io
import random
import uuid
import bcrypt
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv
from faker import Faker
from minio import Minio
from minio.error import S3Error
from PIL import Image, ImageDraw, ImageFont
from datetime import datetime, timedelta, timezone
from tqdm import tqdm
import math
import asyncio
import re # For sanitizing filenames
import sys # For nohup output handling

# --- Configuration ---
load_dotenv()
fake = Faker()

NUM_USERS = 500
NUM_COMMUNITIES = 100
NUM_EVENTS_APPROX_PER_COMMUNITY = 3
NUM_CHAT_MESSAGES = 1200

# --- Database Configuration ---
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME")
DB_PORT = os.getenv("DB_PORT", 5432)

# --- MinIO Configuration ---
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "connections-media")
MINIO_USE_SSL = os.getenv("MINIO_USE_SSL", "False").lower() == "true"

# --- Mock Data Lists ---
GENDERS = ['Male', 'Female', 'Others']
COLLEGES = ['VIT Vellore', 'MIT Manipal', 'SRM Chennai', 'IIT Delhi', 'BITS Pilani', 'NSUT', 'DTU', 'IIIT Hyderabad', 'Stanford', 'Harvard', 'UC Berkeley', 'Cambridge', 'Oxford', 'Community College', 'Online University']

# *** CORRECTED INTERESTS LIST TO MATCH DB CONSTRAINT ***
INTERESTS = ['Gaming', 'Tech', 'Science', 'Music', 'Sports', 'College Event', 'Activities', 'Social', 'Other']
# Note: We use this corrected list for BOTH user interests and community interests generation.

COMMUNITY_ADJECTIVES = ['Awesome', 'Creative', 'Digital', 'Global', 'Innovative', 'Local', 'Virtual', 'Dynamic', 'Future', 'United', 'Open', 'Collaborative', 'Sustainable', 'Academic', 'Research']
COMMUNITY_NOUNS = ['Network', 'Hub', 'Collective', 'Space', 'Zone', 'Society', 'Crew', 'Labs', 'Circle', 'Forum', 'Initiative', 'Group', 'Project', 'Association', 'Guild']
EVENT_TYPES = ['Meetup', 'Workshop', 'Conference', 'Hackathon', 'Talk', 'Social', 'Competition', 'Webinar', 'Party', 'Game Night', 'Study Session', 'AMA', 'Panel', 'Presentation', 'Demo Day']
LOCATIONS = ['Online', 'Campus Green', 'Library Cafe', 'Room 404', 'Discord Server', 'Zoom', 'Local Park', 'Tech Hub Auditorium', 'City Center Plaza', 'Rooftop Bar', 'VR Space', 'Co-working Space', 'University Hall']
CHAT_LINES = [
    'Hello everyone!', 'Anyone free later?', 'What did you think of the last event?',
    'Looking forward to the next session.', 'Can someone share the link?', 'Great point!',
    'I agree.', 'That sounds interesting.', 'Maybe we can collaborate?', 'Any updates?',
    'See you there!', 'Thanks for sharing!', 'What time does it start?', 'Let me know if you need help.',
    'Working on a cool project right now.', 'Just checking in.', 'How is everyone doing?',
    'That was fun!', 'Learned a lot today.', 'Let’s brainstorm some ideas.'
]

# Hashed password for 'password'
DEFAULT_PASSWORD_HASH = bcrypt.hashpw(b'password', bcrypt.gensalt()).decode('utf-8')

# --- Helper Functions ---

def get_db_connection():
    """Establishes a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            host=DB_HOST,
            port=DB_PORT,
            client_encoding='UTF8'
        )
        return conn
    except psycopg2.OperationalError as e:
        print(f"❌ Database connection failed: {e}")
        print("Ensure PostgreSQL is running and credentials in .env are correct.")
        exit(1)

def get_minio_client():
    """Initializes and returns a MinIO client if configured."""
    if not all([MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY]):
        print("⚠️ MinIO environment variables not fully set. Image upload disabled.")
        return None
    try:
        # Clean the endpoint: remove http(s):// and any trailing paths
        cleaned_endpoint = MINIO_ENDPOINT.replace("http://", "").replace("https://", "").rstrip('/')
        # Split host and port if port is present
        if ':' in cleaned_endpoint:
            host, port = cleaned_endpoint.split(':')
            # Minio client expects endpoint as host:port, but if port is default (80/443) it might be omitted
            # For local Minio, it's usually host:port
            endpoint_to_use = f"{host}:{port}"
        else:
            endpoint_to_use = cleaned_endpoint

        client = Minio(
            endpoint_to_use,
            access_key=MINIO_ACCESS_KEY,
            secret_key=MINIO_SECRET_KEY,
            secure=MINIO_USE_SSL
        )
        # Check connection
        client.list_buckets()
        print(f"✅ Connected to MinIO at {MINIO_ENDPOINT}")

        # Ensure bucket exists
        found = client.bucket_exists(MINIO_BUCKET)
        if not found:
            client.make_bucket(MINIO_BUCKET)
            print(f"✅ MinIO Bucket '{MINIO_BUCKET}' created.")
        else:
            print(f"✅ MinIO Bucket '{MINIO_BUCKET}' already exists.")
        return client
    except Exception as e:
        print(f"❌ Failed to initialize MinIO client or bucket: {e}")
        print("Check MinIO endpoint, credentials, and bucket name in .env.")
        return None

def generate_placeholder_image(text="?", size=(100, 100), bg_color=None) -> bytes:
    """Generates a simple PNG image with text."""
    img = Image.new('RGB', size, color=bg_color or (random.randint(100, 200), random.randint(100, 200), random.randint(100, 200)))
    d = ImageDraw.Draw(img)
    try:
        # Attempt to load a common font, fallback if not found
        try:
            font = ImageFont.truetype("arial.ttf", size[1] // 3)
        except IOError:
            font = ImageFont.load_default()
    except Exception:
        font = ImageFont.load_default()

    try:
        # Use textbbox for more accurate positioning if available (Pillow >= 8.0.0)
        text_bbox = d.textbbox((0, 0), text, font=font)
        text_width = text_bbox[2] - text_bbox[0]
        text_height = text_bbox[3] - text_bbox[1]
        position = ((size[0] - text_width) / 2, (size[1] - text_height) / 2 - size[1] // 10) # Adjust vertical position
    except AttributeError: # Fallback for older Pillow versions
         text_width, text_height = d.textsize(text, font=font)
         position = ((size[0] - text_width) / 2, (size[1] - text_height) / 2)

    d.text(position, text, fill=(255, 255, 255), font=font)

    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='PNG')
    return img_byte_arr.getvalue()

# Make upload_to_minio synchronous for easier integration without async/await in main loop if preferred
# Alternatively, keep it async and use asyncio.run() as before. Let's make it sync for simplicity here.
def upload_to_minio_sync(minio_client: Minio, data: bytes, object_name: str, content_type='image/png') -> bool:
    """Uploads bytes data to MinIO (Synchronous Version)."""
    if not minio_client:
        return False
    try:
        minio_client.put_object(
            MINIO_BUCKET,
            object_name,
            io.BytesIO(data),
            length=len(data),
            content_type=content_type
        )
        return True
    except S3Error as e:
        print(f"❌ MinIO Upload Error for {object_name}: {e}", file=sys.stderr) # Print errors to stderr
        return False
    except Exception as e:
        print(f"❌ General Error during MinIO upload for {object_name}: {e}", file=sys.stderr)
        return False

def sanitize_for_path(name: str) -> str:
    """Removes or replaces characters unsuitable for path components."""
    name = name.strip()
    name = re.sub(r'[\\/:*?"<>|\s]+', '_', name)
    name = re.sub(r'[^\w_.-]+', '', name) # Allow ., _ and - in addition to alphanum
    return name[:50]


# --- Main Data Generation Logic ---
def main(): # Changed main to synchronous
    """Main function to orchestrate mock data generation."""
    conn = get_db_connection()
    cursor = conn.cursor()
    minio_client = get_minio_client()

    generated_user_ids = []
    generated_community_ids = []
    generated_event_ids = []
    user_interests = {}
    community_interests = {}
    community_members_map = {}
    event_participants_map = {}
    user_profile_pictures_to_process = [] # New list to store profile picture data for later processing
    community_logos_to_process = [] # New list to store community logo data for later processing
    batch_size = 5000 # Adjust batch size based on memory/performance

    try:
        print("--- Starting Mock Data Generation ---")

        # 1. Generate Users
        print(f"\nGenerating {NUM_USERS} users...")
        users_data = []
        generated_usernames = set()

        with tqdm(total=NUM_USERS, desc="Generating Users", unit="user") as pbar:
            i = 0
            while i < NUM_USERS:
                first_name = fake.first_name()
                last_name = fake.last_name()
                base_username = f"{first_name.lower()}{last_name.lower()}{random.randint(10, 99)}"
                username_counter = 0
                username = base_username
                while username in generated_usernames:
                    username_counter += 1
                    username = f"{base_username}{username_counter}"
                generated_usernames.add(username)

                email = f"{username}@{fake.domain_name()}"
                name = f"{first_name} {last_name}"
                gender = random.choice(GENDERS)
                college = random.choice(COLLEGES)
                interest = random.choice(INTERESTS) # Uses corrected list
                location_str = f"({fake.longitude()},{fake.latitude()})"
                created_at = fake.date_time_between(start_date="-2y", end_date="now", tzinfo=timezone.utc)
                last_seen = fake.date_time_between(start_date="-7d", end_date="now", tzinfo=timezone.utc)

                profile_image_data = None
                if minio_client:
                    placeholder = generate_placeholder_image(f"{first_name[0]}{last_name[0]}", size=(200, 200))
                    object_name = f"users/{username}/profile/{uuid.uuid4()}.png"
                    # Store the data and object_name for later upload and DB insertion
                    profile_image_data = {"data": placeholder, "object_name": object_name, "username": username}

                users_data.append((
                    name, username, gender, email, DEFAULT_PASSWORD_HASH,
                    location_str, created_at, interest, college, last_seen
                ))
                if profile_image_data: # Store for later processing
                    user_profile_pictures_to_process.append(profile_image_data)
                pbar.update(1)
                i += 1

        insert_query_users = """
            INSERT INTO users (name, username, gender, email, password_hash, location, created_at, interest, college, last_seen)
            VALUES %s RETURNING id, interest;
        """
        # Modify users_data to format location as PostGIS Point
        users_data_formatted = []
        for user in users_data:
            name, username, gender, email, password_hash, location_str, created_at, interest, college, last_seen = user
            # Extract longitude and latitude from the string "(longitude,latitude)"
            lon, lat = map(float, location_str.strip('()').split(','))
            # Format for PostGIS
            postgis_location = f"SRID=4326;POINT({lon} {lat})"
            users_data_formatted.append((name, username, gender, email, password_hash, postgis_location, created_at, interest, college, last_seen))

        try:
            print(f"  Inserting {len(users_data_formatted)} user records...")
            inserted_users = execute_values(cursor, insert_query_users, users_data_formatted, fetch=True)
            conn.commit()
            generated_user_ids = [u[0] for u in inserted_users]
            user_interests = {u[0]: u[1] for u in inserted_users}
            print(f"✅ Inserted {len(generated_user_ids)} users.")

            # Process User Profile Pictures
            if minio_client and user_profile_pictures_to_process:
                print("\nProcessing user profile pictures...")
                media_items_data = []
                user_profile_picture_data = []

                with tqdm(total=len(user_profile_pictures_to_process), desc="Uploading Profile Pics", unit="pic") as pbar_upload:
                    for i, profile_data in enumerate(user_profile_pictures_to_process):
                        user_id = generated_user_ids[i] # Assuming order is preserved
                        if upload_to_minio_sync(minio_client, profile_data["data"], profile_data["object_name"]):
                            # Insert into media_items
                            cursor.execute("INSERT INTO media_items (uploader_user_id, minio_object_name, mime_type, file_size_bytes) VALUES (%s, %s, %s, %s) RETURNING id",
                                           (user_id, profile_data["object_name"], "image/png", len(profile_data["data"])))
                            media_id = cursor.fetchone()[0]
                            media_items_data.append((user_id, media_id)) # Store for potential future use

                            # Insert into user_profile_picture
                            user_profile_picture_data.append((user_id, media_id))
                        pbar_upload.update(1)
                conn.commit()
                print(f"✅ Processed {len(user_profile_picture_data)} user profile pictures.")
        except (Exception, psycopg2.Error) as error:
            print(f"\n❌ Error during user bulk insert: {error}", file=sys.stderr)
            if conn: conn.rollback()
            print("Exiting due to user insertion error.")
            exit(1)

        # 2. Generate Communities
        print(f"\nGenerating {NUM_COMMUNITIES} communities...")
        communities_data = []
        if not generated_user_ids:
            print("❌ Cannot generate communities without users.", file=sys.stderr)
            return

        with tqdm(total=NUM_COMMUNITIES, desc="Generating Communities", unit="comm") as pbar:
            for i in range(NUM_COMMUNITIES):
                base_name = f"{random.choice(COMMUNITY_ADJECTIVES)} {random.choice(COMMUNITY_NOUNS)} {i}"
                interest = random.choice(INTERESTS) # Uses corrected list
                creator_id = random.choice(generated_user_ids)
                description = f"A community for {interest} enthusiasts. Welcome!"
                location_str = f"({fake.longitude()},{fake.latitude()})"
                created_at = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)

                logo_data = None
                if minio_client:
                    comm_placeholder_initial = base_name[0] if base_name else 'C'
                    placeholder = generate_placeholder_image(comm_placeholder_initial, size=(300, 300), bg_color=(random.randint(50, 150), random.randint(50, 150), random.randint(50, 150)))
                    sanitized_name_for_path = sanitize_for_path(base_name)
                    object_name = f"communities/{sanitized_name_for_path}/logo/{uuid.uuid4()}.png"
                    logo_data = {"data": placeholder, "object_name": object_name, "community_name": base_name}

                communities_data.append((
                    base_name, description, creator_id, created_at,
                    location_str, interest
                ))
                if logo_data: # Store for later processing
                    community_logos_to_process.append(logo_data)
                pbar.update(1)

        insert_query_communities = """
            INSERT INTO communities (name, description, created_by, created_at, location, interest)
            VALUES %s RETURNING id, interest, created_by;
        """
        # Modify communities_data to format location as PostGIS Point
        communities_data_formatted = []
        for community in communities_data:
            name, description, creator_id, created_at, location_str, interest = community
            lon, lat = map(float, location_str.strip('()').split(','))
            postgis_location = f"SRID=4326;POINT({lon} {lat})"
            communities_data_formatted.append((name, description, creator_id, created_at, postgis_location, interest))

        try:
            print(f"  Inserting {len(communities_data_formatted)} community records...")
            inserted_communities = execute_values(cursor, insert_query_communities, communities_data_formatted, fetch=True)
            conn.commit()
            generated_community_ids = [c[0] for c in inserted_communities]
            community_interests = {c[0]: c[1] for c in inserted_communities}
            community_creators = {c[0]: c[2] for c in inserted_communities}
            print(f"✅ Inserted {len(generated_community_ids)} communities.")

            # Process Community Logos
            if minio_client and community_logos_to_process:
                print("\nProcessing community logos...")
                community_logo_insert_data = []

                with tqdm(total=len(community_logos_to_process), desc="Uploading Community Logos", unit="logo") as pbar_upload:
                    for i, logo_data in enumerate(community_logos_to_process):
                        community_id = generated_community_ids[i] # Assuming order is preserved
                        if upload_to_minio_sync(minio_client, logo_data["data"], logo_data["object_name"]):
                            # Insert into media_items
                            cursor.execute("INSERT INTO media_items (uploader_user_id, minio_object_name, mime_type, file_size_bytes) VALUES (%s, %s, %s, %s) RETURNING id",
                                           (community_creators[community_id], logo_data["object_name"], "image/png", len(logo_data["data"])))
                            media_id = cursor.fetchone()[0]

                            # Insert into community_logo
                            community_logo_insert_data.append((community_id, media_id))
                        pbar_upload.update(1)
                conn.commit()
                print(f"✅ Processed {len(community_logo_insert_data)} community logos.")
        except (Exception, psycopg2.Error) as error:
            print(f"\n❌ Error during community bulk insert: {error}", file=sys.stderr)
            if conn: conn.rollback()
            print("Exiting due to community insertion error.")
            exit(1)


        # 3. Generate Community Memberships
        print(f"\nGenerating community memberships...")
        memberships_data = []
        community_members_map = {cid: set() for cid in generated_community_ids}

        for comm_id, creator_id in community_creators.items():
             join_time = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
             memberships_data.append((creator_id, comm_id, join_time))
             community_members_map[comm_id].add(creator_id)

        print("  Calculating potential memberships...")
        total_pairs = len(generated_user_ids) * len(generated_community_ids)
        with tqdm(total=total_pairs, desc="Evaluating Memberships", unit="pair", leave=False) as pbar_eval:
            for user_id in generated_user_ids:
                user_int = user_interests.get(user_id)
                for comm_id in generated_community_ids:
                    pbar_eval.update(1)
                    if user_id in community_members_map[comm_id]:
                        continue

                    comm_int = community_interests.get(comm_id)
                    join_probability = 0.03
                    if user_int and comm_int and user_int == comm_int:
                        join_probability = 0.25

                    if random.random() < join_probability:
                        joined_at = fake.date_time_between(start_date="-1y", end_date="now", tzinfo=timezone.utc)
                        memberships_data.append((user_id, comm_id, joined_at))
                        community_members_map[comm_id].add(user_id)

        if memberships_data:
            print(f"  Inserting {len(memberships_data)} membership records...")
            insert_query_members = """
                INSERT INTO community_members (user_id, community_id, joined_at)
                VALUES %s ON CONFLICT (user_id, community_id) DO NOTHING;
            """
            with tqdm(total=len(memberships_data), desc="Inserting Memberships", unit="rec") as pbar_insert:
                for i in range(0, len(memberships_data), batch_size):
                    batch = memberships_data[i:i + batch_size]
                    execute_values(cursor, insert_query_members, batch)
                    conn.commit()
                    pbar_insert.update(len(batch))
            print(f"✅ Inserted/Updated community memberships.")
        else:
            print("ℹ️ No new community memberships to insert.")

        # 4. Generate Events
        print(f"\nGenerating events...")
        events_data = []
        total_events_generated_count = 0
        event_community_map = {}

        estimated_total_events = len(generated_community_ids) * NUM_EVENTS_APPROX_PER_COMMUNITY
        with tqdm(total=estimated_total_events, desc="Generating Events", unit="event") as pbar:
             for comm_id in generated_community_ids:
                 num_events_for_comm = max(1, math.ceil(random.gauss(NUM_EVENTS_APPROX_PER_COMMUNITY, 1.5)))
                 members = list(community_members_map.get(comm_id, []))
                 creator_fallback = community_creators.get(comm_id)

                 for _ in range(num_events_for_comm):
                     if members:
                         creator_id = random.choice(members)
                     elif creator_fallback:
                         creator_id = creator_fallback
                     else:
                         creator_id = random.choice(generated_user_ids)

                     event_interest = community_interests.get(comm_id, random.choice(INTERESTS))
                     event_type = random.choice(EVENT_TYPES)
                     title = f"{event_interest} {event_type} - {fake.catch_phrase()}"
                     description = fake.paragraph(nb_sentences=random.randint(2, 5))
                     location = random.choice(LOCATIONS)
                     event_timestamp = fake.date_time_between(start_date="-60d", end_date="+90d", tzinfo=timezone.utc)
                     max_participants = random.randint(15, 150)
                     created_at = fake.date_time_between(start_date="-1y", end_date=min(event_timestamp, datetime.now(timezone.utc)), tzinfo=timezone.utc)
                     image_url = None # No event images for now

                     events_data.append((
                         comm_id, creator_id, title, description, location,
                         event_timestamp, max_participants, image_url, created_at
                     ))
                     total_events_generated_count += 1
                     pbar.update(1)
                     if pbar.n > pbar.total: pbar.total = pbar.n # Adjust total if estimate is exceeded

        if events_data:
            insert_query_events = """
                INSERT INTO events (community_id, creator_id, title, description, location, event_timestamp, max_participants, image_url, created_at)
                VALUES %s RETURNING id, community_id, creator_id, created_at;
            """
            print(f"  Inserting {len(events_data)} event records...")
            inserted_events = execute_values(cursor, insert_query_events, events_data, fetch=True)
            conn.commit()
            generated_event_ids = [e[0] for e in inserted_events]
            event_community_map = {e[0]: e[1] for e in inserted_events}
            event_creators = {e[0]: e[2] for e in inserted_events}
            event_creation_times = {e[0]: e[3] for e in inserted_events}
            print(f"✅ Inserted {len(generated_event_ids)} events.")
        else:
            print("ℹ️ No events generated.")

        # 5. Generate Event Participants
        print(f"\nGenerating event participants...")
        participants_data = []
        event_participants_map = {eid: set() for eid in generated_event_ids}

        for event_id, creator_id in event_creators.items():
            if event_id in event_creation_times: # Ensure event exists
                 participants_data.append((event_id, creator_id, event_creation_times[event_id]))
                 event_participants_map[event_id].add(creator_id)

        print("  Calculating potential participants...")
        with tqdm(total=len(generated_event_ids), desc="Evaluating Participants", unit="event") as pbar_eval_part:
            for event_id in generated_event_ids:
                pbar_eval_part.update(1)
                comm_id = event_community_map.get(event_id)
                if not comm_id: continue

                community_members = list(community_members_map.get(comm_id, []))
                if not community_members: continue

                # Fetch max participants only if needed (optimization)
                max_p = None

                for member_id in community_members:
                    if member_id in event_participants_map[event_id]: continue

                    # Check limit only when necessary
                    if max_p is None:
                        cursor.execute("SELECT max_participants FROM events WHERE id = %s", (event_id,))
                        event_details = cursor.fetchone()
                        max_p = event_details[0] if event_details else 100 # Cache it

                    if len(event_participants_map[event_id]) >= max_p:
                        break # Stop adding if event is full

                    if random.random() < 0.20:
                        event_created = event_creation_times.get(event_id, datetime.now(timezone.utc) - timedelta(days=1))
                        join_start = event_created
                        join_end = datetime.now(timezone.utc)
                        if join_start > join_end: join_start = join_end - timedelta(hours=1)
                        try:
                            joined_at = fake.date_time_between(start_date=join_start, end_date=join_end, tzinfo=timezone.utc)
                        except ValueError:
                             joined_at = join_end

                        participants_data.append((event_id, member_id, joined_at))
                        event_participants_map[event_id].add(member_id)

        if participants_data:
            print(f"  Inserting {len(participants_data)} participant records...")
            insert_query_participants = """
                INSERT INTO event_participants (event_id, user_id, joined_at)
                VALUES %s ON CONFLICT (event_id, user_id) DO NOTHING;
            """
            with tqdm(total=len(participants_data), desc="Inserting Participants", unit="rec") as pbar_insert_part:
                 for i in range(0, len(participants_data), batch_size):
                     batch = participants_data[i:i + batch_size]
                     execute_values(cursor, insert_query_participants, batch)
                     conn.commit()
                     pbar_insert_part.update(len(batch))
            print(f"✅ Inserted/Updated event participants.")
        else:
            print("ℹ️ No new event participants to insert.")

        # 6. Generate Chat Messages
        print(f"\nGenerating {NUM_CHAT_MESSAGES} chat messages...")
        chat_messages_data = []
        all_comm_and_event_ids = generated_community_ids + generated_event_ids
        if not all_comm_and_event_ids or not generated_user_ids:
             print("❌ Cannot generate chat messages without communities/events or users.", file=sys.stderr)
        else:
            with tqdm(total=NUM_CHAT_MESSAGES, desc="Generating Chat Messages", unit="msg") as pbar_chat:
                while len(chat_messages_data) < NUM_CHAT_MESSAGES:
                    target_id = random.choice(all_comm_and_event_ids)
                    is_community = target_id in generated_community_ids
                    community_id = target_id if is_community else None
                    event_id = target_id if not is_community else None

                    relevant_user_pool = []
                    if is_community:
                        relevant_user_pool = list(community_members_map.get(target_id, []))
                    else:
                        relevant_user_pool = list(event_participants_map.get(target_id, []))

                    if not relevant_user_pool:
                        user_id = random.choice(generated_user_ids)
                    else:
                        user_id = random.choice(relevant_user_pool)

                    content = random.choice(CHAT_LINES)
                    timestamp = fake.date_time_between(start_date="-30d", end_date="now", tzinfo=timezone.utc)

                    chat_messages_data.append((
                        community_id, event_id, user_id, content, timestamp
                    ))
                    pbar_chat.update(1)

            if chat_messages_data:
                insert_query_chat = """
                    INSERT INTO chat_messages (community_id, event_id, user_id, content, "timestamp")
                    VALUES %s;
                """
                print(f"  Inserting {len(chat_messages_data)} chat messages...")
                with tqdm(total=len(chat_messages_data), desc="Inserting Chat Messages", unit="rec") as pbar_insert_chat:
                    for i in range(0, len(chat_messages_data), batch_size):
                        batch = chat_messages_data[i:i + batch_size]
                        execute_values(cursor, insert_query_chat, batch)
                        conn.commit()
                        pbar_insert_chat.update(len(batch))
                print(f"✅ Inserted {len(chat_messages_data)} chat messages.")
            else:
                 print("ℹ️ No chat messages generated.")


        print("\n--- Mock Data Generation Finished Successfully! ---")

    except (Exception, psycopg2.Error) as error:
        print(f"\n❌ An error occurred during mock data generation: {error}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        if conn:
            conn.rollback()
            print("Database transaction rolled back.")
    finally:
        if conn:
            cursor.close()
            conn.close()
            print("Database connection closed.")

if __name__ == "__main__":
    # Run the synchronous main function
    main()
