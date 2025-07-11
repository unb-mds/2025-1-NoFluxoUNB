# app.py (Versão com Flask)
import unicodedata
import argparse
import os
import logging
from datetime import datetime
from dotenv import load_dotenv
from flask import Flask, request, jsonify
from ragflow_agent_client import RagflowClient
from visualizaJsonMateriasAssociadas import gerar_texto_ranking
from flask_cors import CORS

# Load environment variables
# Try to load from parent directory first, then current directory
logger = logging.getLogger(__name__)
logger.info("Starting environment variable loading process")

if os.path.exists('../.env'):
    logger.info("Found .env file in parent directory: '../.env'")
    load_dotenv(dotenv_path='../.env')
    logger.info("Successfully loaded environment variables from '../.env'")
elif os.path.exists('.env'):
    logger.info("Found .env file in current directory: './.env'")
    load_dotenv(dotenv_path='.env')
    logger.info("Successfully loaded environment variables from './.env'")
else:
    logger.warning(".env file not found at: .env or ../.env")
    logger.info("Continuing without .env file - expecting environment variables to be set by Docker or system")

# Log key environment variables (safely)
node_env = os.getenv('NODE_ENV', 'not_set')
ai_agent_port = os.getenv('AI_AGENT_PORT', 'not_set')
logger.info(f"Environment configuration: NODE_ENV={node_env}, AI_AGENT_PORT={ai_agent_port}")

# --- Configuração de Logging ---
def setup_logging():
    """Configure logging for the application"""
    logger.info("FUNCTION ENTRY: setup_logging()")
    
    node_env = os.getenv('NODE_ENV')
    log_level = logging.DEBUG if node_env == 'development' else logging.INFO
    logger.info(f"Determined log level: {logging.getLevelName(log_level)} based on NODE_ENV: {node_env}")
    
    # Create logs directory if it doesn't exist
    log_dir = '../logs'
    logger.debug(f"Attempting to create log directory: {log_dir}")
    
    if not os.path.exists(log_dir):
        try:
            logger.debug(f"Log directory {log_dir} doesn't exist, creating it")
            os.makedirs(log_dir)
            logger.info(f"Successfully created log directory: {log_dir}")
        except PermissionError as e:
            logger.warning(f"Permission denied creating {log_dir}: {e}")
            # Fallback to current directory if we can't create in parent
            log_dir = './logs'
            logger.info(f"Falling back to current directory log path: {log_dir}")
            if not os.path.exists(log_dir):
                logger.debug(f"Creating fallback log directory: {log_dir}")
                os.makedirs(log_dir, exist_ok=True)
                logger.info(f"Successfully created fallback log directory: {log_dir}")
    else:
        logger.debug(f"Log directory {log_dir} already exists")
    
    # Configure logging format
    log_format = '\b[%(levelname)s] %(message)s'
    logger.debug(f"Using log format: {log_format}")
    
    # Determine log file path
    log_file_path = f'{log_dir}/ai_agent.log'
    logger.info(f"Log file will be written to: {log_file_path}")
    
    # Configure root logger
    try:
        logging.basicConfig(
            level=log_level,
            format=log_format,
            handlers=[
                logging.FileHandler(log_file_path),
                logging.StreamHandler()  # Console output
            ]
        )
        logger.info("Root logger configured successfully with file and console handlers")
    except Exception as e:
        logger.error(f"Failed to configure root logger: {e}")
        raise
    
    # Get logger for this module
    module_logger = logging.getLogger(__name__)
    module_logger.info("Module logger initialized successfully")
    logger.info("FUNCTION EXIT: setup_logging() - completed successfully")
    return module_logger

# Initialize logger
logger = setup_logging()
logger.info("Main application logger initialized")

# --- Funções e Lógica de Negócio (movidas ou importadas) ---

def remover_acentos_nativo(texto: str) -> str:
    """
    Normaliza o texto para o formato NFD, que separa o caractere do acento,
    e depois remove os caracteres de combinação (acentos).
    """
    logger.debug(f"FUNCTION ENTRY: remover_acentos_nativo(texto='{texto}', type={type(texto)})")
    
    try:
        # Input validation
        if not isinstance(texto, str):
            logger.warning(f"Invalid input type: expected str, got {type(texto)}")
            logger.warning(f"Input value: {repr(texto)}")
            logger.debug("FUNCTION EXIT: remover_acentos_nativo() - returning empty string due to invalid input type")
            return ""
        
        if not texto:
            logger.debug("Input text is empty, returning empty string")
            logger.debug("FUNCTION EXIT: remover_acentos_nativo() - returning empty string for empty input")
            return ""
        
        logger.debug(f"Starting accent removal process for text: '{texto}' (length: {len(texto)})")
        
        # Step 1: Normalize to NFD
        logger.debug("Step 1: Normalizing text to NFD format")
        texto_normalizado = unicodedata.normalize('NFD', texto)
        logger.debug(f"NFD normalized text: '{texto_normalizado}' (length: {len(texto_normalizado)})")
        
        # Step 2: Remove combining characters (accents)
        logger.debug("Step 2: Removing combining characters (accents)")
        texto_sem_acento = "".join(c for c in texto_normalizado if not unicodedata.combining(c))
        logger.debug(f"Text after accent removal: '{texto_sem_acento}' (length: {len(texto_sem_acento)})")
        
        # Log the transformation result
        if texto != texto_sem_acento:
            logger.info(f"Text transformation successful: '{texto}' -> '{texto_sem_acento}'")
        else:
            logger.debug("No accent removal was needed (text unchanged)")
        
        logger.debug("FUNCTION EXIT: remover_acentos_nativo() - completed successfully")
        return texto_sem_acento
    
    except Exception as e:
        logger.error(f"Unexpected error in accent removal for text '{texto}': {str(e)}")
        logger.error(f"Error type: {type(e).__name__}")
        logger.debug("FUNCTION EXIT: remover_acentos_nativo() - returning empty string due to error", exc_info=True)
        return ""

# --- Configuração do Servidor Flask ---

logger.info("Initializing Flask application")
app = Flask(__name__)
logger.info("Flask application instance created")

logger.info("Configuring CORS for Flask application")
CORS(app)
logger.info("CORS configuration completed")

# Log Flask app initialization
logger.info("Flask application and CORS initialized successfully")

# --- Definição do Endpoint da API ---

@app.route('/assistente', methods=['POST'])
def analisar_materia_endpoint():
    """
    Endpoint da API que recebe um JSON com a matéria, a processa
    e retorna o ranking das disciplinas relacionadas.
    """
    request_start_time = datetime.now()
    client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', 'Unknown'))
    request_id = f"req_{request_start_time.strftime('%Y%m%d_%H%M%S_%f')}"
    
    logger.info("="*60)
    logger.info(f"[{request_id}] NEW REQUEST START")
    logger.info(f"[{request_id}] Client IP: {client_ip}")
    logger.info(f"[{request_id}] Timestamp: {request_start_time.isoformat()}")
    logger.info(f"[{request_id}] Method: {request.method}")
    logger.info(f"[{request_id}] URL: {request.url}")
    logger.info(f"[{request_id}] User-Agent: {request.headers.get('User-Agent', 'Unknown')}")
    logger.info("="*60)
    
    try:
        # 1. Extrair os dados da requisição
        logger.info(f"[{request_id}] STEP 1: Extracting request data")
        logger.debug(f"[{request_id}] Request headers: {dict(request.headers)}")
        logger.debug(f"[{request_id}] Request content type: {request.content_type}")
        logger.debug(f"[{request_id}] Request content length: {request.content_length}")

        dados_requisicao = request.get_json()
        logger.debug(f"[{request_id}] Raw request data type: {type(dados_requisicao)}")

        if dados_requisicao is None:
            logger.warning(f"[{request_id}] Request body is empty or not valid JSON")
            logger.warning(f"[{request_id}] Raw request data: {request.get_data()}")
            return jsonify({"erro": "Corpo da requisição deve ser um JSON válido."}), 400

        logger.debug(f"[{request_id}] Request JSON keys: {list(dados_requisicao.keys()) if isinstance(dados_requisicao, dict) else 'Not a dict'}")

        if 'materia' not in dados_requisicao:
            logger.warning(f"[{request_id}] Missing 'materia' field in request")
            logger.warning(f"[{request_id}] Available fields: {list(dados_requisicao.keys()) if isinstance(dados_requisicao, dict) else 'None'}")
            return jsonify({"erro": "O campo 'materia' é obrigatório no corpo da requisição JSON."}), 400

        materia_original = dados_requisicao['materia']
        logger.info(f"[{request_id}] Extracted materia: '{materia_original}' (type: {type(materia_original)}, length: {len(str(materia_original))})")

        if not materia_original or not materia_original.strip():
            logger.warning(f"[{request_id}] Empty 'materia' field provided: '{materia_original}'")
            return jsonify({"erro": "O campo 'materia' não pode estar vazio."}), 400

        logger.info(f"[{request_id}] STEP 1 COMPLETED: Request data extraction successful")

        # 2. Pré-processamento do input
        logger.info(f"[{request_id}] STEP 2: Starting input preprocessing")
        logger.debug(f"[{request_id}] Original materia before preprocessing: '{materia_original}'")
        
        materia_processada = remover_acentos_nativo(materia_original).upper()
        logger.info(f"[{request_id}] Text preprocessing completed:")
        logger.info(f"[{request_id}]   Original: '{materia_original}'")
        logger.info(f"[{request_id}]   Processed: '{materia_processada}'")
        logger.debug(f"[{request_id}] Character count - Original: {len(materia_original)}, Processed: {len(materia_processada)}")

        logger.info(f"[{request_id}] STEP 2 COMPLETED: Input preprocessing successful")

        # 3. Executar a lógica de análise
        logger.info(f"[{request_id}] STEP 3: Starting RAGFlow analysis")
        logger.debug(f"[{request_id}] Initializing RAGFlow client")
        
        client = RagflowClient()
        logger.info(f"[{request_id}] RAGFlow client initialized successfully")
        
        logger.info(f"[{request_id}] STEP 3.1: Starting RAGFlow session")
        session_start_time = datetime.now()
        
        session_id = client.start_session(materia_processada)
        session_duration = (datetime.now() - session_start_time).total_seconds()
        logger.info(f"[{request_id}] RAGFlow session started successfully:")
        logger.info(f"[{request_id}]   Session ID: {session_id}")
        logger.info(f"[{request_id}]   Session creation time: {session_duration:.2f} seconds")
        
        logger.info(f"[{request_id}] STEP 3.2: Starting materia analysis")
        analysis_start_time = datetime.now()
        
        resultado_agente = client.analyze_materia(materia_processada, session_id)
        analysis_duration = (datetime.now() - analysis_start_time).total_seconds()
        
        logger.info(f"[{request_id}] RAGFlow analysis completed:")
        logger.info(f"[{request_id}]   Analysis time: {analysis_duration:.2f} seconds")
        logger.debug(f"[{request_id}] Raw agent result type: {type(resultado_agente)}")
        logger.debug(f"[{request_id}] Raw agent result keys: {list(resultado_agente.keys()) if isinstance(resultado_agente, dict) else 'Not a dict'}")

        # Check for API errors
        result_code = resultado_agente.get("code")
        logger.debug(f"[{request_id}] RAGFlow API response code: {result_code}")
        
        if result_code != 0:
            # Se a API do RAGFlow retornar um erro, repassa a mensagem.
            mensagem_erro = resultado_agente.get('message', 'Erro desconhecido na API do agente.')
            logger.error(f"[{request_id}] RAGFlow API error:")
            logger.error(f"[{request_id}]   Code: {result_code}")
            logger.error(f"[{request_id}]   Message: {mensagem_erro}")
            logger.error(f"[{request_id}]   Full response: {resultado_agente}")
            return jsonify({"erro": f"Erro na API do agente: {mensagem_erro}"}), 500

        logger.info(f"[{request_id}] STEP 3 COMPLETED: RAGFlow analysis successful")

        # 4. Formatar a resposta final
        logger.info(f"[{request_id}] STEP 4: Starting response formatting")
        format_start_time = datetime.now()
        
        logger.debug(f"[{request_id}] Calling gerar_texto_ranking with agent result")
        resposta_formatada = gerar_texto_ranking(resultado_agente)
        
        format_duration = (datetime.now() - format_start_time).total_seconds()
        logger.info(f"[{request_id}] Response formatting completed:")
        logger.info(f"[{request_id}]   Formatting time: {format_duration:.2f} seconds")
        logger.debug(f"[{request_id}] Formatted response type: {type(resposta_formatada)}")
        logger.debug(f"[{request_id}] Formatted response length: {len(str(resposta_formatada))}")
        
        logger.info(f"[{request_id}] STEP 4 COMPLETED: Response formatting successful")
        
        # Calculate total request duration
        request_duration = (datetime.now() - request_start_time).total_seconds()
        logger.info(f"[{request_id}] REQUEST COMPLETED SUCCESSFULLY:")
        logger.info(f"[{request_id}]   Total request time: {request_duration:.2f} seconds")
        logger.info(f"[{request_id}]   Session creation: {session_duration:.2f}s")
        logger.info(f"[{request_id}]   Analysis: {analysis_duration:.2f}s")
        logger.info(f"[{request_id}]   Formatting: {format_duration:.2f}s")
        
        # 5. Retornar a resposta formatada como JSON
        logger.info(f"[{request_id}] Sending successful response to client")
        return jsonify({"resultado": resposta_formatada})

    except Exception as e:
        # Captura qualquer outro erro durante o processo
        request_duration = (datetime.now() - request_start_time).total_seconds()
        logger.error(f"[{request_id}] UNEXPECTED ERROR occurred:")
        logger.error(f"[{request_id}]   Error after: {request_duration:.2f} seconds")
        logger.error(f"[{request_id}]   Error type: {type(e).__name__}")
        logger.error(f"[{request_id}]   Error message: {str(e)}")
        logger.error(f"[{request_id}]   Client IP: {client_ip}")
        logger.error(f"[{request_id}]   Original materia: {locals().get('materia_original', 'Not available')}")
        logger.error(f"[{request_id}]   Processed materia: {locals().get('materia_processada', 'Not available')}")
        logger.error(f"[{request_id}]   Session ID: {locals().get('session_id', 'Not available')}")
        logger.error(f"[{request_id}]   Full stack trace:", exc_info=True)
        return jsonify({"erro": f"Ocorreu um erro interno no servidor: {str(e)}"}), 500

@app.route('/', methods=['GET'])
def root_health_check():
    """Root health check endpoint"""
    logger.debug("ENDPOINT: Root health check requested")
    logger.debug(f"Request from: {request.environ.get('REMOTE_ADDR', 'Unknown')}")
    
    response_data = {
        "status": "healthy",
        "service": "AI Agent",
        "message": "AI Agent server is running",
        "timestamp": datetime.now().isoformat()
    }
    
    logger.debug(f"Sending health check response: {response_data}")
    return jsonify(response_data)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    logger.debug("ENDPOINT: Health check requested")
    logger.debug(f"Request from: {request.environ.get('REMOTE_ADDR', 'Unknown')}")
    
    response_data = {
        "status": "healthy",
        "service": "AI Agent",
        "timestamp": datetime.now().isoformat()
    }
    
    logger.debug(f"Sending health check response: {response_data}")
    return response_data

@app.before_request
def log_request_info():
    """Log information about each request"""
    logger.debug(f"INCOMING REQUEST: {request.method} {request.url}")
    logger.debug(f"  Client: {request.environ.get('REMOTE_ADDR', 'Unknown')}")
    logger.debug(f"  User-Agent: {request.headers.get('User-Agent', 'Unknown')}")
    logger.debug(f"  Content-Type: {request.content_type}")

@app.after_request
def log_response_info(response):
    """Log information about each response"""
    logger.debug(f"OUTGOING RESPONSE: {response.status_code} for {request.method} {request.url}")
    logger.debug(f"  Response size: {response.content_length or 'Unknown'}")
    return response

# --- Configuração de Argumentos da Linha de Comando ---

def parse_arguments():
    """
    Parse command line arguments for the Flask application.
    """
    logger.info("FUNCTION ENTRY: parse_arguments()")
    logger.debug("Creating argument parser")
    
    parser = argparse.ArgumentParser(description='AI Agent Flask Server')
    
    # Default values from environment
    default_port = int(os.getenv('AI_AGENT_PORT', 5000))
    default_debug = os.getenv('NODE_ENV') == 'development'
    default_log_level = 'DEBUG' if os.getenv('NODE_ENV') == 'development' else 'INFO'
    
    logger.debug(f"Default arguments from environment:")
    logger.debug(f"  Port: {default_port}")
    logger.debug(f"  Debug: {default_debug}")
    logger.debug(f"  Log level: {default_log_level}")
    
    parser.add_argument(
        '--port', '-p',
        type=int,
        default=default_port,
        help='Port to run the server on (default: from AI_AGENT_PORT env var or 5000)'
    )
    parser.add_argument(
        '--host',
        type=str,
        default='0.0.0.0',
        help='Host to run the server on (default: 0.0.0.0)'
    )
    parser.add_argument(
        '--debug',
        action='store_true',
        default=default_debug,
        help='Run in debug mode (default: based on NODE_ENV env var)'
    )
    parser.add_argument(
        '--log-level',
        type=str,
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default=default_log_level,
        help='Set the logging level'
    )
    
    logger.debug("Parsing command line arguments")
    args = parser.parse_args()
    
    logger.info(f"Parsed arguments:")
    logger.info(f"  Host: {args.host}")
    logger.info(f"  Port: {args.port}")
    logger.info(f"  Debug: {args.debug}")
    logger.info(f"  Log level: {args.log_level}")
    
    logger.info("FUNCTION EXIT: parse_arguments() - completed successfully")
    return args

# --- Execução do Servidor ---


if __name__ == '__main__':
    logger.info("="*60)
    logger.info("MAIN EXECUTION START")
    logger.info("="*60)
    
    logger.info("Parsing command line arguments")
    args = parse_arguments()
    

    # Update log level if specified via command line
    if hasattr(args, 'log_level'):
        old_level = logging.getLogger().level
        new_level = getattr(logging, args.log_level)
        logger.info(f"Updating log level from {logging.getLevelName(old_level)} to {logging.getLevelName(new_level)}")
        
        logging.getLogger().setLevel(new_level)
        logger.setLevel(new_level)
        logger.info("Log level updated successfully")
    
    logger.info("="*50)
    logger.info("AI AGENT SERVER STARTUP")
    logger.info("="*50)
    logger.info(f"Host: {args.host}")
    logger.info(f"Port: {args.port}")
    logger.info(f"Debug mode: {args.debug}")
    logger.info(f"Log level: {logging.getLevelName(logging.getLogger().level)}")
    logger.info(f"Environment: {os.getenv('NODE_ENV', 'unknown')}")
    logger.info(f"Process ID: {os.getpid()}")
    logger.info(f"Working directory: {os.getcwd()}")
    logger.info("="*50)
    
    try:
        logger.info("Starting Flask application server")
        logger.debug("Flask server configuration:")
        logger.debug(f"  Host: {args.host} (0.0.0.0 makes server accessible on local network)")
        logger.debug(f"  Port: {args.port}")
        logger.debug(f"  Debug mode: {args.debug}")
        logger.debug("Note: For production, use a WSGI server like Gunicorn or Waitress")
        
        # O host '0.0.0.0' torna o servidor acessível na sua rede local.
        # Para produção, use um servidor WSGI como Gunicorn ou Waitress.
        app.run(host=args.host, port=args.port, debug=args.debug)
        
    except Exception as e:
        logger.error("="*50)
        logger.error("FATAL ERROR: Failed to start server")
        logger.error("="*50)
        logger.error(f"Error type: {type(e).__name__}")
        logger.error(f"Error message: {str(e)}")
        logger.error(f"Server configuration attempted:")
        logger.error(f"  Host: {args.host}")
        logger.error(f"  Port: {args.port}")
        logger.error(f"  Debug: {args.debug}")
        logger.error("Full stack trace:", exc_info=True)
        logger.error("="*50)
        exit(1)