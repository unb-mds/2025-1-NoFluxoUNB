<<<<<<< HEAD
<<<<<<< HEAD:no_fluxo_backend/ai_agent/app.py
=======
>>>>>>> e230dc46013b11b69eea88dddfc80240c5a9aa54
# app.py (Versão com Flask)
import unicodedata
import argparse
import os
import logging
from datetime import datetime
from dotenv import load_dotenv
from flask import Flask, request, jsonify
from .ragflow_agent_client import RagflowClient
from .visualizaJsonMateriasAssociadas import gerar_texto_ranking
from flask_cors import CORS

# Load environment variables
# Try to load from parent directory first, then current directory
if os.path.exists('../.env'):
    load_dotenv(dotenv_path='../.env')
elif os.path.exists('.env'):
    load_dotenv(dotenv_path='.env')
else:
    print(".env file not found at: .env")
    # Continue without .env file - environment variables should be set by Docker

# --- Configuração de Logging ---
def setup_logging():
    """Configure logging for the application"""
    log_level = logging.DEBUG if os.getenv('NODE_ENV') == 'development' else logging.INFO
    
    # Create logs directory if it doesn't exist
    log_dir = '../logs'
    if not os.path.exists(log_dir):
        try:
            os.makedirs(log_dir)
        except PermissionError:
            # Fallback to current directory if we can't create in parent
            log_dir = './logs'
            if not os.path.exists(log_dir):
                os.makedirs(log_dir, exist_ok=True)
    
    # Configure logging format
    log_format = '\b[%(levelname)s] %(message)s'
    
    # Configure root logger
    logging.basicConfig(
        level=log_level,
        format=log_format,
        handlers=[
            logging.FileHandler(f'{log_dir}/ai_agent.log'),
            logging.StreamHandler()  # Console output
        ]
    )
    
    # Get logger for this module
    logger = logging.getLogger(__name__)
    logger.info("Logging initialized successfully")
    return logger

# Initialize logger
logger = setup_logging()

# --- Funções e Lógica de Negócio (movidas ou importadas) ---

def remover_acentos_nativo(texto: str) -> str:
    """
    Normaliza o texto para o formato NFD, que separa o caractere do acento,
    e depois remove os caracteres de combinação (acentos).
    """
    try:
        if not isinstance(texto, str):
            logger.warning(f"Input is not a string: {type(texto)}, returning empty string")
            return ""
        
        logger.debug(f"Removing accents from text: '{texto}'")
        texto_normalizado = unicodedata.normalize('NFD', texto)
        texto_sem_acento = "".join(c for c in texto_normalizado if not unicodedata.combining(c))
        logger.debug(f"Text after accent removal: '{texto_sem_acento}'")
        return texto_sem_acento
    
    except Exception as e:
        logger.error(f"Error removing accents from text '{texto}': {str(e)}")
        return ""

# --- Configuração do Servidor Flask ---

app = Flask(__name__)
CORS(app)

# Log Flask app initialization
logger.info("Flask application and CORS initialized")

# --- Definição do Endpoint da API ---

@app.route('/assistente', methods=['POST'])
def analisar_materia_endpoint():
    """
    Endpoint da API que recebe um JSON com a matéria, a processa
    e retorna o ranking das disciplinas relacionadas.
    """
    request_start_time = datetime.now()
    client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', 'Unknown'))
    
    logger.info(f"[REQUEST START] New request from IP: {client_ip}")
    
    try:
        # 1. Extrair os dados da requisição
        logger.debug("Extracting data from request")
        dados_requisicao = request.get_json()

        if dados_requisicao is None:
            logger.warning("Request body is empty or not valid JSON")
            return jsonify({"erro": "Corpo da requisição deve ser um JSON válido."}), 400

        if 'materia' not in dados_requisicao:
            logger.warning("Missing 'materia' field in request")
            return jsonify({"erro": "O campo 'materia' é obrigatório no corpo da requisição JSON."}), 400

        materia_original = dados_requisicao['materia']
        logger.info(f"Received materia: '{materia_original}'")

        if not materia_original or not materia_original.strip():
            logger.warning("Empty 'materia' field provided")
            return jsonify({"erro": "O campo 'materia' não pode estar vazio."}), 400

        # 2. Pré-processamento do input
        logger.debug("Starting text preprocessing")
        materia_processada = remover_acentos_nativo(materia_original).upper()
        logger.info(f"Materia processed: '{materia_original}' -> '{materia_processada}'")

        # 3. Executar a lógica de análise
        logger.info("Starting analysis with RAGFlow client")
        client = RagflowClient()
        
        logger.debug("Starting session with RAGFlow")
        session_id = client.start_session(materia_processada)
        logger.info(f"Session started successfully with ID: {session_id}")
        
        logger.debug("Analyzing materia with RAGFlow agent")
        resultado_agente = client.analyze_materia(materia_processada, session_id)
        logger.debug(f"Raw agent result received: {type(resultado_agente)}")

        if resultado_agente.get("code") != 0:
            # Se a API do RAGFlow retornar um erro, repassa a mensagem.
            mensagem_erro = resultado_agente.get('message', 'Erro desconhecido na API do agente.')
            logger.error(f"RAGFlow API error (code: {resultado_agente.get('code')}): {mensagem_erro}")
            return jsonify({"erro": f"Erro na API do agente: {mensagem_erro}"}), 500

        # 4. Formatar a resposta final
        logger.debug("Formatting response")
        resposta_formatada = gerar_texto_ranking(resultado_agente)
        logger.info("Response formatted successfully")
        
        # Calculate request duration
        request_duration = (datetime.now() - request_start_time).total_seconds()
        logger.info(f"[REQUEST SUCCESS] Request completed in {request_duration:.2f} seconds")
        
        # 5. Retornar a resposta formatada como JSON
        return jsonify({"resultado": resposta_formatada})

    except Exception as e:
        # Captura qualquer outro erro durante o processo
        request_duration = (datetime.now() - request_start_time).total_seconds()
        logger.error(f"[REQUEST ERROR] Unexpected error after {request_duration:.2f} seconds: {str(e)}", exc_info=True)
        return jsonify({"erro": f"Ocorreu um erro interno no servidor: {str(e)}"}), 500

@app.route('/', methods=['GET'])
def root_health_check():
    """Root health check endpoint"""
    logger.debug("Root health check requested")
    return jsonify({
        "status": "healthy",
        "service": "AI Agent",
        "message": "AI Agent server is running",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    logger.debug("Health check requested")
    return jsonify({
        "status": "healthy",
        "service": "AI Agent",
        "timestamp": datetime.now().isoformat()
    })

@app.before_request
def log_request_info():
    """Log information about each request"""
    logger.debug(f"Request: {request.method} {request.url} from {request.environ.get('REMOTE_ADDR', 'Unknown')}")

@app.after_request
def log_response_info(response):
    """Log information about each response"""
    logger.debug(f"Response: {response.status_code} for {request.method} {request.url}")
    return response

# --- Configuração de Argumentos da Linha de Comando ---

def parse_arguments():
    """
    Parse command line arguments for the Flask application.
    """
    parser = argparse.ArgumentParser(description='AI Agent Flask Server')
    parser.add_argument(
        '--port', '-p',
        type=int,
        default=int(os.getenv('AI_AGENT_PORT', 5000)),
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
        default=os.getenv('NODE_ENV') == 'development',
        help='Run in debug mode (default: based on NODE_ENV env var)'
    )
    parser.add_argument(
        '--log-level',
        type=str,
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default='DEBUG' if os.getenv('NODE_ENV') == 'development' else 'INFO',
        help='Set the logging level'
    )
    return parser.parse_args()

# --- Execução do Servidor ---


if __name__ == '__main__':
    args = parse_arguments()
    

    # Update log level if specified via command line
    if hasattr(args, 'log_level'):
        logging.getLogger().setLevel(getattr(logging, args.log_level))
        logger.setLevel(getattr(logging, args.log_level))
    
    logger.info("="*50)
    logger.info("AI AGENT SERVER STARTUP")
    logger.info("="*50)
    logger.info(f"Host: {args.host}")
    logger.info(f"Port: {args.port}")
    logger.info(f"Debug mode: {args.debug}")
    logger.info(f"Log level: {logging.getLogger().level}")
    logger.info(f"Environment: {os.getenv('NODE_ENV', 'unknown')}")
    logger.info("="*50)
    
    try:
        # O host '0.0.0.0' torna o servidor acessível na sua rede local.
        # Para produção, use um servidor WSGI como Gunicorn ou Waitress.
        app.run(host=args.host, port=args.port, debug=args.debug)
    except Exception as e:
        logger.error(f"Failed to start server: {str(e)}", exc_info=True)
<<<<<<< HEAD
=======
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
if os.path.exists('../.env'):
    load_dotenv(dotenv_path='../.env')
elif os.path.exists('.env'):
    load_dotenv(dotenv_path='.env')
else:
    print(".env file not found at: .env")
    # Continue without .env file - environment variables should be set by Docker

# --- Configuração de Logging ---
def setup_logging():
    """Configure logging for the application"""
    log_level = logging.DEBUG if os.getenv('NODE_ENV') == 'development' else logging.INFO
    
    # Create logs directory if it doesn't exist
    log_dir = '../logs'
    if not os.path.exists(log_dir):
        try:
            os.makedirs(log_dir)
        except PermissionError:
            # Fallback to current directory if we can't create in parent
            log_dir = './logs'
            if not os.path.exists(log_dir):
                os.makedirs(log_dir, exist_ok=True)
    
    # Configure logging format
    log_format = '\b[%(levelname)s] %(message)s'
    
    # Configure root logger
    logging.basicConfig(
        level=log_level,
        format=log_format,
        handlers=[
            logging.FileHandler(f'{log_dir}/ai_agent.log'),
            logging.StreamHandler()  # Console output
        ]
    )
    
    # Get logger for this module
    logger = logging.getLogger(__name__)
    logger.info("Logging initialized successfully")
    return logger

# Initialize logger
logger = setup_logging()

# --- Funções e Lógica de Negócio (movidas ou importadas) ---

def remover_acentos_nativo(texto: str) -> str:
    """
    Normaliza o texto para o formato NFD, que separa o caractere do acento,
    e depois remove os caracteres de combinação (acentos).
    """
    try:
        if not isinstance(texto, str):
            logger.warning(f"Input is not a string: {type(texto)}, returning empty string")
            return ""
        
        logger.debug(f"Removing accents from text: '{texto}'")
        texto_normalizado = unicodedata.normalize('NFD', texto)
        texto_sem_acento = "".join(c for c in texto_normalizado if not unicodedata.combining(c))
        logger.debug(f"Text after accent removal: '{texto_sem_acento}'")
        return texto_sem_acento
    
    except Exception as e:
        logger.error(f"Error removing accents from text '{texto}': {str(e)}")
        return ""

# --- Configuração do Servidor Flask ---

app = Flask(__name__)
CORS(app)

# Log Flask app initialization
logger.info("Flask application and CORS initialized")

# --- Definição do Endpoint da API ---

@app.route('/assistente', methods=['POST'])
def analisar_materia_endpoint():
    """
    Endpoint da API que recebe um JSON com a matéria, a processa
    e retorna o ranking das disciplinas relacionadas.
    """
    request_start_time = datetime.now()
    client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', 'Unknown'))
    
    logger.info(f"[REQUEST START] New request from IP: {client_ip}")
    
    try:
        # 1. Extrair os dados da requisição
        logger.debug("Extracting data from request")
        dados_requisicao = request.get_json()

        if not dados_requisicao:
            logger.warning("Request body is empty or not valid JSON")
            return jsonify({"erro": "Corpo da requisição deve ser um JSON válido."}), 400

        if 'materia' not in dados_requisicao:
            logger.warning("Missing 'materia' field in request")
            return jsonify({"erro": "O campo 'materia' é obrigatório no corpo da requisição JSON."}), 400

        materia_original = dados_requisicao['materia']
        logger.info(f"Received materia: '{materia_original}'")

        if not materia_original or not materia_original.strip():
            logger.warning("Empty 'materia' field provided")
            return jsonify({"erro": "O campo 'materia' não pode estar vazio."}), 400

        # 2. Pré-processamento do input
        logger.debug("Starting text preprocessing")
        materia_processada = remover_acentos_nativo(materia_original).upper()
        logger.info(f"Materia processed: '{materia_original}' -> '{materia_processada}'")

        # 3. Executar a lógica de análise
        logger.info("Starting analysis with RAGFlow client")
        client = RagflowClient()
        
        logger.debug("Starting session with RAGFlow")
        session_id = client.start_session(materia_processada)
        logger.info(f"Session started successfully with ID: {session_id}")
        
        logger.debug("Analyzing materia with RAGFlow agent")
        resultado_agente = client.analyze_materia(materia_processada, session_id)
        logger.debug(f"Raw agent result received: {type(resultado_agente)}")

        if resultado_agente.get("code") != 0:
            # Se a API do RAGFlow retornar um erro, repassa a mensagem.
            mensagem_erro = resultado_agente.get('message', 'Erro desconhecido na API do agente.')
            logger.error(f"RAGFlow API error (code: {resultado_agente.get('code')}): {mensagem_erro}")
            return jsonify({"erro": f"Erro na API do agente: {mensagem_erro}"}), 500

        # 4. Formatar a resposta final
        logger.debug("Formatting response")
        resposta_formatada = gerar_texto_ranking(resultado_agente)
        logger.info("Response formatted successfully")
        
        # Calculate request duration
        request_duration = (datetime.now() - request_start_time).total_seconds()
        logger.info(f"[REQUEST SUCCESS] Request completed in {request_duration:.2f} seconds")
        
        # 5. Retornar a resposta formatada como JSON
        return jsonify({"resultado": resposta_formatada})

    except Exception as e:
        # Captura qualquer outro erro durante o processo
        request_duration = (datetime.now() - request_start_time).total_seconds()
        logger.error(f"[REQUEST ERROR] Unexpected error after {request_duration:.2f} seconds: {str(e)}", exc_info=True)
        return jsonify({"erro": f"Ocorreu um erro interno no servidor: {str(e)}"}), 500

@app.route('/', methods=['GET'])
def root_health_check():
    """Root health check endpoint"""
    logger.debug("Root health check requested")
    return jsonify({
        "status": "healthy",
        "service": "AI Agent",
        "message": "AI Agent server is running",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    logger.debug("Health check requested")
    return jsonify({
        "status": "healthy",
        "service": "AI Agent",
        "timestamp": datetime.now().isoformat()
    })

@app.before_request
def log_request_info():
    """Log information about each request"""
    logger.debug(f"Request: {request.method} {request.url} from {request.environ.get('REMOTE_ADDR', 'Unknown')}")

@app.after_request
def log_response_info(response):
    """Log information about each response"""
    logger.debug(f"Response: {response.status_code} for {request.method} {request.url}")
    return response

# --- Configuração de Argumentos da Linha de Comando ---

def parse_arguments():
    """
    Parse command line arguments for the Flask application.
    """
    parser = argparse.ArgumentParser(description='AI Agent Flask Server')
    parser.add_argument(
        '--port', '-p',
        type=int,
        default=int(os.getenv('AI_AGENT_PORT', 5000)),
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
        default=os.getenv('NODE_ENV') == 'development',
        help='Run in debug mode (default: based on NODE_ENV env var)'
    )
    parser.add_argument(
        '--log-level',
        type=str,
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default='DEBUG' if os.getenv('NODE_ENV') == 'development' else 'INFO',
        help='Set the logging level'
    )
    return parser.parse_args()

# --- Execução do Servidor ---


if __name__ == '__main__':
    args = parse_arguments()
    

    # Update log level if specified via command line
    if hasattr(args, 'log_level'):
        logging.getLogger().setLevel(getattr(logging, args.log_level))
        logger.setLevel(getattr(logging, args.log_level))
    
    logger.info("="*50)
    logger.info("AI AGENT SERVER STARTUP")
    logger.info("="*50)
    logger.info(f"Host: {args.host}")
    logger.info(f"Port: {args.port}")
    logger.info(f"Debug mode: {args.debug}")
    logger.info(f"Log level: {logging.getLogger().level}")
    logger.info(f"Environment: {os.getenv('NODE_ENV', 'unknown')}")
    logger.info("="*50)
    
    try:
        # O host '0.0.0.0' torna o servidor acessível na sua rede local.
        # Para produção, use um servidor WSGI como Gunicorn ou Waitress.
        app.run(host=args.host, port=args.port, debug=args.debug)
    except Exception as e:
        logger.error(f"Failed to start server: {str(e)}", exc_info=True)
>>>>>>> origin/dev:no_fluxo_backend/AI-agent/app.py
=======
>>>>>>> e230dc46013b11b69eea88dddfc80240c5a9aa54
        exit(1)