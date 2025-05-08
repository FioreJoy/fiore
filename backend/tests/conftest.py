# tests/conftest.py
import pytest
import requests
import os
from dotenv import load_dotenv
from pathlib import Path
import sys
import time # For potential delays if needed

# Add src to path if helpers are needed from there and not copied
#sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'src'))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'src')))
# --- Load Test Configuration ---
def load_test_config():
    """Loads configuration from .env and sets defaults."""
    config = {}
    dotenv_path = Path(__file__).resolve().parent.parent / '.env'
    if dotenv_path.is_file():
        print(f"\nLoading environment variables from: {dotenv_path}")
        load_dotenv(dotenv_path=dotenv_path)
    else:
        print(f"\nWarning: .env file not found at {dotenv_path}. Tests might fail.")

    config['BASE_URL'] = os.getenv("BASE_URL", "http://localhost:1163").rstrip('/')
    config['API_KEY'] = os.getenv("API_KEY")
    config['TEST_USER_EMAIL'] = os.getenv("TEST_USER_EMAIL", "alice@example.com")
    config['TEST_USER_PASSWORD'] = os.getenv("TEST_USER_PASSWORD")
    config['TEST_IMAGE_PATH_ABS'] = os.getenv("TEST_IMAGE_PATH_ABS") # Absolute path for image
    config['MINIO_BUCKET'] = os.getenv("MINIO_BUCKET", "connections") # Needed for URL parsing

    # Placeholder IDs
    try:
        config['TEST_DATA_IDS'] = {
            'target_user_id': int(os.getenv("TEST_TARGET_USER_ID", "2")),
            'other_user_id': int(os.getenv("TEST_OTHER_USER_ID", "5")),
            'community_id': int(os.getenv("TEST_COMMUNITY_ID", "1")),
            'event_id': int(os.getenv("TEST_EVENT_ID", "1")),
            'post_id': int(os.getenv("TEST_POST_ID", "2")),
            'reply_id': int(os.getenv("TEST_REPLY_ID", "1")),
            'post_id_to_link': int(os.getenv("TEST_POST_TO_LINK", "45")),
            'post_id_in_comm': int(os.getenv("TEST_POST_IN_COMM", "10")),
        }
    except ValueError:
        pytest.exit("ERROR: TEST_* IDs in .env must be valid integers.", returncode=1)

    # Validate required config
    if not config['API_KEY']:
        pytest.exit("ERROR: API_KEY environment variable not set.", returncode=1)
    if not config['TEST_USER_PASSWORD']:
         pytest.exit("ERROR: TEST_USER_PASSWORD environment variable not set.", returncode=1)

    return config

CONFIG = load_test_config()

# --- Pytest Fixtures ---

@pytest.fixture(scope="session")
def config():
    """Provides the loaded configuration dictionary."""
    return CONFIG

@pytest.fixture(scope="session")
def base_url():
    """Provides the base URL for the API."""
    return CONFIG['BASE_URL']

@pytest.fixture(scope="session")
def api_key():
    """Provides the API Key."""
    return CONFIG['API_KEY']

@pytest.fixture(scope="session")
def test_user_credentials():
    """Provides test user email and password."""
    return {"email": CONFIG['TEST_USER_EMAIL'], "password": CONFIG['TEST_USER_PASSWORD']}

@pytest.fixture(scope="session")
def test_data_ids():
    """Provides dictionary of IDs for existing test entities."""
    return CONFIG['TEST_DATA_IDS']

@pytest.fixture(scope="session")
def http_session():
    """Provides a shared requests session."""
    with requests.Session() as session:
        # Set Accept header globally for the session
        session.headers.update({"Accept": "application/json"})
        yield session

# Fixture to log in ONCE per session and provide auth details
# Depends on other session-scoped fixtures
@pytest.fixture(scope="session")
def authenticated_session(http_session, base_url, api_key, test_user_credentials):
    """Logs in the test user and configures the session with auth headers."""
    print("\n--- Logging in test user for session ---")
    login_data = {
        "email": test_user_credentials["email"],
        "password": test_user_credentials["password"]
    }
    # Headers for login don't need auth token, but need API key and Content-Type
    login_headers = {"Accept": "application/json", "Content-Type": "application/json"}
    if api_key: login_headers["X-API-Key"] = api_key

    try:
        response = http_session.post(f"{base_url}/auth/login", json=login_data, headers=login_headers, timeout=15)
        response.raise_for_status()
        response_data = response.json()
        token = response_data.get("token")
        user_id = response_data.get("user_id")
        if not token or user_id is None:
            pytest.fail(f"Login failed: Token or user_id missing. Response: {response_data}")

        print(f"--- Login Successful (User ID: {user_id}) ---")
        # Set default headers for subsequent requests in this session
        http_session.headers.update({
            "Authorization": f"Bearer {token}",
            "X-API-Key": api_key # Add API Key to session headers as well
        })
        # Return details needed by tests
        return {
            "session": http_session, # The configured session object
            "token": token,
            "user_id": user_id,
            "base_url": base_url,
            "api_key": api_key, # Pass API key if needed separately
            "bucket_name": CONFIG['MINIO_BUCKET'] # Pass bucket name
        }
    except requests.exceptions.RequestException as e:
        pytest.fail(f"Login request failed: {e}")
    except Exception as e:
         pytest.fail(f"Login failed with unexpected error: {e}\nResponse Text: {response.text if 'response' in locals() else 'N/A'}")

# Fixture to prepare test file data once per session
@pytest.fixture(scope="session")
def prepared_test_files(config):
    """Prepares test image and text file details."""
    image_details = None
    text_details = None
    text_file_path = Path("./test_upload_session.txt").resolve()

    # Prepare image
    img_path_str = config.get('TEST_IMAGE_PATH_ABS')
    if img_path_str:
        img_path = Path(img_path_str)
        if img_path.is_file():
            try:
                filename = img_path.name; content = img_path.read_bytes()
                mimetype, _ = mimetypes.guess_type(filename)
                image_details = (filename, content, mimetype or 'application/octet-stream')
                print(f"✅ Session Fixture: Prepared test image: {img_path}")
            except Exception as e: print(f"⚠️ Session Fixture Warning: Could not read image file: {e}")
        else: print(f"⚠️ Session Fixture Warning: Image path not found: {img_path_str}")
    else: print("INFO: Session Fixture: TEST_IMAGE_PATH_ABS not set, skipping image preparation.")

    # Prepare text file
    try:
        text_content = f"Session test file {datetime.now()}".encode('utf-8')
        text_file_path.write_bytes(text_content)
        text_details = (text_file_path.name, text_content, 'text/plain')
        print(f"✅ Session Fixture: Prepared test text file: {text_file_path}")
    except Exception as e: print(f"⚠️ Session Fixture Warning: Could not prepare text file: {e}")

    yield {"image": image_details, "text": text_details}

    # Teardown text file
    if text_file_path.exists():
        try: text_file_path.unlink(); print(f"🧹 Session Fixture: Cleaned up text file: {text_file_path}")
        except Exception as e: print(f"⚠️ Session Fixture Warning: Error cleaning up text file: {e}")
