# backend/scripts/migrate_to_age.py

import psycopg2
import psycopg2.extras
import os
import json
from datetime import date, datetime
from dotenv import load_dotenv

# --- Custom JSON Serializer ---
def json_serial(obj):
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError (f"Type {type(obj)} not serializable")

# --- Load .env ---
dotenv_path = os.path.join(os.path.dirname(__file__), '../.env')
load_dotenv(dotenv_path=dotenv_path)

# --- Hardcoded DB Details ---
DB_NAME = "fiore"
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = 5434

GRAPH_NAME = 'fiore'

# --- Helper to safely quote strings ---
def quote_cypher_string(value):
    if value is None: return 'null'
    if isinstance(value, (datetime, date)): return f"'{value.isoformat()}'"
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int, float)): return str(value)
    str_val = str(value).replace("'", "''")
    return f"'{str_val}'"

# --- Helper to build SET clauses ---
def build_cypher_set_clauses(variable, props_dict):
    items = []
    for key, value in props_dict.items():
        if key != 'id' and value is not None:
            prop_key = key
            prop_value = quote_cypher_string(value)
            items.append(f"{variable}.{prop_key} = {prop_value}")
    return ", ".join(items) if items else None

# --- Helper to execute Cypher query ---
def execute_cypher_query(cursor, graph_name, cypher_query):
    sql = f"SELECT * FROM ag_catalog.cypher('{graph_name}', $${cypher_query}$$) as (result agtype);"
    # print(f"DEBUG SQL: {sql.strip()}")
    cursor.execute(sql)

def run_migration():
    conn = None
    cursor = None
    print(f"Attempting to connect to DB: {DB_NAME} on {DB_HOST}:{DB_PORT} as user {DB_USER}")
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME, user=DB_USER, password=DB_PASSWORD,
            host=DB_HOST, port=DB_PORT,
            cursor_factory=psycopg2.extras.RealDictCursor # Use RealDictCursor
        )
        conn.autocommit = False
        cursor = conn.cursor()
        print("Connected.")

        # --- Steps 0, 1, 3, 4 (Keep successful code from previous version) ---
        print("Setting up AGE...")
        cursor.execute("LOAD 'age';")
        cursor.execute("SET search_path = ag_catalog, '$user', public;")
        print("AGE loaded and search path set.")

        try:
            cursor.execute(f"SELECT ag_catalog.create_graph('{GRAPH_NAME}');")
            print(f"Graph '{GRAPH_NAME}' created or already exists.")
            conn.commit()
        except psycopg2.Error as e:
            if e.pgcode == '42710':
                print(f"Graph '{GRAPH_NAME}' already exists.")
                conn.rollback()
            else:
                print(f"Graph Creation Error: {e} (Code: {e.pgcode})")
                conn.rollback(); raise

        print("\nPopulating Vertices...")
        entity_types = [
            ('User', "SELECT id, username, name, image_path FROM public.users"),
            ('Community', "SELECT id, name, interest FROM public.communities"),
            ('Post', "SELECT id, title, created_at FROM public.posts"),
            ('Reply', "SELECT id, created_at FROM public.replies"),
            ('Event', "SELECT id, title, event_timestamp FROM public.events"),
        ]
        for label, select_sql in entity_types:
            print(f"\nProcessing {label} vertices...")
            cursor.execute(select_sql)
            items = cursor.fetchall()
            vertex_count, skipped_count = 0, 0
            if not items: print(f"No items found for {label}."); continue
            for item in items:
                item_id = item['id']
                props_for_set = {k: v for k, v in item.items() if k != 'id'}
                set_clauses_str = build_cypher_set_clauses(label[0].lower(), props_for_set)
                cypher_q = f"MERGE ({label[0].lower()}:{label} {{id: {item_id}}})"
                if set_clauses_str: cypher_q += f" SET {set_clauses_str}"
                try:
                    execute_cypher_query(cursor, GRAPH_NAME, cypher_q)
                    vertex_count += 1
                except psycopg2.Error as e:
                    print(f"Error vertex {label} {item_id}: {e} (Code: {e.pgcode})")
                    conn.rollback(); skipped_count += 1; continue
            print(f"Processed {vertex_count} {label} vertices (skipped {skipped_count}).")
            conn.commit()

        print("\nCreating Indexes...")
        index_definitions = [
            ('User', 'id', 'user_id_graph_idx'), ('Community', 'id', 'community_id_graph_idx'),
            ('Post', 'id', 'post_id_graph_idx'), ('Reply', 'id', 'reply_id_graph_idx'),
            ('Event', 'id', 'event_id_graph_idx')
        ]
        for label, prop, idx_name in index_definitions:
            cursor.execute("SELECT 1 FROM pg_indexes WHERE indexname = %s AND schemaname = %s;", (idx_name, GRAPH_NAME))
            if cursor.fetchone() is None:
                sql = f"""CREATE INDEX {idx_name} ON {GRAPH_NAME}."{label}" ( ((properties ->> '{prop}')::bigint) );"""
                print(f"Attempting Index Create: {idx_name}")
                try:
                    cursor.execute(sql)
                    print(f"Index '{idx_name}' created for {label}.{prop}.")
                    conn.commit()
                except psycopg2.Error as e:
                    print(f"Error creating index {idx_name}: {e} (Code: {e.pgcode})")
                    if e.pgcode == '42P01': print(f"  -> Table '{GRAPH_NAME}.\"{label}\"' not found. VERTEX CREATION LIKELY FAILED.")
                    conn.rollback()
            else:
                print(f"Index '{idx_name}' already exists.")


        # ============================================================
        # Step 5: Migrate Edges (Corrected Property Access)
        # ============================================================
        print("\nMigrating Edges...")
        # Define edge migrations using column NAMES, not indices
        edge_migrations = [
            # Relation, SQL Source, Cypher Pattern (using %s placeholders), Properties map {cypher_prop: sql_col_name}
            ('FOLLOWS',
             "SELECT follower_id, following_id, created_at FROM public.user_followers",
             "MATCH (f:User {id: %s}) MATCH (t:User {id: %s}) MERGE (f)-[r:FOLLOWS]->(t)",
             {'created_at': 'created_at'},
             ['follower_id', 'following_id']), # IDs for pattern formatting
            ('MEMBER_OF',
             "SELECT user_id, community_id, joined_at FROM public.community_members",
             "MATCH (u:User {id: %s}) MATCH (c:Community {id: %s}) MERGE (u)-[r:MEMBER_OF]->(c)",
             {'joined_at': 'joined_at'},
             ['user_id', 'community_id']),
            ('WROTE', # User Wrote Post
             "SELECT user_id, id, created_at FROM public.posts",
             "MATCH (u:User {id: %s}) MATCH (p:Post {id: %s}) MERGE (u)-[r:WROTE]->(p)",
             {'created_at': 'created_at'},
             ['user_id', 'id']),
            ('HAS_POST', # Community Has Post
             "SELECT community_id, post_id, added_at FROM public.community_posts",
             "MATCH (c:Community {id: %s}) MATCH (p:Post {id: %s}) MERGE (c)-[r:HAS_POST]->(p)",
             {'added_at': 'added_at'},
             ['community_id', 'post_id']),
            ('PARTICIPATED_IN',
             "SELECT user_id, event_id, joined_at FROM public.event_participants",
             "MATCH (u:User {id: %s}) MATCH (e:Event {id: %s}) MERGE (u)-[r:PARTICIPATED_IN]->(e)",
             {'joined_at': 'joined_at'},
             ['user_id', 'event_id']),
            ('VOTED', # Post Votes
             "SELECT user_id, post_id, vote_type, created_at FROM public.votes WHERE post_id IS NOT NULL",
             "MATCH (u:User {id: %s}) MATCH (p:Post {id: %s}) MERGE (u)-[r:VOTED]->(p)",
             {'vote_type': 'vote_type', 'created_at': 'created_at'},
             ['user_id', 'post_id']),
            ('VOTED', # Reply Votes
             "SELECT user_id, reply_id, vote_type, created_at FROM public.votes WHERE reply_id IS NOT NULL",
             "MATCH (u:User {id: %s}) MATCH (rep:Reply {id: %s}) MERGE (u)-[r:VOTED]->(rep)",
             {'vote_type': 'vote_type', 'created_at': 'created_at'},
             ['user_id', 'reply_id']),
            ('FAVORITED', # Post Favorites
             "SELECT user_id, post_id, favorited_at FROM public.post_favorites",
             "MATCH (u:User {id: %s}) MATCH (p:Post {id: %s}) MERGE (u)-[r:FAVORITED]->(p)",
             {'favorited_at': 'favorited_at'},
             ['user_id', 'post_id']),
            ('FAVORITED', # Reply Favorites
             "SELECT user_id, reply_id, favorited_at FROM public.reply_favorites",
             "MATCH (u:User {id: %s}) MATCH (rep:Reply {id: %s}) MERGE (u)-[r:FAVORITED]->(rep)",
             {'favorited_at': 'favorited_at'},
             ['user_id', 'reply_id']),
            ('WROTE', # User Wrote Reply
             "SELECT user_id, id, created_at FROM public.replies",
             "MATCH (u:User {id: %s}) MATCH (rep:Reply {id: %s}) MERGE (u)-[r:WROTE]->(rep)",
             {'created_at': 'created_at'},
             ['user_id', 'id']),
            ('REPLIED_TO', # Reply to Post
             "SELECT id, post_id, created_at FROM public.replies WHERE parent_reply_id IS NULL",
             "MATCH (rep:Reply {id: %s}) MATCH (p:Post {id: %s}) MERGE (rep)-[r:REPLIED_TO]->(p)",
             {'created_at': 'created_at'},
             ['id', 'post_id']),
            ('REPLIED_TO', # Reply to Reply
             "SELECT id, parent_reply_id, created_at FROM public.replies WHERE parent_reply_id IS NOT NULL",
             "MATCH (child:Reply {id: %s}) MATCH (parent:Reply {id: %s}) MERGE (child)-[r:REPLIED_TO]->(parent)",
             {'created_at': 'created_at'},
             ['id', 'parent_reply_id']),
            ('CREATED', # User Created Community
             "SELECT created_by, id, created_at FROM public.communities",
             "MATCH (u:User {id: %s}) MATCH (c:Community {id: %s}) MERGE (u)-[r:CREATED]->(c)",
             {'created_at': 'created_at'},
             ['created_by', 'id']),
            ('CREATED', # User Created Event
             "SELECT creator_id, id, created_at FROM public.events",
             "MATCH (u:User {id: %s}) MATCH (e:Event {id: %s}) MERGE (u)-[r:CREATED]->(e)",
             {'created_at': 'created_at'},
             ['creator_id', 'id']),
        ]

        for label, select_sql, cypher_pattern_base, properties_map, id_column_names in edge_migrations:
            print(f"\nProcessing {label} edges...")
            cursor.execute(select_sql)
            rows = cursor.fetchall() # Fetch all rows as dictionaries
            edge_count, skipped_count = 0, 0
            if not rows: print(f"No rows found in source table for {label} edges."); continue

            for row_dict in rows:
                # Extract primary IDs using the specified column names
                try:
                    id1 = row_dict[id_column_names[0]]
                    id2 = row_dict[id_column_names[1]]
                except KeyError as e:
                    print(f"  -> Skipping row due to missing ID key: {e}. Row: {row_dict}")
                    skipped_count += 1
                    continue
                except IndexError:
                    print(f"  -> Skipping row due to missing ID column name definition. Row: {row_dict}")
                    skipped_count += 1
                    continue

                # Build SET clauses string using column names from properties_map
                set_clauses = []
                for prop_name, col_name in properties_map.items():
                    prop_value = row_dict.get(col_name) # Use get for safety
                    set_clauses.append(f"r.{prop_name} = {quote_cypher_string(prop_value)}")
                set_clause_str = f"SET {', '.join(set_clauses)}" if set_clauses else ""

                # Format the base pattern with the actual IDs using %s placeholders
                cypher_concrete_pattern = cypher_pattern_base % (id1, id2)

                # Combine pattern and SET clause
                cypher_q = f"{cypher_concrete_pattern} {set_clause_str}"

                try:
                    # print(f"DEBUG Cypher Edge: {cypher_q}") # Uncomment to verify
                    execute_cypher_query(cursor, GRAPH_NAME, cypher_q)
                    edge_count += 1
                except psycopg2.Error as e:
                    print(f"Error edge {label} (IDs: {id1}, {id2}): {e} (Code: {e.pgcode})")
                    conn.rollback(); skipped_count += 1; continue
                except Exception as e:
                    print(f"Error processing edge {label} (IDs: {id1}, {id2}): {e}")
                    conn.rollback(); skipped_count += 1; continue

            print(f"Processed {edge_count} {label} edges (skipped {skipped_count}).")
            conn.commit() # Commit after each edge type

        print("\nMigration Script Finished Successfully.")

    # ... (Keep existing final error handling and connection closing) ...
    except (Exception, psycopg2.Error) as error:
        print(f"\n--- MIGRATION FAILED ---")
        print(f"Error Type: {type(error).__name__}")
        print(f"Error Details: {error}")
        if hasattr(error, 'pgcode') and error.pgcode: print(f"PG Code: {error.pgcode}")
        import traceback
        traceback.print_exc()
        if conn: conn.rollback(); print("Transaction rolled back.")
    finally:
        if cursor: cursor.close()
        if conn: conn.close(); print("Database connection closed.")

if __name__ == "__main__":
    run_migration()