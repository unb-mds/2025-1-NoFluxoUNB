import os
import subprocess
import signal
import time
import logging
import argparse
from pathlib import Path

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
    args = parser.parse_args()

    REPO_DIR = "./"  # Replace with the path to your repository
    START_COMMAND = "npm run build-and-start"
    CHECK_INTERVAL = 10  # Interval in seconds to check for updates
    BRANCH = args.branch

    dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(dir)

    log_message(f"Python: Current working directory: {os.getcwd()}")
    log_message(f"Python: Monitoring branch: {BRANCH}")

    process = start_process(START_COMMAND)

    try:
        while True:
            if check_for_updates(REPO_DIR, BRANCH):
                log_message(f"Python: New changes detected in branch {BRANCH}. Updating...")
                stop_process(process)
                pull_updates(REPO_DIR, BRANCH)
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
