const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');
const os = require('os');
const { pipeline } = require('stream/promises');

const TESSERACT_VERSION = '5.3.3';
const DOWNLOAD_DIR = path.join(__dirname, '..', 'tesseract');
const PLATFORM = os.platform();
const ARCH = os.arch();

function checkExistingInstallation() {
    const tesseractPath = path.join(DOWNLOAD_DIR, 'tesseract-ocr');
    const binaryName = PLATFORM === 'win32' ? 'tesseract.exe' : 'tesseract';
    const binaryPath = path.join(tesseractPath, binaryName);
    const langDataPath = path.join(tesseractPath, 'tessdata', 'por.traineddata');

    try {
        // Check if binary exists
        if (!fs.existsSync(binaryPath)) {
            console.log('Tesseract binary not found, installation needed.');
            return false;
        }

        // Check if language data exists
        if (!fs.existsSync(langDataPath)) {
            console.log('Portuguese language data not found, installation needed.');
            return false;
        }

        // Try to execute tesseract to verify it works
        try {
            execSync(`"${binaryPath}" --version`);
            console.log('Existing Tesseract installation found and verified.');
            return true;
        } catch (error) {
            console.log('Existing Tesseract installation is corrupted, reinstallation needed.');
            return false;
        }
    } catch (error) {
        console.log('Error checking installation:', error);
        return false;
    }
}

async function downloadFile(url, dest) {
    await fs.promises.mkdir(path.dirname(dest), { recursive: true });
    const fileStream = fs.createWriteStream(dest);

    console.log(`Downloading from ${url}`);
    console.log(`Saving to ${dest}`);

    return new Promise((resolve, reject) => {
        https.get(url, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`Failed to download: ${response.statusCode}`));
                return;
            }

            pipeline(response, fileStream)
                .then(() => resolve())
                .catch(reject);
        }).on('error', reject);
    });
}

async function setupMacOS() {
    console.log('Setting up Tesseract for macOS...');
    const tesseractPath = path.join(DOWNLOAD_DIR, 'tesseract-ocr');

    try {
        // Create directories
        await fs.promises.mkdir(tesseractPath, { recursive: true });
        await fs.promises.mkdir(path.join(tesseractPath, 'tessdata'), { recursive: true });

        // Check if Tesseract is already installed via Homebrew
        try {
            const version = execSync('brew list tesseract --version').toString().trim();
            console.log(`Tesseract is already installed via Homebrew: ${version}`);
        } catch (error) {
            // Tesseract is not installed, install it
            console.log('Installing Tesseract via Homebrew...');
            execSync('brew install tesseract', { stdio: 'inherit' });
        }

        // Download Portuguese language data
        console.log('Downloading Portuguese language data...');
        const langDataUrl = 'https://raw.githubusercontent.com/tesseract-ocr/tessdata/main/por.traineddata';
        await downloadFile(langDataUrl, path.join(tesseractPath, 'tessdata', 'por.traineddata'));

        // Create a symlink to the Homebrew installation
        const brewPath = execSync('brew --prefix tesseract').toString().trim();
        const binPath = path.join(brewPath, 'bin', 'tesseract');

        // Remove existing symlink if it exists
        try {
            await fs.promises.unlink(path.join(tesseractPath, 'tesseract'));
        } catch (error) {
            // Ignore error if file doesn't exist
        }

        await fs.promises.symlink(binPath, path.join(tesseractPath, 'tesseract'));

        console.log('Tesseract setup completed for macOS');
    } catch (error) {
        console.error('Error setting up Tesseract:', error);
        throw error;
    }
}

async function setupWindows() {
    console.log('Setting up Tesseract for Windows...');
    const tesseractPath = path.join(DOWNLOAD_DIR, 'tesseract-ocr');

    try {
        // Create directories
        await fs.promises.mkdir(tesseractPath, { recursive: true });
        await fs.promises.mkdir(path.join(tesseractPath, 'tessdata'), { recursive: true });

        // Download Windows binary
        console.log('Downloading Tesseract binary...');
        const url = `https://digi.bib.uni-mannheim.de/tesseract/tesseract-ocr-w64-setup-v${TESSERACT_VERSION}.exe`;
        const installerPath = path.join(tesseractPath, 'installer.exe');

        await downloadFile(url, installerPath);

        // Extract using 7zip (built into Windows 10+)
        console.log('Extracting Tesseract...');
        execSync(`powershell Expand-Archive -Path "${installerPath}" -DestinationPath "${tesseractPath}" -Force`);

        // Download Portuguese language data
        console.log('Downloading Portuguese language data...');
        const langDataUrl = 'https://raw.githubusercontent.com/tesseract-ocr/tessdata/main/por.traineddata';
        await downloadFile(langDataUrl, path.join(tesseractPath, 'tessdata', 'por.traineddata'));

        console.log('Tesseract setup completed for Windows');
    } catch (error) {
        console.error('Error setting up Tesseract:', error);
        throw error;
    }
}

async function setupLinux() {
    console.log('Setting up Tesseract for Linux...');
    const tesseractPath = path.join(DOWNLOAD_DIR, 'tesseract-ocr');

    try {
        // Create directories
        await fs.promises.mkdir(tesseractPath, { recursive: true });
        await fs.promises.mkdir(path.join(tesseractPath, 'tessdata'), { recursive: true });

        // Download Linux binary
        console.log('Downloading Tesseract binary...');
        const arch = process.arch === 'x64' ? 'amd64' : 'i386';
        const url = `https://notesalexp.org/tesseract-ocr/tesseract-ocr-${TESSERACT_VERSION}/tesseract-ocr-${TESSERACT_VERSION}-${arch}.tar.xz`;
        const archivePath = path.join(tesseractPath, 'tesseract.tar.xz');

        await downloadFile(url, archivePath);

        // Extract archive
        console.log('Extracting Tesseract...');
        execSync(`tar -xf "${archivePath}" -C "${tesseractPath}"`);

        // Download Portuguese language data
        console.log('Downloading Portuguese language data...');
        const langDataUrl = 'https://raw.githubusercontent.com/tesseract-ocr/tessdata/main/por.traineddata';
        await downloadFile(langDataUrl, path.join(tesseractPath, 'tessdata', 'por.traineddata'));

        // Make binary executable
        const binaryPath = path.join(tesseractPath, 'usr', 'bin', 'tesseract');
        execSync(`chmod +x "${binaryPath}"`);

        console.log('Tesseract setup completed for Linux');
    } catch (error) {
        console.error('Error setting up Tesseract:', error);
        throw error;
    }
}

async function main() {
    console.log(`Checking Tesseract OCR ${TESSERACT_VERSION} setup for ${PLATFORM} (${ARCH})...`);

    try {
        // Check if already installed
        if (checkExistingInstallation()) {
            console.log('Tesseract is already installed and working. Skipping setup.');
            return;
        }

        console.log('Installing Tesseract...');
        switch (PLATFORM) {
            case 'darwin':
                await setupMacOS();
                break;
            case 'win32':
                await setupWindows();
                break;
            case 'linux':
                await setupLinux();
                break;
            default:
                console.error(`Unsupported platform: ${PLATFORM}`);
                process.exit(1);
        }

        // Update the Python script to use the local Tesseract
        const pythonScript = path.join(__dirname, '..', 'parse-pdf', 'pdf_parser_final.py');
        let content = await fs.promises.readFile(pythonScript, 'utf8');

        const tesseractPath = path.join(DOWNLOAD_DIR, 'tesseract-ocr', PLATFORM === 'win32' ? 'tesseract.exe' : 'tesseract').replace(/\\/g, '\\\\');

        content = content.replace(
            /pytesseract\.pytesseract\.tesseract_cmd = .+/,
            `pytesseract.pytesseract.tesseract_cmd = '${tesseractPath}'`
        );

        await fs.promises.writeFile(pythonScript, content);

        console.log('Setup completed successfully!');
    } catch (error) {
        console.error('Setup failed:', error);
        process.exit(1);
    }
}

main(); 