@echo off
title EduLink — Textbook AI Setup
color 0B
echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║     EduLink Textbook AI — Setup Script      ║
echo  ╚══════════════════════════════════════════════╝
echo.
echo  This will:
echo   1. Install Python dependencies
echo   2. Index ALL textbooks (Grade 1-12)
echo   3. Build the offline knowledge database
echo.
echo  NOTE: Step 2 may take 2-6 hours (runs in background)
echo  You can use your computer normally while it runs.
echo.
pause

echo.
echo [1/3] Installing Python dependencies...
pip install --pre pymupdf tqdm Pillow
if %errorlevel% neq 0 (
    echo.
    echo ERROR: pip install failed. Make sure Python is installed.
    echo Download Python from: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo      Done!

echo.
echo [2/3] Starting textbook indexer...
echo      This will process all PDFs in the "text books" folder.
echo      Progress will be shown below.
echo.
python "%~dp0indexer.py"
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Indexer failed. Check the error message above.
    pause
    exit /b 1
)

echo.
echo [3/3] Testing the database...
python "%~dp0indexer.py" --test --grade 9 --subject Mathematics --query "unit 2"

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║         Setup Complete! ✓                   ║
echo  ║                                              ║
echo  ║  Database: textbook_ai\data\textbooks.db    ║
echo  ║  Images:   textbook_ai\data\page_images\    ║
echo  ╚══════════════════════════════════════════════╝
echo.
pause
