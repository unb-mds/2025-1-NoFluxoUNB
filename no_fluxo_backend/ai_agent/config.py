# config.py (Reading from environment variables)
import os
import logging
from datetime import datetime
from dotenv import load_dotenv

# Configure logging for this module
logger = logging.getLogger(__name__)

logger.info("="*50)
logger.info("CONFIGURATION MODULE INITIALIZATION")
logger.info(f"Started at: {datetime.now().isoformat()}")
logger.info("="*50)

# Load environment variables from .env file
logger.info("STEP 1: Searching for .env file")
dotenv_path = '.env'
parent_dotenv_path = '../.env'

logger.debug(f"Current working directory: {os.getcwd()}")
logger.debug(f"Checking for .env file at: {dotenv_path}")
logger.debug(f"Checking for .env file at: {parent_dotenv_path}")

env_file_found = False
env_file_path = None

if os.path.exists(parent_dotenv_path):
    env_file_path = parent_dotenv_path
    env_file_found = True
    logger.info(f"Found .env file in parent directory: {parent_dotenv_path}")
elif os.path.exists(dotenv_path):
    env_file_path = dotenv_path
    env_file_found = True
    logger.info(f"Found .env file in current directory: {dotenv_path}")
else:
    logger.warning(f".env file not found at either location:")
    logger.warning(f"  Current directory: {dotenv_path}")
    logger.warning(f"  Parent directory: {parent_dotenv_path}")
    logger.info("Will attempt to read from system environment variables")

if env_file_found:
    logger.info("STEP 2: Loading environment variables from .env file")
    logger.debug(f"Loading from: {env_file_path}")
    
    try:
        # Get file size for logging
        file_size = os.path.getsize(env_file_path)
        logger.debug(f".env file size: {file_size} bytes")
        
        # Load the environment variables
        load_dotenv(dotenv_path=env_file_path)
        logger.info("Environment variables loaded successfully from .env file")
        
        # Log some file metadata
        stat_info = os.stat(env_file_path)
        logger.debug(f".env file last modified: {datetime.fromtimestamp(stat_info.st_mtime).isoformat()}")
        
    except Exception as e:
        logger.error(f"Error loading .env file from {env_file_path}: {str(e)}")
        logger.error(f"Error type: {type(e).__name__}")
        logger.warning("Falling back to system environment variables")
else:
    logger.info("STEP 2: Skipping .env file loading (file not found)")

logger.info("STEP 3: Reading RAGFlow configuration from environment variables")

# Read configuration from environment variables with detailed logging
logger.debug("Attempting to read RAGFLOW_API_KEY from environment")
RAGFLOW_API_KEY = os.getenv('RAGFLOW_API_KEY')

logger.debug("Attempting to read RAGFLOW_BASE_URL from environment")
RAGFLOW_BASE_URL = os.getenv('RAGFLOW_BASE_URL')

logger.debug("Attempting to read RAGFLOW_AGENT_ID from environment")
RAGFLOW_AGENT_ID = os.getenv('RAGFLOW_AGENT_ID')

# Log configuration status (without exposing sensitive data)
logger.info("STEP 4: Validating configuration variables")
logger.info("Configuration status:")

if RAGFLOW_API_KEY:
    api_key_preview = f"{RAGFLOW_API_KEY[:8]}...{RAGFLOW_API_KEY[-4:]}" if len(RAGFLOW_API_KEY) > 12 else "***"
    logger.info(f"  RAGFLOW_API_KEY: SET (preview: {api_key_preview}, length: {len(RAGFLOW_API_KEY)})")
else:
    logger.warning("  RAGFLOW_API_KEY: NOT SET")

if RAGFLOW_BASE_URL:
    logger.info(f"  RAGFLOW_BASE_URL: SET ({RAGFLOW_BASE_URL})")
    # Validate URL format
    if RAGFLOW_BASE_URL.startswith(('http://', 'https://')):
        logger.debug("    URL format appears valid")
    else:
        logger.warning("    URL format may be invalid - should start with http:// or https://")
else:
    logger.warning("  RAGFLOW_BASE_URL: NOT SET")

if RAGFLOW_AGENT_ID:
    logger.info(f"  RAGFLOW_AGENT_ID: SET ({RAGFLOW_AGENT_ID}, length: {len(RAGFLOW_AGENT_ID)})")
    # Basic validation for agent ID format
    if len(RAGFLOW_AGENT_ID) >= 10:  # Assume minimum length
        logger.debug("    Agent ID length appears valid")
    else:
        logger.warning("    Agent ID may be too short")
else:
    logger.warning("  RAGFLOW_AGENT_ID: NOT SET")

# Verification to ensure all required variables are set
logger.info("STEP 5: Performing final validation")
missing_vars = []

if not RAGFLOW_API_KEY:
    missing_vars.append('RAGFLOW_API_KEY')
    logger.error("Missing required variable: RAGFLOW_API_KEY")
    
if not RAGFLOW_BASE_URL:
    missing_vars.append('RAGFLOW_BASE_URL')
    logger.error("Missing required variable: RAGFLOW_BASE_URL")
    
if not RAGFLOW_AGENT_ID:
    missing_vars.append('RAGFLOW_AGENT_ID')
    logger.error("Missing required variable: RAGFLOW_AGENT_ID")

if missing_vars:
    logger.error("="*50)
    logger.error("CONFIGURATION VALIDATION FAILED")
    logger.error("="*50)
    
    error_msg = (
        f"Error: Missing required configuration variables: {', '.join(missing_vars)}. "
        "Please check your .env file and ensure all RAGFlow variables are properly set."
    )
    
    logger.error(f"Missing variables: {', '.join(missing_vars)}")
    logger.error("Required variables for RAGFlow:")
    logger.error("  - RAGFLOW_API_KEY: Your RAGFlow API key")
    logger.error("  - RAGFLOW_BASE_URL: RAGFlow server base URL (e.g., http://localhost)")
    logger.error("  - RAGFLOW_AGENT_ID: Your RAGFlow agent identifier")
    
    if env_file_found:
        logger.error(f"Check your .env file at: {env_file_path}")
        logger.error("Ensure it contains all required variables in the format:")
        logger.error("  RAGFLOW_API_KEY=your_api_key_here")
        logger.error("  RAGFLOW_BASE_URL=http://localhost")
        logger.error("  RAGFLOW_AGENT_ID=your_agent_id_here")
    else:
        logger.error("No .env file found. Create one or set environment variables directly.")
    
    logger.error("="*50)
    raise ValueError(error_msg)

logger.info("="*50)
logger.info("CONFIGURATION VALIDATION SUCCESSFUL")
logger.info("All RAGFlow configuration variables loaded successfully")
logger.info("Configuration summary:")
logger.info(f"  API Key: {'SET' if RAGFLOW_API_KEY else 'NOT SET'}")
logger.info(f"  Base URL: {RAGFLOW_BASE_URL}")
logger.info(f"  Agent ID: {RAGFLOW_AGENT_ID}")
logger.info("="*50)

# Log additional environment info for debugging
logger.debug("Additional environment information:")
logger.debug(f"  Python version: {os.sys.version}")
logger.debug(f"  Platform: {os.name}")
logger.debug(f"  Current user: {os.getenv('USER', os.getenv('USERNAME', 'Unknown'))}")
logger.debug(f"  Environment variables count: {len(os.environ)}")

# Check for other potentially relevant environment variables
relevant_env_vars = ['NODE_ENV', 'AI_AGENT_PORT', 'FLASK_ENV', 'DEBUG']
logger.debug("Other relevant environment variables:")
for var in relevant_env_vars:
    value = os.getenv(var)
    if value:
        logger.debug(f"  {var}: {value}")
    else:
        logger.debug(f"  {var}: NOT SET")

logger.info("Configuration module initialization completed successfully")
