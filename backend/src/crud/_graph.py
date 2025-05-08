# src/crud/_graph.py
import psycopg2
import psycopg2.extras
from typing import Optional, Dict, Any, List, Tuple

from .. import utils

GRAPH_NAME = 'fiore'

# --- REVISED Helper to execute Cypher query ---
def execute_cypher(
        cursor: psycopg2.extensions.cursor,
        query: str,
        fetch_one=False,
        fetch_all=False,
        # Use specific column definitions for reads, or None for writes
        expected_columns: Optional[List[Tuple[str, str]]] = None
):
    """
    Executes Cypher via AGE.
    - Requires `expected_columns` for fetch_one/fetch_all.
    - Uses a default dummy output for write operations (MERGE/CREATE/DELETE/SET).
    """
    cursor.execute("LOAD 'age';")
    cursor.execute("SET search_path = ag_catalog, '$user', public;")

    # --- Determine AS clause ---
    as_clause: str
    if fetch_one or fetch_all:
        # READ operations MUST define expected output
        if not expected_columns:
            print(f"ERROR execute_cypher: expected_columns is REQUIRED for fetch=True. Query: {query[:100]}...")
            raise ValueError("expected_columns must be provided for Cypher queries that fetch data.")
        col_defs = ", ".join([f"{name} {type}" for name, type in expected_columns])
        as_clause = f"AS ({col_defs})"
    else:
        # WRITE operations (MERGE/CREATE/DELETE/SET without RETURN)
        # Use a minimal definition. AGE might return void or a status.
        # Using 'result agtype' is a common pattern here, assuming it handles void/null return.
        as_clause = "AS (result agtype)"
        # We don't actually use the result for writes, just check for errors.
        expected_columns = [('result', 'agtype')] # Set internally for processing logic below

    sql = f"SELECT * FROM ag_catalog.cypher('{GRAPH_NAME}', $${query}$$) {as_clause};"

    try:
        # print(f"DEBUG Cypher SQL: {sql.strip()}")
        cursor.execute(sql)

        if fetch_one:
            row = cursor.fetchone();
            if not row: return None
            row_dict = dict(row)
            # Parse based on expected columns definition
            return {col_name: utils.parse_agtype(row_dict.get(col_name)) for col_name, _ in expected_columns}

        elif fetch_all:
            rows = cursor.fetchall(); results = []
            for row in rows:
                row_dict = dict(row)
                results.append({col_name: utils.parse_agtype(row_dict.get(col_name)) for col_name, _ in expected_columns})
            return results
        else: # Write operation succeeded if no error
            return True

    except psycopg2.Error as db_err:
        print(f"!!! Cypher Execution Error ({db_err.pgcode}): {db_err}")
        print(f"    SQL: {sql}")
        raise db_err # Re-raise
    except Exception as e:
        print(f"!!! Unexpected Error in execute_cypher: {e}")
        print(f"    SQL: {sql}")
        raise e

# --- build_cypher_set_clauses remains the same ---
def build_cypher_set_clauses(variable: str, props_dict: Dict[str, Any]) -> Optional[str]:
    items = [];
    for k, v in props_dict.items():
        if k != 'id' and v is not None: items.append(f"{variable}.{k} = {utils.quote_cypher_string(v)}")
    return ", ".join(items) if items else None