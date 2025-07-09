# NoFluxo Backend

## Tesseract OCR Setup

The application uses Tesseract OCR for processing PDF files. The Tesseract binary is automatically downloaded and configured during the build process (`npm run build`). The setup script:

1. Detects your operating system (Windows, macOS, or Linux)
2. Downloads the appropriate Tesseract binary
3. Downloads the Portuguese language data
4. Configures the Python script to use the local Tesseract installation

### Requirements

- Windows: 7-Zip must be installed for extracting the Windows binary
- Linux: Build tools (gcc, make) for compiling from source
- macOS: No additional requirements

### Troubleshooting

If you encounter issues with Tesseract:

1. Delete the `tesseract` directory in the project root
2. Run `npm run setup-tesseract` to reinstall Tesseract
3. Check the console output for any error messages

If problems persist, you can install Tesseract manually:

- Windows: Download from [UB-Mannheim](https://github.com/UB-Mannheim/tesseract/wiki)
- macOS: `brew install tesseract`
- Linux: `sudo apt-get install tesseract-ocr`

Then update the path in `parse-pdf/pdf_parser_final.py`. 