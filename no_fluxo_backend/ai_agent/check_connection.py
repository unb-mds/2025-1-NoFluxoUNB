# check_connection.py
import logging
import os
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='[%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(),  # Console output
        logging.FileHandler('../logs/connection_test.log', mode='a')  # Log file
    ]
)

logger = logging.getLogger(__name__)

logger.info("="*60)
logger.info("RAGFlow CONNECTION TEST STARTED")
logger.info(f"Test started at: {datetime.now().isoformat()}")
logger.info("="*60)

try:
    logger.info("STEP 1: Loading configuration variables from config module")
    logger.debug("Attempting to import RAGFlow configuration")
    
    from config import RAGFLOW_API_KEY, RAGFLOW_BASE_URL, RAGFLOW_AGENT_ID
    logger.info("Configuration import successful")
    
    logger.info("STEP 2: Validating configuration variables")
    logger.debug("Checking if all required configuration variables are set")
    
    # Check each variable individually
    missing_vars = []
    
    if not RAGFLOW_API_KEY:
        logger.error("RAGFLOW_API_KEY is not set or empty")
        missing_vars.append('RAGFLOW_API_KEY')
    else:
        logger.debug("RAGFLOW_API_KEY: SET (length: {})".format(len(RAGFLOW_API_KEY)))
    
    if not RAGFLOW_BASE_URL:
        logger.error("RAGFLOW_BASE_URL is not set or empty")
        missing_vars.append('RAGFLOW_BASE_URL')
    else:
        logger.info(f"RAGFLOW_BASE_URL: {RAGFLOW_BASE_URL}")
    
    if not RAGFLOW_AGENT_ID:
        logger.error("RAGFLOW_AGENT_ID is not set or empty")
        missing_vars.append('RAGFLOW_AGENT_ID')
    else:
        logger.info(f"RAGFLOW_AGENT_ID: {RAGFLOW_AGENT_ID}")

    if missing_vars:
        logger.error("="*50)
        logger.error("CONFIGURATION ERROR: Missing required variables")
        logger.error(f"Missing variables: {', '.join(missing_vars)}")
        logger.error("Please check your .env file and ensure all RAGFlow variables are properly set")
        logger.error("="*50)
        exit(1)
    else:
        logger.info("Configuration validation successful - all variables are set")

    logger.info("STEP 3: Importing RAGFlow client")
    logger.debug("Attempting to import RagflowClient from ragflow_agent_client module")
    
    from ragflow_agent_client import RagflowClient
    logger.info("RAGFlow client import successful")

    logger.info("STEP 4: Initializing RAGFlow client")
    logger.debug("Creating RagflowClient instance")
    
    client = RagflowClient()
    logger.info("RAGFlow client initialized successfully")
    logger.debug(f"Client endpoint: {client.url}")
    
    logger.info("STEP 5: Testing connection with RAGFlow")
    logger.debug("Preparing test message for connection validation")
    
    test_message = "Este é um teste de conexão para validar a API do RAGFlow."
    logger.info(f"Test message: '{test_message}'")
    
    logger.debug("Starting session for connection test")
    session_start_time = datetime.now()
    
    try:
        session_id = client.start_session(test_message)
        session_duration = (datetime.now() - session_start_time).total_seconds()
        
        logger.info(f"Session creation successful:")
        logger.info(f"  Session ID: {session_id}")
        logger.info(f"  Duration: {session_duration:.2f} seconds")
        
        logger.debug("Testing analysis with the created session")
        analysis_start_time = datetime.now()
        
        response = client.analyze_materia(test_message, session_id)
        analysis_duration = (datetime.now() - analysis_start_time).total_seconds()
        
        logger.info(f"Analysis completed successfully:")
        logger.info(f"  Duration: {analysis_duration:.2f} seconds")
        logger.debug(f"Response type: {type(response)}")
        logger.debug(f"Response keys: {list(response.keys()) if isinstance(response, dict) else 'Not a dict'}")
        
        if isinstance(response, dict) and "code" in response:
            response_code = response.get("code")
            logger.info(f"API response code: {response_code}")
            
            if response_code == 0:
                logger.info("API response indicates success")
            else:
                logger.warning(f"API returned non-zero code: {response_code}")
                if "message" in response:
                    logger.warning(f"API message: {response['message']}")

        logger.info("="*50)
        logger.info("CONNECTION TEST RESULT: SUCCESS")
        logger.info("RAGFlow API is responding correctly")
        logger.info(f"Total test time: {(datetime.now() - session_start_time).total_seconds():.2f} seconds")
        logger.info("="*50)
        
        # Log a sample of the response (safely)
        if isinstance(response, dict):
            logger.debug("Sample response structure:")
            for key, value in list(response.items())[:3]:  # Show first 3 keys
                if isinstance(value, str) and len(value) > 100:
                    logger.debug(f"  {key}: '{value[:100]}...' (truncated)")
                else:
                    logger.debug(f"  {key}: {value}")
    
    except Exception as api_error:
        logger.error("="*50)
        logger.error("CONNECTION TEST RESULT: API ERROR")
        logger.error(f"Error during API communication: {str(api_error)}")
        logger.error(f"Error type: {type(api_error).__name__}")
        logger.error("="*50)
        logger.debug("Full stack trace:", exc_info=True)
        exit(1)

except ImportError as import_error:
    logger.error("="*50)
    logger.error("CONNECTION TEST RESULT: IMPORT ERROR")
    logger.error(f"Failed to import required modules: {str(import_error)}")
    logger.error("This could indicate:")
    logger.error("  1. Missing dependencies")
    logger.error("  2. Configuration file issues")
    logger.error("  3. Module not found in path")
    logger.error("="*50)
    logger.debug("Full stack trace:", exc_info=True)
    exit(1)

except Exception as e:
    logger.error("="*50)
    logger.error("CONNECTION TEST RESULT: UNEXPECTED ERROR")
    logger.error(f"Unexpected exception during test: {str(e)}")
    logger.error(f"Error type: {type(e).__name__}")
    logger.error(f"Test duration before error: {(datetime.now() - datetime.now()).total_seconds():.2f} seconds")
    logger.error("="*50)
    logger.debug("Full stack trace:", exc_info=True)
    exit(1)

finally:
    logger.info("="*60)
    logger.info("RAGFlow CONNECTION TEST COMPLETED")
    logger.info(f"Test ended at: {datetime.now().isoformat()}")
    logger.info("="*60)