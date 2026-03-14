#!/usr/bin/env node
/**
 * install-all.js — Install all dependencies (Node + Python/MCP agent).
 * Works cross-platform (macOS, Linux, Windows).
 * Usage: npm run install:all  (from no_fluxo_backend/)
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const BACKEND_DIR = path.join(REPO_ROOT, 'no_fluxo_backend');
const MCP_AGENT_DIR = path.join(REPO_ROOT, 'mcp_agent');
const VENV_DIR = path.join(REPO_ROOT, '.venv');

const isWindows = process.platform === 'win32';
const python = isWindows ? 'python' : 'python3';
const pip = path.join(VENV_DIR, isWindows ? 'Scripts' : 'bin', 'pip');
const requirementsFile = path.join(MCP_AGENT_DIR, 'requirements.txt');

function run(cmd, opts = {}) {
    console.log(`  > ${cmd}`);
    execSync(cmd, { stdio: 'inherit', ...opts });
}

try {
    // Step 1: Node.js dependencies
    console.log('\n[1/3] Installing Node.js dependencies...');
    run('npm install --loglevel verbose', { cwd: BACKEND_DIR });
    console.log('  ✅ Node.js dependencies installed\n');

    // Step 2: Python virtual environment
    console.log('[2/3] Setting up Python virtual environment...');
    if (!fs.existsSync(VENV_DIR)) {
        console.log(`  Creating venv at ${VENV_DIR}...`);
        run(`${python} -m venv "${VENV_DIR}"`);
    }
    console.log('  ✅ Virtual environment ready\n');

    // Step 3: Python dependencies
    console.log('[3/3] Installing MCP agent Python dependencies...');
    run(`"${pip}" install -v -r "${requirementsFile}"`);
    console.log('  ✅ Python dependencies installed\n');

    console.log('All dependencies installed successfully!');
    console.log('Run `npm run dev:full` to start both servers.');
} catch (error) {
    console.error('\n❌ Installation failed:', error.message);
    process.exit(1);
}
