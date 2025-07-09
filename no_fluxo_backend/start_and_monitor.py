import os
import subprocess
import signal
import time
import logging
import argparse
from pathlib import Path
import urllib.parse
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Set up logging at the same place as the script with name process.log
log_file = Path(__file__).parent / "process.log"
logging.basicConfig(
    filename=log_file,
    level=logging.INFO,
    format="%(asctime)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

def log_message(message):
    print(message)
    logging.info(message)

def setup_git_auth(username, token):
    """Setup git authentication using environment variables for credential helper."""
    if username and token:
        # Set up git credentials using environment variables
        env = os.environ.copy()
        env['GIT_USERNAME'] = username
        env['GIT_PASSWORD'] = token
        return env
    return None

def get_authenticated_url(url, username, token):
    """Convert a git URL to include authentication credentials."""
    if not username or not token:
        return url
    
    # Handle HTTPS URLs
    if url.startswith('https://'):
        # Parse the URL and remove any existing auth
        parsed = urllib.parse.urlparse(url)
        netloc = parsed.netloc
        if '@' in netloc:
            netloc = netloc.split('@')[1]
        
        # Quote username and token separately, ensuring special characters are properly encoded
        quoted_username = urllib.parse.quote(username, safe='')
        quoted_token = urllib.parse.quote(token, safe='')
        
        # Reconstruct with credentials
        authenticated_url = f"https://{quoted_username}:{quoted_token}@{netloc}{parsed.path}"
        return authenticated_url
    
    # Return original URL if not HTTPS
    return url

def check_for_updates(repo_dir, branch):
    """Check if the remote repository has new commits."""
    os.chdir(repo_dir)
    subprocess.run(["git", "fetch", "origin"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    local_commit = subprocess.check_output(["git", "rev-parse", "HEAD"]).strip()
    remote_commit = subprocess.check_output(["git", "rev-parse", f"origin/{branch}"]).strip()

    return local_commit != remote_commit

def pull_updates(repo_dir, branch):
    """Pull the latest changes from the remote repository."""
    os.chdir(repo_dir)
    log_message(f"Python: Performing a hard reset before pulling updates from {branch}.")
    subprocess.run(["git", "reset", "--hard", f"origin/{branch}"], check=True)
    subprocess.run(["git", "pull", "origin", branch], check=True)

def update_fork_repo(fork_path, branch, git_username=None, git_token=None):
    """Update the fork repository with the latest changes from current branch to main."""
    if not fork_path or not os.path.exists(fork_path):
        log_message(f"Python: Fork path {fork_path} does not exist. Skipping fork update.")
        return
    
    # Set up authentication if provided
    git_env = setup_git_auth(git_username, git_token)
    
    try:
        # Save current directory and its state
        original_dir = os.getcwd()
        original_branch = subprocess.check_output(["git", "rev-parse", "--abbrev-ref", "HEAD"]).decode().strip()
        
        # Get the original repo's remote URL
        origin_url = subprocess.check_output(["git", "remote", "get-url", "origin"]).decode().strip()
        
        # First update the current repo to make sure we have latest changes
        subprocess.run(["git", "fetch", "origin"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["git", "reset", "--hard", f"origin/{branch}"], check=True)
        subprocess.run(["git", "pull", "origin", branch], check=True)
        
        # Get the latest commit hash from current branch
        current_commit = subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip()
        
        # Change to fork directory
        os.chdir(fork_path)
        log_message(f"Python: Updating fork repository at {fork_path}")
        
        # Get fork's origin URL and update it with authentication if needed
        try:
            fork_origin_url = subprocess.check_output(["git", "remote", "get-url", "origin"], stderr=subprocess.PIPE).decode().strip()
            # Remove any existing authentication from the URL
            if '@' in fork_origin_url:
                fork_origin_url = 'https://' + fork_origin_url.split('@')[1]
            
            if git_username and git_token:
                authenticated_fork_url = get_authenticated_url(fork_origin_url, git_username, git_token)
                subprocess.run(["git", "remote", "set-url", "origin", authenticated_fork_url], check=True)
                log_message("Python: Updated fork's origin URL with authentication")
        except subprocess.CalledProcessError as e:
            log_message(f"Python: Warning - Could not get/set fork's origin URL: {e.stderr.decode().strip()}")
            # If origin doesn't exist, try to add it
            if git_username and git_token:
                fork_url = f"https://github.com/{git_username}/2025-1-NoFluxoUNB.git"
                authenticated_fork_url = get_authenticated_url(fork_url, git_username, git_token)
                subprocess.run(["git", "remote", "add", "origin", authenticated_fork_url], check=True)
                log_message("Python: Added fork's origin remote")
            else:
                raise Exception("No authentication provided and origin remote doesn't exist")

        # Fetch latest changes from fork's origin with full error output
        try:
            fetch_result = subprocess.run(["git", "fetch", "origin"], 
                                        env=git_env,
                                        capture_output=True,
                                        text=True,
                                        check=True)
            log_message("Python: Successfully fetched from fork's origin")
        except subprocess.CalledProcessError as e:
            log_message(f"Python: Error fetching from fork's origin: {e.stderr}")
        
        # Switch to main branch in fork
        log_message("Python: Switching to main branch in fork repository")
        try:
            
            # Try to checkout main branch
            subprocess.run(["git", "checkout", "main"], check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            # If main branch doesn't exist, create it
            log_message("Python: Main branch not found, creating it")
            subprocess.run(["git", "checkout", "-b", "main"], check=True)
        
        try:
            subprocess.run(["git", "reset", "--hard", "origin/main"], check=True, env=git_env)
            subprocess.run(["git", "pull", "origin", "main"], check=True, env=git_env)
        except subprocess.CalledProcessError as e:
            log_message(f"Python: Warning - Could not reset/pull main branch: {e.stderr if hasattr(e, 'stderr') else str(e)}")
            # If we can't reset/pull, we'll just push our changes later
        
        # Add or update the original repo as a remote
        log_message("Python: Setting up upstream remote with original repository")
        try:
            
            # Try to add the remote
            subprocess.run(["git", "remote", "add", "upstream", origin_url], check=True)
        except subprocess.CalledProcessError:
            # If remote already exists, update its URL
            subprocess.run(["git", "remote", "set-url", "upstream", origin_url], check=True)
        
        # Fetch from upstream (original repo)
        subprocess.run(["git", "fetch", "upstream"], check=True)
        
        # Force update main branch with the content from upstream's current branch
        log_message(f"Python: Updating fork's main branch with content from upstream's {branch} branch")
        subprocess.run(["git", "reset", "--hard", current_commit], check=True)
        
        # Push to fork's origin/main
        log_message("Python: Pushing changes to fork's main branch")
        
        # Set up authentication if provided
        git_env = setup_git_auth(git_username, git_token)
        
        if git_username and git_token:
            # Get the current origin URL and update it with authentication
            fork_origin_url = subprocess.check_output(["git", "remote", "get-url", "origin"]).decode().strip()
            authenticated_fork_url = get_authenticated_url(fork_origin_url, git_username, git_token)
            
            # Temporarily update the origin URL with authentication
            subprocess.run(["git", "remote", "set-url", "origin", authenticated_fork_url], check=True)
            
            # Push with authentication
            subprocess.run(["git", "push", "-f", "origin", "main"], check=True, env=git_env)
            
            # Restore the original URL (without credentials)
            subprocess.run(["git", "remote", "set-url", "origin", fork_origin_url], check=True)
        else:
            # Push without explicit authentication (relies on system git config)
            subprocess.run(["git", "push", "-f", "origin", "main"], check=True)
        
        log_message(f"Python: Fork repository main branch updated successfully with content from {branch}")
        
        # Return to original directory and branch
        os.chdir(original_dir)
        if original_branch != branch:
            subprocess.run(["git", "checkout", original_branch], check=True)
        
    except subprocess.CalledProcessError as e:
        log_message(f"Python: Error updating fork repository: {e}")
        # Return to original directory even if there was an error
        os.chdir(original_dir)
        if original_branch != branch:
            subprocess.run(["git", "checkout", original_branch], check=True)
    except Exception as e:
        log_message(f"Python: Unexpected error updating fork repository: {e}")
        # Return to original directory even if there was an error
        os.chdir(original_dir)
        if original_branch != branch:
            subprocess.run(["git", "checkout", original_branch], check=True)

def start_process(command):
    """Start a subprocess with the given command and print logs in real time."""
    log_message(f"Python: Starting subprocess with command: {command}")
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=True,
        text=True,                 # Decode bytes to string automatically
        preexec_fn=os.setsid
    )
    # Print the logs in a separate thread or inline
    print_logs_in_real_time(process)
    return process

def print_logs_in_real_time(process):
    """Print logs from the subprocess in real time."""
    def stream_output(stream, prefix):
        for line in iter(stream.readline, b""):
            if line != "":
                message = f"{prefix}: {line}"
                log_message(message)
    
    # Create threads for stdout and stderr
    import threading
    threading.Thread(target=stream_output, args=(process.stdout, "STDOUT"), daemon=True).start()
    threading.Thread(target=stream_output, args=(process.stderr, "STDERR"), daemon=True).start()

def stop_process(process):
    """Stop the given subprocess."""
    try:
        if process and process.poll() is None:  # Check if process is running
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)  # Kill the process group

    except Exception as e:
        log_message(f"Python: Error occurred: {e}")

def restart_process_if_crashed(process, command):
    """Check if the process has crashed and restart it."""
    try:
        if process.poll() is not None:  # If process is not running
            log_message("Python: Process crashed. Restarting...")
            return start_process(command)
    except Exception as e:
        log_message(f"Python: Error occurred: {e}")
        return None
    return process





def main():
    parser = argparse.ArgumentParser(description='Monitor and auto-update a git repository.')
    parser.add_argument('--branch', default='main', help='Git branch to monitor (default: main)')
    parser.add_argument('--fork-location', help='Path to fork repository that should be updated when origin changes')
    parser.add_argument('--git-username', help='Git username for authentication (can also use GIT_USERNAME in .env)')
    parser.add_argument('--git-token', help='Git token/password for authentication (can also use GIT_TOKEN in .env)')
    args = parser.parse_args()

    REPO_DIR = "./"  # Replace with the path to your repository
    START_COMMAND = "npm run build-and-start"
    CHECK_INTERVAL = 10  # Interval in seconds to check for updates
    BRANCH = args.branch
    FORK_LOCATION = args.fork_location
    
    # Get authentication credentials from args, environment variables, or .env file
    GIT_USERNAME = args.git_username or os.getenv('GIT_USERNAME')
    GIT_TOKEN = args.git_token or os.getenv('GIT_TOKEN')
    
    if not GIT_USERNAME and FORK_LOCATION:
        log_message("Python: Warning - No git username provided. Set GIT_USERNAME in .env file or use --git-username")
    if not GIT_TOKEN and FORK_LOCATION:
        log_message("Python: Warning - No git token provided. Set GIT_TOKEN in .env file or use --git-token")

    dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(dir)

    log_message(f"Python: Current working directory: {os.getcwd()}")
    log_message(f"Python: Monitoring branch: {BRANCH}")
    
    if FORK_LOCATION:
        log_message(f"Python: Fork repository location: {FORK_LOCATION}")
        if not os.path.exists(FORK_LOCATION):
            log_message(f"Python: Warning - Fork location {FORK_LOCATION} does not exist!")
    else:
        log_message("Python: No fork repository specified.")
    
    # Log authentication status (without exposing credentials)
    if GIT_USERNAME and GIT_TOKEN:
        log_message(f"Python: Git authentication configured for user: {GIT_USERNAME}")
    elif FORK_LOCATION:
        log_message("Python: No git authentication provided - using system git config")

    process = start_process(START_COMMAND)

    try:
        while True:
            if check_for_updates(REPO_DIR, BRANCH):
                log_message(f"Python: New changes detected in branch {BRANCH}. Updating...")
                stop_process(process)
                pull_updates(REPO_DIR, BRANCH)
                
                # Update fork repository if specified
                if FORK_LOCATION:
                    update_fork_repo(FORK_LOCATION, BRANCH, GIT_USERNAME, GIT_TOKEN)
                
                log_message("Python: Starting the process...")
                process = start_process(START_COMMAND)
            else:
                new_process = restart_process_if_crashed(process, START_COMMAND)
                if new_process is None:
                    log_message("Python: Process crashed and could not be restarted. trying again in 10 seconds...")

                    while new_process is None:
                        time.sleep(10)
                        new_process = start_process(START_COMMAND)

            time.sleep(CHECK_INTERVAL)
    except KeyboardInterrupt:
        log_message("Python: Exiting. Stopping subprocess...")
        stop_process(process)

if __name__ == "__main__":
    main()
