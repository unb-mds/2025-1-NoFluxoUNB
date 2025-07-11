# ragflow_agent_client.py (VERSÃO FINAL E FUNCIONAL)
import requests
import json
import logging
from datetime import datetime
from .config import RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID
#import formataResposta

# Configure logger for this module
logger = logging.getLogger(__name__)

API_KEY = RAGFLOW_API_KEY
BASE_URL = RAGFLOW_BASE_URL
AGENT_ID = RAGFLOW_AGENT_ID

class RagflowClient:
    def __init__(self, agent_id=AGENT_ID):
        logger.info("Initializing RagflowClient")
        self.agent_id = agent_id
        self.url = f"{BASE_URL}/api/v1/agents/{self.agent_id}/completions"
        self.headers = {
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json"
        }
        
        logger.info(f"RAGFlow client initialized with:")
        logger.info(f"  - Agent ID: {self.agent_id}")
        logger.info(f"  - Base URL: {BASE_URL}")
        logger.info(f"  - Endpoint: {self.url}")
        logger.debug(f"  - Headers: {json.dumps({k: v if k != 'Authorization' else 'Bearer ***' for k, v in self.headers.items()}, indent=2)}")

    def start_session(self, materia):
        """Start a new session with the RAGFlow agent"""
        logger.info(f"Starting new session for materia: '{materia}'")
        
        session_start_time = datetime.now()
        
        try:
            payload = {"materia": materia, "stream": False}
            logger.debug(f"Session payload: {json.dumps(payload, indent=2)}")
            
            logger.debug(f"Making POST request to: {self.url}")
            resp = requests.post(self.url, headers=self.headers, json=payload, timeout=30)
            
            request_duration = (datetime.now() - session_start_time).total_seconds()
            logger.info(f"Session request completed in {request_duration:.2f} seconds")
            logger.debug(f"Response status code: {resp.status_code}")
            logger.debug(f"Response headers: {dict(resp.headers)}")

            # Check if request was successful
            resp.raise_for_status()
            logger.debug("No HTTP errors raised for session start request")

            # Parse response
            try:
                data = resp.json()
                logger.debug(f"Session response data type: {type(data)}")
                logger.debug(f"Session response keys: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
                
                if "data" in data and "session_id" in data["data"]:
                    session_id = data["data"]["session_id"]
                    logger.info(f"Session started successfully with ID: {session_id}")
                    return session_id
                else:
                    logger.error(f"Unexpected response structure for session start: {data}")
                    raise ValueError("Invalid response structure from RAGFlow API")
                    
            except json.JSONDecodeError as e:
                logger.error(f"Failed to decode JSON response for session start: {e}")
                logger.error(f"Raw response content: {resp.text}")
                raise
                
        except requests.exceptions.Timeout:
            logger.error(f"Timeout occurred while starting session for materia: '{materia}'")
            raise
        except requests.exceptions.RequestException as e:
            logger.error(f"Request exception during session start: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error during session start: {e}", exc_info=True)
            raise

    def analyze_materia(self, materia: str, session_id: str):
        """Analyze a materia using the RAGFlow agent with an existing session"""
        logger.info(f"Starting analysis for materia: '{materia}' with session: {session_id}")
        
        analysis_start_time = datetime.now()
        
        try:
            payload = {
                "question": materia,
                "session_id": session_id,
                "stream": False
            }
            logger.debug(f"Analysis payload: {json.dumps(payload, indent=2)}")
            
            logger.debug(f"Making POST request to: {self.url}")
            resp = requests.post(self.url, headers=self.headers, json=payload, timeout=60)
            
            request_duration = (datetime.now() - analysis_start_time).total_seconds()
            logger.info(f"Analysis request completed in {request_duration:.2f} seconds")
            logger.debug(f"Response status code: {resp.status_code}")
            logger.debug(f"Response headers: {dict(resp.headers)}")

            # Check if request was successful
            resp.raise_for_status()
            logger.debug("No HTTP errors raised for analysis request")

            # Parse response
            try:
                data = resp.json()
                logger.debug(f"Analysis response data type: {type(data)}")
                logger.debug(f"Analysis response keys: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
                
                # Log response code if present
                if isinstance(data, dict) and "code" in data:
                    response_code = data["code"]
                    logger.info(f"RAGFlow API response code: {response_code}")
                    
                    if response_code == 0:
                        logger.info("Analysis completed successfully")
                    else:
                        logger.warning(f"RAGFlow API returned non-zero code: {response_code}")
                        if "message" in data:
                            logger.warning(f"RAGFlow API message: {data['message']}")
                
                logger.info(f"Analysis completed for materia: '{materia}'")
                return data
                
            except json.JSONDecodeError as e:
                logger.error(f"Failed to decode JSON response for analysis: {e}")
                logger.error(f"Raw response content: {resp.text}")
                raise
                
        except requests.exceptions.Timeout:
            logger.error(f"Timeout occurred while analyzing materia: '{materia}' with session: {session_id}")
            raise
        except requests.exceptions.RequestException as e:
            logger.error(f"Request exception during analysis: {e}")
            raise
        except Exception as e:
            logger.error(f"Unexpected error during analysis: {e}", exc_info=True)
            raise

    def _log_response_summary(self, response_data, operation):
        """Log a summary of the response data (helper method)"""
        try:
            if isinstance(response_data, dict):
                logger.debug(f"{operation} response summary:")
                logger.debug(f"  - Type: {type(response_data)}")
                logger.debug(f"  - Keys: {list(response_data.keys())}")
                
                if "data" in response_data:
                    data_section = response_data["data"]
                    logger.debug(f"  - Data section type: {type(data_section)}")
                    if isinstance(data_section, dict):
                        logger.debug(f"  - Data section keys: {list(data_section.keys())}")
                        
        except Exception as e:
            logger.warning(f"Failed to log response summary for {operation}: {e}")

    '''
    def gerar_palavrasChaves(self, materia: str):
        """Generate keywords for a materia (commented out method)"""
        logger.info(f"Generating keywords for materia: '{materia}'")

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