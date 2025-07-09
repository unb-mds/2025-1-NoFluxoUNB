import os
import subprocess
import signal
import time
import logging
import argparse
from pathlib import Path
import urllib.parse
from dotenv import load_dotenv
import threading
import queue
import gc
import psutil
from logging.handlers import RotatingFileHandler

# Load environment variables from .env file
load_dotenv()

# Set up logging with rotation to prevent unbounded log file growth
log_file = Path(__file__).parent / "process.log"
handler = RotatingFileHandler(
    log_file, 
    maxBytes=10*1024*1024,  # 10MB max file size
    backupCount=5  # Keep 5 backup files
)
handler.setFormatter(logging.Formatter(
    "%(asctime)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
))
logging.basicConfig(
    level=logging.INFO,
    handlers=[handler]
)

# Global variables for thread management
active_threads = []
shutdown_event = threading.Event()

def log_message(message):
    print(message)
    logging.info(message)

def cleanup_threads():
    """Clean up any active threads."""
    global active_threads
    shutdown_event.set()
    
    for thread in active_threads[:]:  # Create a copy of the list
        if thread.is_alive():
            thread.join(timeout=2.0)  # Wait up to 2 seconds for thread to finish
        active_threads.remove(thread)
    
    shutdown_event.clear()
    gc.collect()  # Force garbage collection

def log_memory_usage():
    """Log current memory usage for monitoring."""
    try:
        process = psutil.Process()
        memory_info = process.memory_info()
        memory_mb = memory_info.rss / 1024 / 1024
        log_message(f"Python: Memory usage: {memory_mb:.2f} MB, Active threads: {len(active_threads)}")
    except Exception as e:
        log_message(f"Python: Error getting memory info: {e}")

def run_git_command_safely(command, cwd=None, timeout=30):
    """Run git command with proper resource cleanup and timeout."""
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False  # Don't raise exception on non-zero exit
        )
        return result
    except subprocess.TimeoutExpired:
        log_message(f"Python: Git command timed out: {' '.join(command)}")
        return None
    except Exception as e:
        log_message(f"Python: Error running git command {' '.join(command)}: {e}")
        return None



def save_git_config(repo_path):
    """Save current git configuration that we might modify."""
    try:
        original_dir = os.getcwd()
        os.chdir(repo_path)
        
        config_backup = {}
        
        # Save credential helper configuration
        try:
            result = subprocess.run(["git", "config", "--local", "--get", "credential.helper"], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                config_backup['credential.helper'] = result.stdout.strip()
        except:
            pass
        
        # Save any credential.* configurations
        try:
            result = subprocess.run(["git", "config", "--local", "--get-regexp", "credential\\..*"], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        key, value = line.split(' ', 1)
                        config_backup[key] = value
        except:
            pass
        
        os.chdir(original_dir)
        log_message(f"Python: Saved git configuration: {list(config_backup.keys())}")
        return config_backup
        
    except Exception as e:
        log_message(f"Python: Error saving git config: {e}")
        os.chdir(original_dir)
        return {}

def setup_git_credential_helper(username, token, repo_path):
    """Setup git credential helper using git config."""
    if not username or not token:
        return None
    
    try:
        # Save current config before making changes
        config_backup = save_git_config(repo_path)
        
        original_dir = os.getcwd()
        os.chdir(repo_path)
        
        # Set up credential helper to store credentials temporarily
        subprocess.run(["git", "config", "--local", "credential.helper", "store"], check=True)
        
        # Write credentials to git credential store
        credential_input = f"protocol=https\nhost=github.com\nusername={username}\npassword={token}\n\n"
        process = subprocess.Popen(
            ["git", "credential", "approve"],
            stdin=subprocess.PIPE,
            text=True
        )
        process.communicate(input=credential_input)
        
        os.chdir(original_dir)
        log_message("Python: Git credential helper configured")
        return config_backup
        
    except Exception as e:
        log_message(f"Python: Error setting up git credential helper: {e}")
        os.chdir(original_dir)
        return {}

def restore_git_config(repo_path, config_backup):
    """Restore original git configuration."""
    try:
        original_dir = os.getcwd()
        os.chdir(repo_path)
        
        # Clear current credential configuration
        subprocess.run(["git", "config", "--local", "--unset", "credential.helper"], 
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Remove any credential.* configurations we might have added
        try:
            result = subprocess.run(["git", "config", "--local", "--get-regexp", "credential\\..*"], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line:
                        key = line.split(' ', 1)[0]
                        subprocess.run(["git", "config", "--local", "--unset", key], 
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except:
            pass
        
        # Restore original configuration
        for key, value in config_backup.items():
            subprocess.run(["git", "config", "--local", key, value], check=True)
        
        os.chdir(original_dir)
        log_message(f"Python: Restored git configuration: {list(config_backup.keys())}")
        
    except Exception as e:
        log_message(f"Python: Warning - Could not restore git config: {e}")
        os.chdir(original_dir)



def check_for_updates(repo_dir, branch):
    """Check if the remote repository has new commits."""
    original_dir = os.getcwd()
    try:
        os.chdir(repo_dir)
        
        # Use safe git command runner
        fetch_result = run_git_command_safely(["git", "fetch", "origin"], cwd=repo_dir)
        if fetch_result is None or fetch_result.returncode != 0:
            log_message("Python: Warning - Failed to fetch from origin")
            return False
            
        local_result = run_git_command_safely(["git", "rev-parse", "HEAD"], cwd=repo_dir)
        remote_result = run_git_command_safely(["git", "rev-parse", f"origin/{branch}"], cwd=repo_dir)
        
        if local_result is None or remote_result is None:
            log_message("Python: Warning - Failed to get commit hashes")
            return False
            
        local_commit = local_result.stdout.strip()
        remote_commit = remote_result.stdout.strip()
        
        return local_commit != remote_commit
        
    except Exception as e:
        log_message(f"Python: Error checking for updates: {e}")
        return False
    finally:
        os.chdir(original_dir)

def pull_updates(repo_dir, branch):
    """Pull the latest changes from the remote repository."""
    original_dir = os.getcwd()
    try:
        os.chdir(repo_dir)
        log_message(f"Python: Performing a hard reset before pulling updates from {branch}.")
        
        reset_result = run_git_command_safely(["git", "reset", "--hard", f"origin/{branch}"], cwd=repo_dir)
        if reset_result is None or reset_result.returncode != 0:
            raise Exception("Failed to reset repository")
            
        pull_result = run_git_command_safely(["git", "pull", "origin", branch], cwd=repo_dir)
        if pull_result is None or pull_result.returncode != 0:
            raise Exception("Failed to pull updates")
            
    except Exception as e:
        log_message(f"Python: Error pulling updates: {e}")
        raise
    finally:
        os.chdir(original_dir)

def update_fork_repo(fork_path, branch, git_username=None, git_token=None):
    """Update the fork repository with the latest changes from current branch to main."""
    if not fork_path or not os.path.exists(fork_path):
        log_message(f"Python: Fork path {fork_path} does not exist. Skipping fork update.")
        return

    # Initialize variables outside try block for error handling
    config_backup = {}
    original_dir = os.getcwd()
    original_branch = None

    try:
        # Save current directory and its state
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
        
        # Setup git credential helper for authentication and save original config
        if git_username and git_token:
            config_backup = setup_git_credential_helper(git_username, git_token, fork_path)
        
        # Ensure fork's origin URL is clean (no embedded credentials)
        try:
            fork_origin_url = subprocess.check_output(["git", "remote", "get-url", "origin"], stderr=subprocess.PIPE).decode().strip()
            log_message(f"Python: Current fork origin URL: {fork_origin_url}")
            
            # Always clean the URL to remove any embedded credentials
            if '@' in fork_origin_url and 'github.com' in fork_origin_url:
                # Extract just the github.com part
                clean_url = 'https://github.com/' + fork_origin_url.split('github.com/')[1]
                subprocess.run(["git", "remote", "set-url", "origin", clean_url], check=True)
                log_message(f"Python: Cleaned fork's origin URL to: {clean_url}")
            else:
                log_message("Python: Fork origin URL is already clean")
                

        except subprocess.CalledProcessError as e:
            log_message(f"Python: Warning - Could not get fork's origin URL: {e.stderr.decode().strip() if e.stderr else str(e)}")
            # If origin doesn't exist, try to add it
            if git_username and git_token:
                fork_url = f"https://github.com/{git_username}/2025-1-NoFluxoUNB.git"
                subprocess.run(["git", "remote", "add", "origin", fork_url], check=True)
                log_message(f"Python: Added fork's origin remote: {fork_url}")
            else:
                raise Exception("No authentication provided and origin remote doesn't exist")

        # Fetch latest changes from fork's origin with full error output
        try:
            fetch_result = subprocess.run(["git", "fetch", "origin"], 
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
            subprocess.run(["git", "reset", "--hard", "origin/main"], check=True)
            subprocess.run(["git", "pull", "origin", "main"], check=True)
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
        
        # Push using credential helper
        try:
            subprocess.run(["git", "push", "-f", "origin", "main"], check=True)
            log_message("Python: Successfully pushed to fork's main branch")
        except subprocess.CalledProcessError as e:
            log_message(f"Python: Error pushing to fork: {e}")
            raise
        
        log_message(f"Python: Fork repository main branch updated successfully with content from {branch}")
        
        # Restore original git configuration
        if git_username and git_token:
            restore_git_config(fork_path, config_backup)
        
        # Return to original directory and branch
        os.chdir(original_dir)
        if original_branch and original_branch != branch:
            subprocess.run(["git", "checkout", original_branch], check=True)
        
    except subprocess.CalledProcessError as e:
        log_message(f"Python: Error updating fork repository: {e}")
        # Restore original git configuration even on error
        if git_username and git_token:
            restore_git_config(fork_path, config_backup)
        # Return to original directory even if there was an error
        os.chdir(original_dir)
        if original_branch and original_branch != branch:
            subprocess.run(["git", "checkout", original_branch], check=True)
    except Exception as e:
        log_message(f"Python: Unexpected error updating fork repository: {e}")
        # Restore original git configuration even on error
        if git_username and git_token:
            restore_git_config(fork_path, config_backup)
        # Return to original directory even if there was an error
        os.chdir(original_dir)
        if original_branch and original_branch != branch:
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
    """Print logs from the subprocess in real time with proper resource management."""
    def stream_output(stream, prefix):
        try:
            while not shutdown_event.is_set():
                line = stream.readline()
                if not line:  # End of stream
                    break
                if line.strip():  # Only log non-empty lines
                    message = f"{prefix}: {line.strip()}"
                    log_message(message)
        except Exception as e:
            log_message(f"Python: Error reading from {prefix}: {e}")
        finally:
            try:
                stream.close()
            except:
                pass
    
    # Create threads for stdout and stderr with proper management
    stdout_thread = threading.Thread(target=stream_output, args=(process.stdout, "STDOUT"), daemon=True)
    stderr_thread = threading.Thread(target=stream_output, args=(process.stderr, "STDERR"), daemon=True)
    
    stdout_thread.start()
    stderr_thread.start()
    
    active_threads.extend([stdout_thread, stderr_thread])

def stop_process(process):
    """Stop the given subprocess with proper cleanup."""
    try:
        if process and process.poll() is None:  # Check if process is running
            # First, try graceful termination
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            
            # Wait for process to terminate gracefully
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                # Force kill if it doesn't terminate gracefully
                log_message("Python: Process didn't terminate gracefully, force killing...")
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                process.wait()
            
            # Clean up process resources
            if process.stdout and not process.stdout.closed:
                process.stdout.close()
            if process.stderr and not process.stderr.closed:
                process.stderr.close()
            if process.stdin and not process.stdin.closed:
                process.stdin.close()
                
        # Clean up threads after stopping process
        cleanup_threads()
        
    except Exception as e:
        log_message(f"Python: Error stopping process: {e}")

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
    
    # Memory monitoring counter
    memory_check_counter = 0
    MEMORY_CHECK_INTERVAL = 60  # Log memory every 60 iterations (10 minutes)

    try:
        while True:
            # Log memory usage periodically
            memory_check_counter += 1
            if memory_check_counter >= MEMORY_CHECK_INTERVAL:
                log_memory_usage()
                memory_check_counter = 0
            
            if check_for_updates(REPO_DIR, BRANCH):
                log_message(f"Python: New changes detected in branch {BRANCH}. Updating...")
                stop_process(process)
                pull_updates(REPO_DIR, BRANCH)
                
                # Update fork repository if specified
                if FORK_LOCATION:
                    update_fork_repo(FORK_LOCATION, BRANCH, GIT_USERNAME, GIT_TOKEN)
                
                log_message("Python: Starting the process...")
                process = start_process(START_COMMAND)
                
                # Force garbage collection after major operations
                gc.collect()
                log_memory_usage()
            else:
                new_process = restart_process_if_crashed(process, START_COMMAND)
                if new_process is None:
                    log_message("Python: Process crashed and could not be restarted. trying again in 10 seconds...")

                    while new_process is None:
                        time.sleep(10)
                        new_process = start_process(START_COMMAND)
                else:
                    process = new_process

            time.sleep(CHECK_INTERVAL)
    except KeyboardInterrupt:
        log_message("Python: Exiting. Stopping subprocess...")
        stop_process(process)
    finally:
        cleanup_threads()

if __name__ == "__main__":
    main()
