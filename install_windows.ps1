<#
    ML Finance
    Windows setup script

    Run from PowerShell:
        irm https://raw.githubusercontent.com/diegolealgon/mlfin/main/install_python_windows.ps1 | iex

    ----------------------------------------------------------------------
    What this creates
    ----------------------------------------------------------------------

      Desktop\ML_Finance\            Everything the user ever touches.
          Start Jupyter.bat            double click to work
          Check Setup.bat              double click if something breaks
          Notebooks\                   where notebook files go
          README.txt

      C:\Users\Public\mlfin\         The engine. Python and packages.

    The engine goes to the Public folder rather than the user profile for
    three reasons, all of which break conda otherwise:

      1. Conda cannot install into a path containing a space, and plenty of
         Windows usernames have one. The NSIS /D flag will not accept quotes,
         so there is no way to work around it.
      2. Windows enforces a 260 character path limit that conda's nested
         site-packages trees run into. A short root buys headroom.
      3. It is writable by a standard user, so no administrator rights are
         needed anywhere in this script.

    No administrator rights are required. Nothing is added to PATH and
    nothing is registered as the system Python, so this cannot interfere
    with other software.
#>

$ErrorActionPreference = "Stop"

# ----------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------

$ProjectName   = "ML Finance"
$InstallDir    = "C:\Users\Public\mlfin"          # engine, disposable
$EnvName       = "mlfin"
$PythonVersion = "3.11"

# "notebook" for the simpler classic interface, "lab" for full JupyterLab.
$JupyterInterface = "notebook"

$MiniforgeUrl = "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Windows-x86_64.exe"

# The Desktop is often redirected into OneDrive, so ask Windows where it is
# rather than assuming $env:USERPROFILE\Desktop.
$DesktopRoot  = [Environment]::GetFolderPath("Desktop")
$DesktopDir   = Join-Path $DesktopRoot "ML_Finance"
$NotebookDir  = Join-Path $DesktopDir "Notebooks"

$EnvDir  = Join-Path $InstallDir "python\envs\$EnvName"
$Conda   = Join-Path $InstallDir "python\Scripts\conda.exe"
$Pip     = Join-Path $EnvDir "Scripts\pip.exe"
$Py      = Join-Path $EnvDir "python.exe"
$Jupyter = Join-Path $EnvDir "Scripts\jupyter.exe"

function Say  { param($m) Write-Host "   $m" -ForegroundColor Green;  Write-Host "" }
function Warn { param($m) Write-Host "   $m" -ForegroundColor Yellow }
function Die  {
    param($m)
    Write-Host ""
    Write-Host "   $m" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Press Enter to close this window."
    Read-Host | Out-Null
    exit 1
}

# ----------------------------------------------------------------------
# Banner
# ----------------------------------------------------------------------

Write-Host ""
Write-Host "   ======================================================" -ForegroundColor Green
Write-Host "     $ProjectName"                                         -ForegroundColor Green
Write-Host "     Setup for Windows"                                    -ForegroundColor Green
Write-Host "   ======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   This takes about ten minutes. You can leave it running."
Write-Host "   Do not close this window until it says it is finished."
Write-Host ""

# ----------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------

# 64 bit only. Miniforge publishes no 32 bit Windows build.
if (-not [Environment]::Is64BitOperatingSystem) {
    Die "This needs 64 bit Windows. Please ask whoever sent you this installer."
}

# ARM machines can run the x64 build under emulation, but it is slow and
# some packages have no matching wheel. Warn rather than block.
if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") {
    Warn "NOTE: this is an ARM based PC. The install should work but may be slow."
    Write-Host ""
}

if (-not (Test-Path $DesktopRoot)) {
    Die "Could not find your Desktop folder. Please ask whoever sent you this installer."
}

# Reinstall rebuilds the engine only. Notebooks and the saved key survive.
if (Test-Path $InstallDir) {
    Warn "It looks like you have installed this before."
    Warn "Python will be rebuilt from scratch, which takes several minutes."
    Write-Host ""
    Warn "Anything in 'Notebooks' will NOT be touched, and your saved"
    Warn "API key will be kept."
    Write-Host ""
    Write-Host "   Type 'yes' and press Enter to continue."
    Write-Host ""
    $confirmation = Read-Host "                       "
    if ($confirmation -ne "yes") { Die "Setup cancelled. Nothing was changed." }
    try {
        Remove-Item -Recurse -Force $InstallDir
    } catch {
        Die "Could not remove the old installation. Close Jupyter if it is running, then try again."
    }
    Write-Host ""
}

try {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
} catch {
    Die "Could not create $InstallDir. Please ask whoever sent you this installer."
}

# ----------------------------------------------------------------------
# Python
# ----------------------------------------------------------------------

$installer = Join-Path $env:TEMP "Miniforge3.exe"

Say "Step 1 of 5: downloading Python..."
try {
    # The progress bar slows large downloads dramatically in PowerShell 5.
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $MiniforgeUrl -OutFile $installer
    $ProgressPreference = 'Continue'
} catch {
    Die "Download failed. Check your internet connection and try again."
}

Say "Step 2 of 5: installing Python. This takes a few minutes..."
# /D must come last and must NOT be quoted. That is a quirk of the NSIS
# installer, and the reason the install path cannot contain a space.
$installArgs = "/InstallationType=JustMe /RegisterPython=0 /AddToPath=0 /S /D=$InstallDir\python"
$proc = Start-Process -FilePath $installer -ArgumentList $installArgs -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Die "Python installation failed. Please ask whoever sent you this installer."
}
Remove-Item $installer -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $Conda)) {
    Die "Python did not install where expected. Please ask whoever sent you this installer."
}

Say "Step 3 of 5: creating the Python environment..."
& $Conda create -y -q -n $EnvName "python=$PythonVersion" 2>&1 | Out-Null
if (-not (Test-Path $Py)) {
    Die "Could not create the Python environment. Please ask whoever sent you this installer."
}

# ----------------------------------------------------------------------
# Packages
# ----------------------------------------------------------------------

$assets = Join-Path $InstallDir "assets"
New-Item -ItemType Directory -Force -Path $assets | Out-Null

$requirements = @'
# --- Core runtime -----------------------------------------------------
jupyterlab==4.2.5
notebook==7.2.2
ipywidgets==8.1.5
python-dotenv==1.0.1
tqdm==4.66.5
requests==2.32.3

# --- Data and plotting ------------------------------------------------
pandas==2.2.3
numpy==1.26.4
scipy==1.13.1
matplotlib==3.9.2
seaborn==0.13.2
plotly==5.24.1
openpyxl==3.1.5
xlsxwriter==3.2.0

# --- Tabular and time series modelling --------------------------------
scikit-learn==1.5.2
statsmodels==0.14.4
xgboost==2.1.1
lightgbm==4.5.0
numpy-financial==1.0.0
yfinance==0.2.44
pandas-datareader==0.10.0

# --- Text and language ------------------------------------------------
nltk==3.9.1
tiktoken==0.7.0
transformers==4.44.2
sentence-transformers==3.1.1
datasets==2.21.0
openai==1.51.0
pypdf==5.0.1
beautifulsoup4==4.12.3
lxml==5.3.0
edgartools==2.28.1

# --- Retrieval and vector stores --------------------------------------
chromadb==0.5.11
faiss-cpu==1.8.0.post1

# --- Graphs and images ------------------------------------------------
networkx==3.3
pillow==10.4.0

# --- Explainability and fairness --------------------------------------
shap==0.46.0
fairlearn==0.11.0
'@

$heavy = @'
# Optional. PyTorch (CPU build, roughly 200 MB) plus the reinforcement
# learning stack. Only needed to run transformer fine tuning or the
# reinforcement learning notebooks locally instead of in the cloud.
#
#   C:\Users\Public\mlfin\python\envs\mlfin\Scripts\pip.exe install ^
#       -r C:\Users\Public\mlfin\assets\requirements-heavy.txt ^
#       --extra-index-url https://download.pytorch.org/whl/cpu

torch==2.4.1
accelerate==0.34.2
gymnasium==0.29.1
stable-baselines3==2.3.2
'@

# ASCII, so pip never trips over a byte order mark on the first line.
[IO.File]::WriteAllText((Join-Path $assets "requirements.txt"), $requirements, [Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path $assets "requirements-heavy.txt"), $heavy, [Text.Encoding]::ASCII)

Say "Step 4 of 5: installing packages. This is the slow part..."
& $Pip install --no-input -q -r (Join-Path $assets "requirements.txt")
if ($LASTEXITCODE -ne 0) {
    Die "Package installation failed. Please send a screenshot of this window to whoever sent you this installer."
}

# Clear kernel name, so the picker is unambiguous if another Python exists.
& $Py -m ipykernel install --user --name $EnvName --display-name "ML_Finance (Python $PythonVersion)" 2>&1 | Out-Null

# ----------------------------------------------------------------------
# Desktop folder
# ----------------------------------------------------------------------

Say "Step 5 of 5: creating your Desktop folder..."

New-Item -ItemType Directory -Force -Path $NotebookDir | Out-Null

$envFile = Join-Path $NotebookDir ".env"
if (-not (Test-Path $envFile)) {
    [IO.File]::WriteAllText($envFile, "LLM_API_KEY=`"`"`r`n", [Text.Encoding]::ASCII)
} else {
    Say "        Found your saved API key, keeping it."
}

[IO.File]::WriteAllText(
    (Join-Path $NotebookDir ".gitignore"),
    ".env`r`n.ipynb_checkpoints/`r`n__pycache__/`r`n*.pyc`r`n",
    [Text.Encoding]::ASCII)

# ---------------------------- diagnostic ------------------------------
# Embedded rather than downloaded, so the whole install is a single
# network call and cannot half succeed.

$checkScript = @'
"""
ML Finance
Installation check

Run this after installing, and any time something breaks. If you need help,
paste the ENTIRE output of this script into your message when asking for help.
It redacts your API key automatically, so it is safe to share.

    Normally you do not run this by hand. Double click the "Check Setup" file
    inside the "ML_Finance" folder on your Desktop.
"""

import importlib
import os
import platform
import sys
from pathlib import Path

# Packages required by every notebook. Tuple is (import name, pip name).
CORE = [
    ("jupyterlab", "jupyterlab"),
    ("dotenv", "python-dotenv"),
    ("pandas", "pandas"),
    ("numpy", "numpy"),
    ("scipy", "scipy"),
    ("matplotlib", "matplotlib"),
    ("seaborn", "seaborn"),
    ("sklearn", "scikit-learn"),
    ("statsmodels", "statsmodels"),
    ("xgboost", "xgboost"),
    ("yfinance", "yfinance"),
]

# Packages required only by the text and language notebooks.
LANGUAGE = [
    ("nltk", "nltk"),
    ("tiktoken", "tiktoken"),
    ("transformers", "transformers"),
    ("sentence_transformers", "sentence-transformers"),
    ("openai", "openai"),
    ("pypdf", "pypdf"),
    ("bs4", "beautifulsoup4"),
    ("chromadb", "chromadb"),
    ("faiss", "faiss-cpu"),
    ("edgar", "edgartools"),
]

# Optional heavy packages. Absence is not an error.
OPTIONAL = [
    ("torch", "torch"),
    ("gymnasium", "gymnasium"),
]


def rule(title):
    print()
    print(title)
    print("=" * 60)


def check_group(name, packages, required=True):
    rule(name)
    missing = []
    for import_name, pip_name in packages:
        try:
            mod = importlib.import_module(import_name)
            version = getattr(mod, "__version__", "unknown")
            print(f"  OK      {pip_name:<24} {version}")
        except Exception as exc:
            label = "MISSING" if required else "absent "
            print(f"  {label} {pip_name:<24} ({type(exc).__name__})")
            missing.append(pip_name)
    return missing


def redact(secret):
    """Show enough of the key to identify it, not enough to use it."""
    if not secret:
        return "(empty)"
    if len(secret) <= 12:
        return "(too short to be valid)"
    return f"{secret[:7]}...{secret[-4:]}"


def check_llm():
    rule("4. LLM endpoint")

    try:
        from dotenv import load_dotenv
    except ImportError:
        print("  SKIP    python-dotenv is not installed, cannot read the key file")
        return

    # Look for .env next to this script's parent, then in the notebooks folder.
    home = Path.home()
    candidates = [
        home / "Desktop" / "ML_Finance" / "Notebooks" / ".env",
        # Windows Desktop is often redirected into OneDrive.
        home / "OneDrive" / "Desktop" / "ML_Finance" / "Notebooks" / ".env",
        Path.cwd() / ".env",   # if run from inside Jupyter
    ]
    env_path = next((p for p in candidates if p.exists()), None)

    if env_path is None:
        print("  MISSING No key file found. Expected it at:")
        print(f"          {candidates[0]}")
        print("          Re-run the setup script.")
        return

    print(f"  Found   .env at {env_path}")
    load_dotenv(env_path)

    key = os.getenv("LLM_API_KEY", "").strip()

    print(f"  Key     {redact(key)}")

    if not key:
        print()
        print("  No key saved yet. This is fine if you do not need it yet.")
        print("  When you have one, start Jupyter from the ML_Finance folder")
        print("  and paste the key when asked.")
        return

    # The server address lives in the notebooks, not here, so this file
    # carries no endpoint. If an address happens to be available we use it
    # to confirm the key works. If not, we check everything else and stop.
    base = os.getenv("LLM_BASE_URL", "").strip()

    if not base:
        print("  URL     not set, so the connection was not tested")
        print()
        print("  Everything that can be checked without contacting the server")
        print("  has been checked above. If your notebook cannot connect, the")
        print("  problem is most likely the network rather than this setup.")
        return

    print(f"  URL     {base}")

    try:
        from openai import OpenAI
    except ImportError:
        print("  SKIP    openai package is not installed")
        return

    print()
    print("  Sending a test request...")

    try:
        client = OpenAI(api_key=key, base_url=base, timeout=30.0)
        models = client.models.list()
        names = [m.id for m in models.data]
        print(f"  OK      Endpoint reachable. Models available: {', '.join(names) or 'none listed'}")

        target = names[0] if names else "default"
        reply = client.chat.completions.create(
            model=target,
            messages=[{"role": "user", "content": "Reply with exactly the word: connected"}],
            max_tokens=10,
        )
        print(f"  OK      Test completion returned: {reply.choices[0].message.content.strip()!r}")

    except Exception as exc:
        print(f"  FAILED  {type(exc).__name__}: {exc}")
        print()
        print("  Common causes, in the order worth checking:")
        print("    1. You are not connected to the campus VPN.")
        print("    2. Your key was typed with a missing or extra character.")
        print("    3. You have used your full quota.")
        print("    4. The server is down. Check for any posted announcements.")


def main():
    rule("1. System")
    print(f"  Python      {sys.version.split()[0]}")
    print(f"  Executable  {sys.executable}")
    print(f"  Platform    {platform.platform()}")
    print(f"  Machine     {platform.machine()}")

    if sys.version_info < (3, 10):
        print()
        print("  WARNING: Python is older than 3.10. Re-run the setup script.")

    missing_core = check_group("2. Core packages", CORE)
    missing_lang = check_group("3. Text and language packages", LANGUAGE)
    check_group("3b. Optional heavy packages", OPTIONAL, required=False)

    check_llm()

    rule("Summary")
    if not missing_core and not missing_lang:
        print("  Everything required is installed.")
    else:
        for group, missing in (("core", missing_core), ("language", missing_lang)):
            if missing:
                print(f"  Missing {group} packages: {', '.join(missing)}")
        print()
        print("  Re-run the setup script rather than installing these by hand.")
        print("  Mixed versions cause problems that are hard to debug.")
    print()


if __name__ == "__main__":
    main()
'@
[IO.File]::WriteAllText((Join-Path $assets "check_install.py"), $checkScript, [Text.Encoding]::UTF8)

# ---------------------------- launcher --------------------------------
# Plain batch rather than PowerShell, so execution policy is irrelevant.

$launcher = @"
@echo off
setlocal enabledelayedexpansion
title ${ProjectName}

set "JUPYTER=${Jupyter}"
set "NOTEBOOKS=${NotebookDir}"
set "ENVFILE=${NotebookDir}\.env"

cls
echo.
echo    ${ProjectName}
echo    ======================================================
echo.

if not exist "%JUPYTER%" (
    echo    Something is wrong with your Python installation.
    echo.
    echo    Please run the setup script again.
    echo.
    pause
    exit /b 1
)

if not exist "%NOTEBOOKS%" (
    echo    Your 'Notebooks' folder is missing.
    echo.
    echo    Please run the setup script again.
    echo.
    pause
    exit /b 1
)

rem Ask for the API key on first run, so nobody has to find a hidden file.
set "CURRENTKEY="
if exist "%ENVFILE%" (
    for /f "usebackq delims=" %%A in (`findstr /b "LLM_API_KEY=" "%ENVFILE%"`) do (
        set "RAW=%%A"
        set "RAW=!RAW:LLM_API_KEY=!"
        set "RAW=!RAW:~1!"
        set "RAW=!RAW:"=!"
        set "CURRENTKEY=!RAW!"
    )
)

if "!CURRENTKEY!"=="" (
    echo    You have not entered your API key yet.
    echo.
    echo    You may not need it right away. You can skip this for now
    echo    and enter it later.
    echo.
    echo    Paste your key and press Enter, or just press Enter to skip.
    echo.
    set /p "TYPEDKEY=   Key: "
    set "TYPEDKEY=!TYPEDKEY: =!"
    set "TYPEDKEY=!TYPEDKEY:	=!"
    if not "!TYPEDKEY!"=="" (
        > "%ENVFILE%" echo LLM_API_KEY="!TYPEDKEY!"
        echo.
        echo    Key saved. You will not be asked again.
    ) else (
        echo.
        echo    Skipped. You will be asked again next time.
    )
    echo.
    timeout /t 2 /nobreak >nul
)

cls
echo.
echo    ${ProjectName}
echo    ======================================================
echo.
echo    Starting Jupyter. Your browser will open in a moment.
echo.
echo    Save any notebook files you receive into:
echo        Desktop \ ML_Finance \ Notebooks
echo.
echo    Keep this window open while you work.
echo    To stop, close this window or press Ctrl and C together.
echo.

cd /d "%NOTEBOOKS%"
"%JUPYTER%" ${JupyterInterface}
"@

[IO.File]::WriteAllText((Join-Path $DesktopDir "Start Jupyter.bat"), $launcher, [Text.Encoding]::ASCII)

# ---------------------------- checker ---------------------------------

$checker = @"
@echo off
title Check Setup
cls
"${Py}" "${assets}\check_install.py"
echo.
echo    ======================================================
echo    Copy everything above and include it when you ask for help.
echo    Your API key is hidden, so it is safe to send.
echo    ======================================================
echo.
pause
"@

[IO.File]::WriteAllText((Join-Path $DesktopDir "Check Setup.bat"), $checker, [Text.Encoding]::ASCII)

# ---------------------------- readme ----------------------------------

$readme = @"
${ProjectName}
======================================================

HOW TO START WORKING
--------------------
Double click "Start Jupyter.bat" in this folder.
Your browser will open with your notebooks listed.


WHEN YOU RECEIVE A NOTEBOOK FILE
--------------------------------
Download it, then drag it into the "Notebooks" folder inside
this folder. It will show up in Jupyter straight away.

If you already have Jupyter open, you can also drag the file directly
onto the file list in your browser. That does the same thing.


IF SOMETHING BREAKS
-------------------
Double click "Check Setup.bat" in this folder. Copy everything
in the window that opens and include it when you ask for help. It
hides your API key automatically, so it is safe to send.


PLEASE DO NOT
-------------
Do not move or rename this folder.
Do not move or rename the "mlfin" folder in C:\Users\Public. You will
not normally see it, and you never need to open it, but deleting it
will stop everything from working.
"@

[IO.File]::WriteAllText((Join-Path $DesktopDir "README.txt"), $readme, [Text.Encoding]::ASCII)

# ----------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------

Write-Host ""
Write-Host "   ======================================================" -ForegroundColor Green
Write-Host "     All done."                                            -ForegroundColor Green
Write-Host "   ======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "   Look on your Desktop for a folder called:"
Write-Host "       ML_Finance"
Write-Host ""
Write-Host "   Open it and double click:"
Write-Host "       Start Jupyter.bat"
Write-Host ""
Write-Host "   Save any notebook files you receive into the"
Write-Host "   'Notebooks' folder inside it."
Write-Host ""
Write-Host "   You can close this window now."
Write-Host ""

# Open the folder so the user sees it immediately.
try { Invoke-Item $DesktopDir } catch { }
