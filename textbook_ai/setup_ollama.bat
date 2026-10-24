@echo off
title EduLink — Ollama AI Setup
color 0B
echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║     EduLink — Offline AI (Ollama) Setup     ║
echo  ╚══════════════════════════════════════════════╝
echo.
echo  This will set up the local AI for EduLink.
echo  Ollama is already installed. Now downloading
echo  the AI model (llama3.2:3b — about 2GB).
echo.
echo  All AI runs ON YOUR PC — no internet needed!
echo.

echo [1/2] Downloading AI model (llama3.2:3b, 2GB)...
echo      This may take 10-30 minutes depending on internet speed.
echo.
ollama pull llama3.2:3b
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Could not download model.
    echo Make sure Ollama is installed and internet is connected.
    pause
    exit /b 1
)

echo.
echo [2/2] Testing the AI model...
echo "Hello, are you ready to help Ethiopian students?" | ollama run llama3.2:3b

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║       Ollama AI Ready! ✓                    ║
echo  ║                                              ║
echo  ║  Model: llama3.2:3b                         ║
echo  ║  API:   http://localhost:11434              ║
echo  ║                                              ║
echo  ║  Start Ollama server: ollama serve          ║
echo  ╚══════════════════════════════════════════════╝
echo.
pause
