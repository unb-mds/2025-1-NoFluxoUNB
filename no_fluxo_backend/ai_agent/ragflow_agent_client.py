# ragflow_agent_client.py (VERSÃO FINAL E FUNCIONAL)
import requests
import json
import logging
from datetime import datetime
from config import RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID
#import formataResposta

# Configure logger for this module
logger = logging.getLogger(__name__)

API_KEY = RAGFLOW_API_KEY
BASE_URL = RAGFLOW_BASE_URL
AGENT_ID = RAGFLOW_AGENT_ID

class RagflowClient:
    def __init__(self, agent_id=AGENT_ID):
        logger.info("="*50)
        logger.info("RAGFlow CLIENT INITIALIZATION")
        logger.info("="*50)
        
        logger.debug("FUNCTION ENTRY: RagflowClient.__init__()")
        logger.debug(f"Input agent_id parameter: {agent_id}")
        
        # Store configuration
        self.agent_id = agent_id
        self.url = f"{BASE_URL}/api/v1/agents/{self.agent_id}/completions"
        self.headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json"
        }
        
        # Validate configuration
        logger.info("Validating RAGFlow client configuration...")
        
        if not API_KEY:
            logger.error("RAGFLOW_API_KEY is not set or empty")
            raise ValueError("RAGFLOW_API_KEY must be configured")
        
        if not BASE_URL:
            logger.error("RAGFLOW_BASE_URL is not set or empty")
            raise ValueError("RAGFLOW_BASE_URL must be configured")
            
        if not self.agent_id:
            logger.error("Agent ID is not set or empty")
            raise ValueError("Agent ID must be provided")
        
        logger.info("Configuration validation successful")
        
        logger.info("RAGFlow client configuration:")
        logger.info(f"  Agent ID: {self.agent_id}")
        logger.info(f"  Base URL: {BASE_URL}")
        logger.info(f"  Endpoint: {self.url}")
        logger.info(f"  API Key: {'SET' if API_KEY else 'NOT SET'} (length: {len(API_KEY) if API_KEY else 0})")
        
        logger.debug("Request headers prepared:")
        safe_headers = {k: v if k != 'Authorization' else 'Bearer ***' for k, v in self.headers.items()}
        logger.debug(f"  Headers: {json.dumps(safe_headers, indent=4)}")
        
        logger.info("RAGFlow client initialized successfully")
        logger.debug("FUNCTION EXIT: RagflowClient.__init__()")

    def start_session(self, materia):
        """Start a new session with the RAGFlow agent"""
        logger.info("="*40)
        logger.info("STARTING NEW RAGFlow SESSION")
        logger.info("="*40)
        
        logger.debug("FUNCTION ENTRY: start_session()")
        logger.info(f"Input materia: '{materia}' (type: {type(materia)}, length: {len(str(materia))})")
        
        session_start_time = datetime.now()
        session_id = None
        
        try:
            # Input validation
            logger.debug("STEP 1: Input validation")
            
            if not materia:
                logger.error("Materia parameter is empty or None")
                raise ValueError("Materia parameter cannot be empty")
            
            if not isinstance(materia, str):
                logger.warning(f"Materia is not a string (type: {type(materia)}), converting...")
                materia = str(materia)
            
            logger.debug(f"Validated materia: '{materia}'")
            
            # Prepare payload
            logger.debug("STEP 2: Preparing session payload")
            payload = {"materia": materia, "stream": False}
            payload_size = len(json.dumps(payload))
            
            logger.info("Session request details:")
            logger.info(f"  Endpoint: {self.url}")
            logger.info(f"  Method: POST")
            logger.info(f"  Payload size: {payload_size} bytes")
            logger.debug(f"  Payload content: {json.dumps(payload, indent=2)}")
            
            # Make request
            logger.debug("STEP 3: Making HTTP request to RAGFlow")
            logger.debug(f"Making POST request to: {self.url}")
            logger.debug("Request timeout: 30 seconds")
            
            resp = requests.post(self.url, headers=self.headers, json=payload, timeout=30)
            
            request_duration = (datetime.now() - session_start_time).total_seconds()
            logger.info(f"HTTP request completed in {request_duration:.2f} seconds")
            
            # Log response details
            logger.debug("STEP 4: Analyzing HTTP response")
            logger.info(f"Response status code: {resp.status_code}")
            logger.debug(f"Response headers: {dict(resp.headers)}")
            logger.debug(f"Response size: {len(resp.content)} bytes")
            logger.debug(f"Response encoding: {resp.encoding}")

            # Check HTTP status
            logger.debug("STEP 5: Validating HTTP status")
            try:
                resp.raise_for_status()
                logger.debug("HTTP status validation successful - no HTTP errors")
            except requests.exceptions.HTTPError as http_err:
                logger.error("HTTP error occurred during session start:")
                logger.error(f"  Status code: {resp.status_code}")
                logger.error(f"  Error: {http_err}")
                logger.error(f"  Response text: {resp.text}")
                raise

            # Parse JSON response
            logger.debug("STEP 6: Parsing JSON response")
            try:
                data = resp.json()
                logger.debug("JSON parsing successful")
                logger.debug(f"Response data type: {type(data)}")
                
                if isinstance(data, dict):
                    logger.debug(f"Response keys: {list(data.keys())}")
                    
                    # Log response structure
                    for key, value in data.items():
                        if isinstance(value, dict):
                            logger.debug(f"  {key}: dict with keys {list(value.keys())}")
                        elif isinstance(value, list):
                            logger.debug(f"  {key}: list with {len(value)} items")
                        else:
                            logger.debug(f"  {key}: {type(value).__name__}")
                
            except json.JSONDecodeError as e:
                logger.error("JSON parsing failed:")
                logger.error(f"  JSON error: {e}")
                logger.error(f"  Raw response content: {resp.text}")
                raise
                
            # Extract session ID
            logger.debug("STEP 7: Extracting session ID")
            
            if isinstance(data, dict) and "data" in data:
                data_section = data["data"]
                logger.debug(f"Data section type: {type(data_section)}")
                
                if isinstance(data_section, dict) and "session_id" in data_section:
                    session_id = data_section["session_id"]
                    logger.info(f"Session ID extracted successfully: {session_id}")
                    
                    # Validate session ID
                    if not session_id or len(session_id) < 5:
                        logger.warning(f"Session ID appears to be invalid: '{session_id}'")
                    else:
                        logger.debug(f"Session ID validation passed (length: {len(session_id)})")
                else:
                    logger.error("'session_id' not found in data section")
                    logger.error(f"Available keys in data section: {list(data_section.keys()) if isinstance(data_section, dict) else 'Not a dict'}")
                    raise ValueError("session_id not found in API response")
            else:
                logger.error("Unexpected response structure - 'data' section not found")
                logger.error(f"Available keys: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
                logger.debug(f"Full response: {json.dumps(data, indent=2)}")
                raise ValueError("Invalid response structure from RAGFlow API")
            
            # Success logging
            total_duration = (datetime.now() - session_start_time).total_seconds()
            logger.info("="*30)
            logger.info("SESSION START SUCCESSFUL")
            logger.info(f"Session ID: {session_id}")
            logger.info(f"Total duration: {total_duration:.2f} seconds")
            logger.info("="*30)
            
            logger.debug("FUNCTION EXIT: start_session() - success")
            return session_id
                    
        except requests.exceptions.Timeout:
            request_duration = (datetime.now() - session_start_time).total_seconds()
            logger.error("Session start failed - timeout occurred:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Duration before timeout: {request_duration:.2f} seconds")
            logger.error(f"  Endpoint: {self.url}")
            raise
            
        except requests.exceptions.ConnectionError as conn_err:
            request_duration = (datetime.now() - session_start_time).total_seconds()
            logger.error("Session start failed - connection error:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Duration before error: {request_duration:.2f} seconds")
            logger.error(f"  Connection error: {conn_err}")
            logger.error(f"  Endpoint: {self.url}")
            raise
            
        except requests.exceptions.RequestException as e:
            request_duration = (datetime.now() - session_start_time).total_seconds()
            logger.error("Session start failed - request exception:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Duration before error: {request_duration:.2f} seconds")
            logger.error(f"  Request exception: {e}")
            logger.error(f"  Exception type: {type(e).__name__}")
            raise
            
        except Exception as e:
            request_duration = (datetime.now() - session_start_time).total_seconds()
            logger.error("Session start failed - unexpected error:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Duration before error: {request_duration:.2f} seconds")
            logger.error(f"  Error: {e}")
            logger.error(f"  Error type: {type(e).__name__}")
            logger.debug("Full stack trace:", exc_info=True)
            raise

    def analyze_materia(self, materia: str, session_id: str):
        """Analyze a materia using the RAGFlow agent with an existing session"""
        logger.info("="*40)
        logger.info("STARTING RAGFlow ANALYSIS")
        logger.info("="*40)
        
        logger.debug("FUNCTION ENTRY: analyze_materia()")
        logger.info(f"Input materia: '{materia}' (type: {type(materia)}, length: {len(str(materia))})")
        logger.info(f"Session ID: {session_id}")
        
        analysis_start_time = datetime.now()
        
        try:
            # Input validation
            logger.debug("STEP 1: Input validation")
            
            if not materia:
                logger.error("Materia parameter is empty or None")
                raise ValueError("Materia parameter cannot be empty")
            
            if not session_id:
                logger.error("Session ID parameter is empty or None")
                raise ValueError("Session ID parameter cannot be empty")
            
            if not isinstance(materia, str):
                logger.warning(f"Materia is not a string (type: {type(materia)}), converting...")
                materia = str(materia)
                
            if not isinstance(session_id, str):
                logger.warning(f"Session ID is not a string (type: {type(session_id)}), converting...")
                session_id = str(session_id)
            
            logger.debug(f"Validated materia: '{materia}'")
            logger.debug(f"Validated session_id: '{session_id}'")
            
            # Prepare payload
            logger.debug("STEP 2: Preparing analysis payload")
            payload = {
                "question": materia,
                "session_id": session_id,
                "stream": False
            }
            payload_size = len(json.dumps(payload))
            
            logger.info("Analysis request details:")
            logger.info(f"  Endpoint: {self.url}")
            logger.info(f"  Method: POST")
            logger.info(f"  Payload size: {payload_size} bytes")
            logger.debug(f"  Payload content: {json.dumps(payload, indent=2)}")
            
            # Make request
            logger.debug("STEP 3: Making HTTP request to RAGFlow")
            logger.debug(f"Making POST request to: {self.url}")
            logger.debug("Request timeout: 60 seconds")
            
            resp = requests.post(self.url, headers=self.headers, json=payload, timeout=60)
            
            request_duration = (datetime.now() - analysis_start_time).total_seconds()
            logger.info(f"HTTP request completed in {request_duration:.2f} seconds")

            # Log response details
            logger.debug("STEP 4: Analyzing HTTP response")
            logger.info(f"Response status code: {resp.status_code}")
            logger.debug(f"Response headers: {dict(resp.headers)}")
            logger.debug(f"Response size: {len(resp.content)} bytes")
            logger.debug(f"Response encoding: {resp.encoding}")

            # Check HTTP status
            logger.debug("STEP 5: Validating HTTP status")
            try:
                resp.raise_for_status()
                logger.debug("HTTP status validation successful - no HTTP errors")
            except requests.exceptions.HTTPError as http_err:
                logger.error("HTTP error occurred during analysis:")
                logger.error(f"  Status code: {resp.status_code}")
                logger.error(f"  Error: {http_err}")
                logger.error(f"  Response text: {resp.text}")
                raise

            # Parse JSON response
            logger.debug("STEP 6: Parsing JSON response")
            try:
                data = resp.json()
                logger.debug("JSON parsing successful")
                logger.debug(f"Response data type: {type(data)}")
                
                if isinstance(data, dict):
                    logger.debug(f"Response keys: {list(data.keys())}")
                    
                    # Log response structure safely
                    for key, value in data.items():
                        if isinstance(value, dict):
                            logger.debug(f"  {key}: dict with keys {list(value.keys())}")
                        elif isinstance(value, list):
                            logger.debug(f"  {key}: list with {len(value)} items")
                        elif isinstance(value, str) and len(value) > 100:
                            logger.debug(f"  {key}: string (length: {len(value)}, preview: '{value[:50]}...')")
                        else:
                            logger.debug(f"  {key}: {type(value).__name__} = {value}")
                
            except json.JSONDecodeError as e:
                logger.error("JSON parsing failed:")
                logger.error(f"  JSON error: {e}")
                logger.error(f"  Raw response content: {resp.text}")
                raise
                
            # Validate response code
            logger.debug("STEP 7: Validating API response code")
            if isinstance(data, dict) and "code" in data:
                response_code = data["code"]
                logger.info(f"RAGFlow API response code: {response_code}")
                
                if response_code == 0:
                    logger.info("API response indicates success (code: 0)")
                else:
                    logger.warning(f"API returned non-zero code: {response_code}")
                    if "message" in data:
                        logger.warning(f"API message: {data['message']}")
                    
                    # Log additional error context
                    logger.warning("Non-zero response code details:")
                    logger.warning(f"  Input materia: '{materia}'")
                    logger.warning(f"  Session ID: {session_id}")
                    logger.warning(f"  Full response: {json.dumps(data, indent=2)}")
            else:
                logger.warning("No 'code' field found in API response")
                logger.debug(f"Available fields: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
            
            # Success logging
            total_duration = (datetime.now() - analysis_start_time).total_seconds()
            logger.info("="*30)
            logger.info("ANALYSIS COMPLETED SUCCESSFULLY")
            logger.info(f"Materia: '{materia}'")
            logger.info(f"Session ID: {session_id}")
            logger.info(f"Total duration: {total_duration:.2f} seconds")
            logger.info(f"Response code: {data.get('code', 'not available')}")
            logger.info("="*30)
            
            # Log response summary
            self._log_response_summary(data, "Analysis")
            
            logger.debug("FUNCTION EXIT: analyze_materia() - success")
            return data
                
        except requests.exceptions.Timeout:
            request_duration = (datetime.now() - analysis_start_time).total_seconds()
            logger.error("Analysis failed - timeout occurred:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Session ID: {session_id}")
            logger.error(f"  Duration before timeout: {request_duration:.2f} seconds")
            logger.error(f"  Endpoint: {self.url}")
            raise
            
        except requests.exceptions.ConnectionError as conn_err:
            request_duration = (datetime.now() - analysis_start_time).total_seconds()
            logger.error("Analysis failed - connection error:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Session ID: {session_id}")
            logger.error(f"  Duration before error: {request_duration:.2f} seconds")
            logger.error(f"  Connection error: {conn_err}")
            logger.error(f"  Endpoint: {self.url}")
            raise
            
        except requests.exceptions.RequestException as e:
            request_duration = (datetime.now() - analysis_start_time).total_seconds()
            logger.error("Analysis failed - request exception:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Session ID: {session_id}")
            logger.error(f"  Duration before error: {request_duration:.2f} seconds")
            logger.error(f"  Request exception: {e}")
            logger.error(f"  Exception type: {type(e).__name__}")
            raise
            
        except Exception as e:
            request_duration = (datetime.now() - analysis_start_time).total_seconds()
            logger.error("Analysis failed - unexpected error:")
            logger.error(f"  Materia: '{materia}'")
            logger.error(f"  Session ID: {session_id}")
            logger.error(f"  Duration before error: {request_duration:.2f} seconds")
            logger.error(f"  Error: {e}")
            logger.error(f"  Error type: {type(e).__name__}")
            logger.debug("Full stack trace:", exc_info=True)
            raise

    def _log_response_summary(self, response_data, operation):
        """Log a summary of the response data (helper method)"""
        logger.debug(f"FUNCTION ENTRY: _log_response_summary(operation='{operation}')")
        
        try:
            if isinstance(response_data, dict):
                logger.debug(f"{operation} response summary:")
                logger.debug(f"  Response type: {type(response_data)}")
                logger.debug(f"  Number of keys: {len(response_data)}")
                logger.debug(f"  Top-level keys: {list(response_data.keys())}")
                
                # Log specific important fields
                important_fields = ['code', 'message', 'data', 'error', 'success', 'result']
                for field in important_fields:
                    if field in response_data:
                        value = response_data[field]
                        if isinstance(value, str) and len(value) > 100:
                            logger.debug(f"  {field}: string (length: {len(value)}, preview: '{value[:50]}...')")
                        elif isinstance(value, dict):
                            logger.debug(f"  {field}: dict with keys {list(value.keys())}")
                        elif isinstance(value, list):
                            logger.debug(f"  {field}: list with {len(value)} items")
                        else:
                            logger.debug(f"  {field}: {value}")
                
                if "data" in response_data:
                    data_section = response_data["data"]
                    logger.debug(f"  Data section analysis:")
                    logger.debug(f"    Data type: {type(data_section)}")
                    if isinstance(data_section, dict):
                        logger.debug(f"    Data keys: {list(data_section.keys())}")
                        logger.debug(f"    Data size: {len(data_section)} items")
                    elif isinstance(data_section, list):
                        logger.debug(f"    Data length: {len(data_section)} items")
                        
            else:
                logger.debug(f"{operation} response summary:")
                logger.debug(f"  Response type: {type(response_data)} (not a dict)")
                logger.debug(f"  Response content: {str(response_data)[:200]}...")
                        
        except Exception as e:
            logger.warning(f"Failed to log response summary for {operation}: {e}")
            logger.debug(f"Summary error details: {type(e).__name__}: {str(e)}")
        
        logger.debug("FUNCTION EXIT: _log_response_summary()")

    '''
    def gerar_palavrasChaves(self, materia: str):
        """Generate keywords for a materia (commented out method)"""
        logger.info(f"FUNCTION ENTRY: gerar_palavrasChaves(materia='{materia}')")
        logger.warning("This method is currently commented out and not implemented")

        payload = {
            "materia": materia,
            "stream": False
        }
        logger.debug(f"Keywords payload: {json.dumps(payload, indent=2)}")
        
        resp = requests.post(self.url, headers=self.headers, json=payload)
        logger.debug(f"Keywords response status: {resp.status_code}")
        
        resp.raise_for_status()
        logger.debug("No HTTP errors raised for keywords request")
        
        response_data = resp.json()
        logger.debug(f"Keywords response: {response_data}")
        return response_data
    '''