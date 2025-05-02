# backend/src/crud/_graph.py
import psycopg2
import psycopg2.extras
from typing import Optional, Dict, Any, List

from .. import utils # Import utils from the parent directory

GRAPH_NAME = 'fiore' # Use the correct graph name

# --- Helper to execute Cypher query ---
def execute_cypher(cursor: psycopg2.extensions.cursor, query: str, fetch_one=False, fetch_all=False):
    """Executes a Cypher query via AGE and optionally fetches results."""
    # Ensure search path includes ag_catalog for the session or rely on prefixing
    # Setting it locally might be safer if connections are reused differently
    cursor.execute("SET LOCAL search_path = ag_catalog, '$user', public;")
    sql = f"SELECT * FROM ag_catalog.cypher('{GRAPH_NAME}', $${query}$$) as (result agtype);"
    try:
        # print(f"DEBUG Cypher SQL: {sql.strip()}") # Uncomment for deep debugging
        cursor.execute(sql)
        if fetch_one:
            row = cursor.fetchone()
            # print(f"DEBUG execute_cypher fetchone raw: {row}")
            # Use utils.parse_agtype to handle potential JSON strings etc.
            return utils.parse_agtype(row['result']) if row else None
        elif fetch_all:
            rows = cursor.fetchall()
            # print(f"DEBUG execute_cypher fetchall raw: {rows}")
            # Parse each result
            return [utils.parse_agtype(row['result']) for row in rows]
        else:
            # Assume success for MERGE/CREATE/DELETE if no exception
            return True
    except psycopg2.Error as db_err:
         print(f"!!! Cypher Execution Error ({db_err.pgcode}): {db_err}")
         print(f"    Query: {query}")
         raise db_err # Re-raise for transaction control
    except Exception as e:
         print(f"!!! Unexpected Error in execute_cypher: {e}")
         print(f"    Query: {query}")
         raise e

# --- Helper to build SET clauses string ---
def build_cypher_set_clauses(variable: str, props_dict: Dict[str, Any]) -> Optional[str]:
    """Builds 'var.prop1 = val1, var.prop2 = val2' string for Cypher SET."""
    items = []
    for key, value in props_dict.items():
         # Skip 'id' as it's used in MERGE match, skip None values
         if key != 'id' and value is not None:
            prop_key = key # Assume keys are safe identifiers
            prop_value = utils.quote_cypher_string(value) # Use quoting helper
            items.append(f"{variable}.{prop_key} = {prop_value}")
    return ", ".join(items) if items else None

# --- Specific Graph Operations can also live here ---
# Example: Get counts (could also be in _user.py or _community.py etc.)

def get_graph_counts(cursor: psycopg2.extensions.cursor, node_label: str, node_id: int, count_specs: List[Dict[str, str]]) -> Dict[str, int]:
    """
    Fetches multiple counts related to a node in a single query.
    count_specs: List of dicts like {'name': 'followers_count', 'pattern': '(f:User)-[:FOLLOWS]->(n)'}
                 or {'name': 'member_count', 'pattern': '(m:User)-[:MEMBER_OF]->(n)'}
    """
    if not count_specs:
        return {}

    match_clause = f"MATCH (n:{node_label} {{id: {node_id}}})"
    return_clauses = []
    for spec in count_specs:
        pattern = spec['pattern'].replace("(n)", "(n)") # Ensure pattern uses 'n'
        return_clauses.append(f"count(DISTINCT {spec.get('distinct_var', pattern[1])}) as {spec['name']}")
        # ^ Assumes the variable to count distinct is the first one in the pattern match (e.g., 'f' or 'm')
        # Adjust 'distinct_var' in spec if needed

    # Build the full Cypher query
    optional_matches = " ".join(f"OPTIONAL MATCH {spec['pattern']}" for spec in count_specs)
    return_statement = "RETURN " + ", ".join(f"count(DISTINCT {spec.get('distinct_var', spec['pattern'].split(':')[0][1:])}) as {spec['name']}" for spec in count_specs)
    # ^ Simpler way to build return statement directly

    cypher_q = f"{match_clause} {optional_matches} {return_statement}"

    # print(f"DEBUG get_graph_counts Cypher: {cypher_q}") # Debug

    result_agtype = execute_cypher(cursor, cypher_q, fetch_one=True)
    result_map = result_agtype if isinstance(result_agtype, dict) else {}

    # Convert results to int, default to 0
    counts = {spec['name']: int(result_map.get(spec['name'], 0)) for spec in count_specs}
    return counts
