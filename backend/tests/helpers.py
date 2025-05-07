# tests/helpers.py
import requests
import json
import traceback
from typing import Optional, Dict, Any, List, Union
import mimetypes
from pathlib import Path
import os # Import os

# --- MinIO related imports (conditional) ---
try:
    from minio import Minio
    from minio.error import S3Error
    MINIO_AVAILABLE = True
except ImportError:
    MINIO_AVAILABLE = False
    Minio = None
    S3Error = None

# Global test results dictionary
results = { "success": [], "failed": [], "skipped": [], }

# --- Request Helper ---
def make_api_request(
    session: requests.Session, # Expects session with base headers (Auth, API Key, Accept) set
    method: str,
    url: str,
    test_name: str,
    expected_status: List[int] = [200, 201, 204],
    params: Optional[Dict[str, Any]] = None,
    data: Optional[Dict[str, Any]] = None, # For form fields OR form-urlencoded
    json_data: Optional[Dict[str, Any]] = None, # Explicitly for JSON body
    files: Optional[Union[Dict[str, tuple], List[tuple]]] = None,
) -> Optional[Dict[str, Any]]:
    """Makes an API request using the provided session and logs results."""
    global results
    req_kwargs = {"params": params, "timeout": 30}
    log_data_str = "None"
    current_headers = session.headers.copy() # Get headers from session for this request

    # Determine body type and set Content-Type if needed
    if files:
        req_kwargs["files"] = files
        req_kwargs["data"] = data # Form fields
        file_log = f"{[f[1][0] for f in files] if isinstance(files, list) else {k: v[0] for k,v in files.items()}}"
        log_data_str = f"Form Fields: {data}, Files: {file_log}"
        if "Content-Type" in current_headers: del current_headers["Content-Type"] # Let requests set multipart
    elif json_data:
        req_kwargs["json"] = json_data # Use json parameter
        log_data_str = f"JSON Body: {json.dumps(json_data)}"
        current_headers["Content-Type"] = "application/json; charset=UTF-8"
    elif data:
        req_kwargs["data"] = data # Use data parameter
        log_data_str = f"Form Body: {data}"
        current_headers["Content-Type"] = "application/x-www-form-urlencoded"

    # Update kwargs with potentially modified headers for this specific request
    req_kwargs["headers"] = current_headers

    print(f"\n--- Testing: {test_name} ({method.upper()} {url}) ---")
    print(f"    Params: {params}")
    print(f"    Data: {log_data_str}")

    try:
        response = session.request(method, url, **req_kwargs)
        print(f"    Status Code: {response.status_code}")
        response_data, response_text = None, response.text
        try:
            if response_text: response_data = response.json()
            else: print("    Response Body: (Empty)")
        except json.JSONDecodeError:
            print(f"    Response Text (Not JSON): {response_text[:500]}...")
            response_data = {"error": "Non-JSON response", "content": response_text}

        if response.status_code in expected_status:
            print(f"    Result: SUCCESS")
            results["success"].append({"name": test_name, "status": response.status_code}) # Log less on success
            return response_data
        else:
            print(f"    Result: FAILED")
            print(f"    Response: {response_text[:1000]}") # Log full body on failure
            results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {url}", "status": response.status_code, "response": response_data or response_text})
            return None
    except requests.exceptions.Timeout: print(f"    Result: FAILED (Timeout)"); results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {url}", "status": "Timeout", "response": "Request timed out"})
    except requests.exceptions.RequestException as e: print(f"    Result: FAILED (Request Error: {e})"); results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {url}", "status": "Request Error", "response": str(e)})
    except Exception as e: print(f"    Result: FAILED (Script Error: {e})"); results["failed"].append({"name": test_name, "endpoint": f"{method.upper()} {url}", "status": "Script Error", "response": str(e)}); traceback.print_exc()
    return None

# --- File Preparation ---
def prepare_file_details(file_path_str: Optional[str]) -> Optional[tuple]:
    """Reads a file and returns (filename, content_bytes, mimetype) tuple."""
    if not file_path_str: return None
    file_path = Path(file_path_str)
    if file_path.is_file():
        try:
            filename = file_path.name; content = file_path.read_bytes(); mimetype, _ = mimetypes.guess_type(filename)
            print(f"    Prepared test file: {file_path} ({mimetype or 'unknown'})")
            return (filename, content, mimetype or 'application/octet-stream')
        except Exception as e: print(f"    ⚠️ Warning: Could not read/prepare test file '{file_path}': {e}")
    else: print(f"    ⚠️ Warning: Test file path '{file_path_str}' not found or not a file.")
    return None

# --- MinIO Helpers (Verification Disabled) ---
def verify_minio_upload(object_name: Optional[str], expect_exists: bool = True):
    print(f"    INFO: MinIO verification for '{object_name}' skipped.")

def extract_minio_object_name(url: Optional[str], bucket_name: str) -> Optional[str]:
     if not url or not bucket_name: return None
     try:
         path_part = url.split('?')[0]; key_part = f"/{bucket_name}/"
         if key_part in path_part: return path_part.split(key_part, 1)[1]
     except Exception as e: print(f"WARN: Failed to extract object name from URL '{url}': {e}")
     return None

# --- Result Printing ---
def print_test_summary():
    """Prints a summary of successful and failed tests."""
    print("\n\n" + "="*30 + " TEST SUMMARY " + "="*30)
    # Access global results dict
    success_count=len(results['success']);failed_count=len(results['failed']);skipped_count=len(results['skipped']);total_run=success_count+failed_count
    print(f"TOTAL TESTS EXECUTED: {total_run}")
    print(f"SUCCESSFUL:           {success_count}")
    print(f"FAILED:               {failed_count}")
    print(f"SKIPPED:              {skipped_count}")
    if results["failed"]:
        print("\n--- FAILED TESTS ---")
        for i, failure in enumerate(results["failed"]):
            print(f"\n{i+1}. Test Name: {failure.get('name', 'Unknown Test')}")
            print(f"   Endpoint:  {failure.get('endpoint', 'N/A')}")
            print(f"   Status:    {failure.get('status', 'N/A')}")
            response_content = failure.get('response', 'N/A')
            response_str = str(response_content)
            print(f"   Response:  {response_str[:1000]}{'...' if len(response_str)>1000 else ''}")
    elif total_run > 0: print("\n--- ALL EXECUTED TESTS PASSED ---")
    else: print("\n--- NO TESTS WERE EXECUTED ---")
    if results["skipped"]: print("\n--- SKIPPED TESTS ---"); [print(f"{i+1}. {s['name']}") for i, s in enumerate(results["skipped"])]
    print("="*74 + "\n")
