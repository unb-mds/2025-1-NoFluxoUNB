# direct_test.py
import requests
import json
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='[%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(),  # Console output
        logging.FileHandler('../logs/direct_test.log', mode='a')  # Log file
    ]
)

logger = logging.getLogger(__name__)

logger.info("="*60)
logger.info("DIRECT RAGFlow API TEST STARTED")
logger.info(f"Test started at: {datetime.now().isoformat()}")
logger.info("="*60)

logger.warning("NOTICE: This test uses hardcoded credentials for direct API testing")
logger.warning("For production use, always use environment variables or secure configuration")

# --- SUAS CREDENCIAIS CORRETAS ESTÃO FIXAS AQUI ---
# Pegue a chave da interface do RAGFlow (⚙️ -> API Setting)
API_KEY      = "ragflow-MyMDYxOTNjNDhhNjExZjBhYWEzZmE3Nj"
# Pegue o ID do seu agente na lista de agentes
AGENT_ID     = "10b20f0248a611f089a9fa761c0fa70c"
BASE_URL     = "http://localhost"
# --------------------------------------------------

logger.info("STEP 1: Configuration validation")
logger.info("Hardcoded configuration loaded:")
logger.info(f"  API_KEY: {API_KEY[:15]}...{API_KEY[-6:]} (length: {len(API_KEY)})")
logger.info(f"  AGENT_ID: {AGENT_ID}")
logger.info(f"  BASE_URL: {BASE_URL}")

# Validate configuration
config_valid = True
if not API_KEY or len(API_KEY) < 10:
    logger.error("API_KEY appears to be invalid or too short")
    config_valid = False

if not AGENT_ID or len(AGENT_ID) < 10:
    logger.error("AGENT_ID appears to be invalid or too short")
    config_valid = False

if not BASE_URL or not BASE_URL.startswith(('http://', 'https://')):
    logger.error("BASE_URL appears to be invalid")
    config_valid = False

if not config_valid:
    logger.error("Configuration validation failed - stopping test")
    exit(1)

logger.info("Configuration validation successful")

logger.info("STEP 2: Preparing HTTP request")
headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

endpoint_url = f"{BASE_URL}/api/v1/agents_openai/{AGENT_ID}/chat/completions"

payload = {
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Isto é um teste direto."}],
    "stream": False
}

logger.info("HTTP request prepared:")
logger.info(f"  Endpoint URL: {endpoint_url}")
logger.info(f"  Method: POST")
logger.info(f"  Headers: {json.dumps({k: v if k != 'Authorization' else 'Bearer ***' for k, v in headers.items()}, indent=4)}")
logger.info(f"  Payload: {json.dumps(payload, indent=4)}")
logger.debug(f"  Payload size: {len(json.dumps(payload))} bytes")

logger.info("STEP 3: Making HTTP request to RAGFlow API")
request_start_time = datetime.now()

try:
    logger.debug("Sending POST request...")
    logger.debug(f"Request timeout: 180 seconds")
    
    response = requests.post(endpoint_url, headers=headers, json=payload, timeout=180)
    request_duration = (datetime.now() - request_start_time).total_seconds()
    
    logger.info(f"HTTP request completed in {request_duration:.2f} seconds")
    logger.info(f"Response status code: {response.status_code}")
    logger.debug(f"Response headers: {dict(response.headers)}")
    logger.debug(f"Response size: {len(response.content)} bytes")
    
    logger.info("STEP 4: Validating HTTP response")
    
    # Check for HTTP errors
    try:
        response.raise_for_status()
        logger.info("HTTP status validation successful - no HTTP errors")
    except requests.exceptions.HTTPError as http_err:
        logger.error("="*50)
        logger.error("HTTP ERROR DETECTED")
        logger.error("="*50)
        logger.error(f"HTTP Status Code: {response.status_code}")
        logger.error(f"HTTP Error: {http_err}")
        logger.error(f"Response Headers: {dict(response.headers)}")
        logger.error(f"Response Content: {response.text}")
        logger.error("="*50)
        raise
    
    logger.info("STEP 5: Parsing JSON response")
    
    try:
        json_data = response.json()
        logger.info("JSON parsing successful")
        logger.debug(f"Response JSON keys: {list(json_data.keys()) if isinstance(json_data, dict) else 'Not a dict'}")
        logger.debug(f"Response JSON type: {type(json_data)}")
    except json.JSONDecodeError as json_err:
        logger.error("="*50)
        logger.error("JSON PARSING ERROR")
        logger.error("="*50)
        logger.error(f"JSON Error: {json_err}")
        logger.error(f"Raw Response Content: {response.text}")
        logger.error("="*50)
        raise
    
    logger.info("STEP 6: Extracting response content")
    
    # Extract the final answer
    try:
        choices = json_data.get("choices", [])
        logger.debug(f"Number of choices in response: {len(choices)}")
        
        if not choices:
            logger.warning("No choices found in response")
            final_answer = ""
        else:
            logger.debug(f"First choice structure: {list(choices[0].keys()) if isinstance(choices[0], dict) else 'Not a dict'}")
            
            message = choices[0].get("message", {})
            logger.debug(f"Message structure: {list(message.keys()) if isinstance(message, dict) else 'Not a dict'}")
            
            final_answer = message.get("content", "")
            logger.debug(f"Content length: {len(final_answer)} characters")
    
    except Exception as extract_err:
        logger.error(f"Error extracting content from response: {extract_err}")
        logger.debug(f"Full response for debugging: {json.dumps(json_data, indent=2)}")
        final_answer = ""
    
    logger.info("STEP 7: Presenting results")
    
    if final_answer:
        logger.info("="*50)
        logger.info("TEST RESULT: SUCCESS")
        logger.info("RAGFlow API responded with content")
        logger.info("="*50)
        logger.info("API Response Content:")
        logger.info("-" * 30)
        logger.info(final_answer.strip())
        logger.info("-" * 30)
        logger.info(f"Response length: {len(final_answer)} characters")
        logger.info(f"Total test duration: {request_duration:.2f} seconds")
    else:
        logger.warning("="*50)
        logger.warning("TEST RESULT: SUCCESS (BUT NO CONTENT)")
        logger.warning("Connection successful but no content received")
        logger.warning("="*50)
        logger.info("Full response for analysis:")
        logger.info(json.dumps(json_data, indent=2))
        logger.info(f"Total test duration: {request_duration:.2f} seconds")

except requests.exceptions.HTTPError as http_err:
    request_duration = (datetime.now() - request_start_time).total_seconds()
    logger.error("="*50)
    logger.error("TEST RESULT: HTTP ERROR")
    logger.error("="*50)
    logger.error(f"Test duration before error: {request_duration:.2f} seconds")
    logger.error(f"HTTP Status Code: {http_err.response.status_code}")
    logger.error(f"HTTP Error Details: {http_err}")
    logger.error(f"Server Response: {http_err.response.text}")
    logger.error("="*50)
    
    # Additional debugging information
    logger.debug("Request details that caused the error:")
    logger.debug(f"  URL: {endpoint_url}")
    logger.debug(f"  Method: POST")
    logger.debug(f"  Headers: {headers}")
    logger.debug(f"  Payload: {json.dumps(payload)}")
    
except requests.exceptions.Timeout:
    request_duration = (datetime.now() - request_start_time).total_seconds()
    logger.error("="*50)
    logger.error("TEST RESULT: TIMEOUT ERROR")
    logger.error("="*50)
    logger.error(f"Request timed out after {request_duration:.2f} seconds")
    logger.error("This could indicate:")
    logger.error("  1. RAGFlow server is slow to respond")
    logger.error("  2. Network connectivity issues")
    logger.error("  3. Server is overloaded")
    logger.error("="*50)
    
except requests.exceptions.ConnectionError as conn_err:
    request_duration = (datetime.now() - request_start_time).total_seconds()
    logger.error("="*50)
    logger.error("TEST RESULT: CONNECTION ERROR")
    logger.error("="*50)
    logger.error(f"Test duration before error: {request_duration:.2f} seconds")
    logger.error(f"Connection Error: {conn_err}")
    logger.error("This could indicate:")
    logger.error("  1. RAGFlow server is not running")
    logger.error("  2. Wrong base URL configuration")
    logger.error("  3. Network connectivity issues")
    logger.error("  4. Firewall blocking the connection")
    logger.error(f"Attempted to connect to: {endpoint_url}")
    logger.error("="*50)
    
except Exception as e:
    request_duration = (datetime.now() - request_start_time).total_seconds()
    logger.error("="*50)
    logger.error("TEST RESULT: UNEXPECTED ERROR")
    logger.error("="*50)
    logger.error(f"Test duration before error: {request_duration:.2f} seconds")
    logger.error(f"Error type: {type(e).__name__}")
    logger.error(f"Error message: {str(e)}")
    logger.error("="*50)
    logger.debug("Full stack trace:", exc_info=True)

finally:
    total_duration = (datetime.now() - request_start_time).total_seconds()
    logger.info("="*60)
    logger.info("DIRECT RAGFlow API TEST COMPLETED")
    logger.info(f"Total test duration: {total_duration:.2f} seconds")
    logger.info(f"Test ended at: {datetime.now().isoformat()}")
    logger.info("="*60)