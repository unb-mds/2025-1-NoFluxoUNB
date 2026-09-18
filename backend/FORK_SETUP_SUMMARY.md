# Fork Auto-Cloning Setup Summary

## ✅ What Was Implemented

### **FORK_URL Parameter for Automatic Cloning**

Instead of mounting external directories, the container now automatically clones your fork repository using Git credentials.

## 🔧 How It Works

### **Before (Manual Directory Mounting):**
```yaml
volumes:
  - /path/to/local/fork:/app/fork  # Manual mounting
```

### **After (Automatic Cloning):**
```env
FORK_URL=https://github.com/yourusername/2025-1-NoFluxoUNB.git
```

## 📁 Changes Made

### **Configuration Files:**
1. **`docker.env.example`** - Added `FORK_URL` parameter
2. **`docker-entrypoint.sh`** - Added automatic fork cloning logic
3. **`docker-compose.yml`** - Added persistent volume for fork data
4. **`test-docker.sh`** - Updated to check `FORK_URL` instead of `FORK_LOCATION`

### **Docker Workflow:**
1. **Container starts** → Reads `FORK_URL` from environment
2. **Checks** if fork already exists at `/app/fork_repo`
3. **If not exists** → Clones fork using `GIT_USERNAME` and `GIT_TOKEN`
4. **If exists** → Pulls latest changes from fork
5. **Passes fork location** to `start_and_monitor.py`

## 🎯 Benefits

| Aspect          | Before               | After                   |
| --------------- | -------------------- | ----------------------- |
| **Setup**       | Manual clone + mount | ✅ Automatic cloning     |
| **Credentials** | SSH keys/git config  | ✅ Uses .env credentials |
| **Portability** | Host-dependent paths | ✅ Self-contained        |
| **Persistence** | Host directory       | ✅ Docker volume         |
| **Security**    | External key mounts  | ✅ Credential management |

## 🔑 Environment Configuration

### **Required for Fork Sync:**
```env
GIT_USERNAME=your_github_username
GIT_TOKEN=your_github_token
FORK_URL=https://github.com/yourusername/2025-1-NoFluxoUNB.git
```

### **Generated Fork Path:**
- **Inside Container**: `/app/fork_repo`
- **Docker Volume**: `fork_data` (persistent across restarts)

## 🚀 Usage Example

### **1. Create Fork on GitHub:**
- Go to main repository
- Click "Fork" button
- Copy your fork URL

### **2. Configure Environment:**
```bash
cd no_fluxo_backend
cp docker.env.example .env
# Edit .env with your fork URL
```

### **3. Start Container:**
```bash
docker-compose up --build
```

### **4. Watch Logs:**
```bash
🍴 Fork URL configured: https://github.com/user/2025-1-NoFluxoUNB.git
📦 Cloning fork repository...
✅ Fork cloned successfully
🎯 Using fork location: /app/fork_repo
```

## ✅ Result

The container now automatically:
- ✅ **Clones your fork** using HTTPS with tokens
- ✅ **Persists fork data** across container restarts
- ✅ **Syncs changes** to your fork when updates are detected
- ✅ **Manages credentials** securely within the container
- ✅ **No external dependencies** on host file system

Perfect for containerized environments! 🐳 