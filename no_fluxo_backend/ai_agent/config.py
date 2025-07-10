# config.py (Reading from environment variables)
import os
import logging
from dotenv import load_dotenv

# Configure logging for this module
logger = logging.getLogger(__name__)

# Load environment variables from .env file
logger.info("Loading environment variables from .env file")
dotenv_path = '.env'

if os.path.exists(dotenv_path):
    logger.info(f"Found .env file at: {dotenv_path}")
    load_dotenv(dotenv_path=dotenv_path)
    logger.info("Environment variables loaded successfully")
else:
    logger.warning(f".env file not found at: {dotenv_path}")
    logger.info("Attempting to load from system environment variables")

# Read configuration from environment variables
logger.debug("Reading RAGFlow configuration from environment variables")

RAGFLOW_API_KEY = os.getenv('RAGFLOW_API_KEY')
RAGFLOW_BASE_URL = os.getenv('RAGFLOW_BASE_URL')
RAGFLOW_AGENT_ID = os.getenv('RAGFLOW_AGENT_ID')

# Log configuration status (without exposing sensitive data)
logger.info(f"RAGFLOW_API_KEY: {'SET' if RAGFLOW_API_KEY else 'NOT SET'}")
logger.info(f"RAGFLOW_BASE_URL: {RAGFLOW_BASE_URL if RAGFLOW_BASE_URL else 'NOT SET'}")
logger.info(f"RAGFLOW_AGENT_ID: {'SET' if RAGFLOW_AGENT_ID else 'NOT SET'}")

# Verification to ensure all required variables are set
missing_vars = []
if not RAGFLOW_API_KEY:
    missing_vars.append('RAGFLOW_API_KEY')
if not RAGFLOW_BASE_URL:
    missing_vars.append('RAGFLOW_BASE_URL')
if not RAGFLOW_AGENT_ID:
    missing_vars.append('RAGFLOW_AGENT_ID')

if missing_vars:
    error_msg = (
        f"Error: Missing required configuration variables: {', '.join(missing_vars)}. "
        "Please check your .env file and ensure all RAGFlow variables are properly set."
    )
    logger.error(error_msg)
    raise ValueError(error_msg)

logger.info("All RAGFlow configuration variables loaded successfully")
