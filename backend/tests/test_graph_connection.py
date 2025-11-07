
import psycopg2
import psycopg2.extras
import pytest
from src.database import get_db_connection

def test_graph_connection():
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("LOAD 'age';")
        cursor.execute("SET search_path = ag_catalog, '$user', public;")
        cursor.execute("SELECT * FROM ag_catalog.cypher('fiore', $$MATCH (n) RETURN count(n)$$) AS (c agtype);")
        result = cursor.fetchone()
        assert result is not None
        assert 'c' in result
        assert isinstance(int(result['c']), int)
    finally:
        if conn:
            conn.close()
