#!/bin/bash
#
# ML Finance
# macOS setup script
#
# Download this file, then run it from Terminal:
#   bash ~/Downloads/install_mac.sh
#
# ----------------------------------------------------------------------
# What this creates
# ----------------------------------------------------------------------
#
#   ~/Desktop/ML_Finance/          Everything the user ever touches.
#       Start Jupyter.command        double click to work
#       Check Setup.command          double click if something breaks
#       Notebooks/                   where notebook files go
#       README.txt
#
#   ~/mlfin/                       The engine. Python and packages.
#                                  Deliberately NOT on the Desktop: a conda
#                                  install is several GB across hundreds of
#                                  thousands of files, and if the user has
#                                  iCloud syncing their Desktop, macOS will
#                                  try to upload all of it. Users are never
#                                  told this folder exists.

set -e

# ----------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------

PROJECT_NAME="ML Finance"

DESKTOP_DIR="${HOME}/Desktop/ML_Finance"        # visible, user facing
NOTEBOOK_DIR="${DESKTOP_DIR}/Notebooks"         # where notebook files go
INSTALL_DIR="${HOME}/mlfin"                     # hidden engine, disposable

ENV_NAME="mlfin"
PYTHON_VERSION="3.11"

# "notebook" for the simpler classic interface, "lab" for full JupyterLab.
JUPYTER_INTERFACE="notebook"

# Optional CA certificate for the LLM endpoint. Leave empty to skip.
# Only needed if the endpoint uses a certificate issued by a private CA
# rather than a publicly trusted one.
CA_CERT_URL="https://raw.githubusercontent.com/diegolealgon/mlfin/main/ca.crt"

if [[ "$(uname -m)" == "arm64" ]]; then
    MINIFORGE="Miniforge3-MacOSX-arm64.sh"
else
    MINIFORGE="Miniforge3-MacOSX-x86_64.sh"
fi
MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/${MINIFORGE}"

ENV_DIR="${INSTALL_DIR}/python/envs/${ENV_NAME}"
CONDA="${INSTALL_DIR}/python/bin/conda"
PIP="${ENV_DIR}/bin/pip"
PY="${ENV_DIR}/bin/python"
JUPYTER="${ENV_DIR}/bin/jupyter"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
PREFIX='   '

LOG_FILE="${INSTALL_DIR}/install_log.txt"

say()  { printf "${PREFIX}${GREEN}%s${NC}\n\n" "$1"; }
warn() { printf "${PREFIX}${YELLOW}%s${NC}\n" "$1"; }
die()  {
    printf "\n${PREFIX}${RED}%s${NC}\n\n" "$1"
    if [ -f "$LOG_FILE" ]; then
        printf "${PREFIX}%s\n" "A detailed log was saved to:"
        printf "${PREFIX}%s\n\n" "$LOG_FILE"
    fi
    exit 1
}

# ----------------------------------------------------------------------
# Banner
# ----------------------------------------------------------------------

printf "\n"
printf "${PREFIX}${GREEN}%s${NC}\n" "======================================================"
printf "${PREFIX}${GREEN}%s${NC}\n" "  ${PROJECT_NAME}"
printf "${PREFIX}${GREEN}%s${NC}\n" "  Setup for macOS"
printf "${PREFIX}${GREEN}%s${NC}\n" "======================================================"
printf "\n"
printf "${PREFIX}%s\n"   "This takes about ten minutes. You can leave it running."
printf "${PREFIX}%s\n\n" "Do not close this window until it says it is finished."

# ----------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------

# Conda cannot handle spaces in its own install path.
case "$INSTALL_DIR" in
    *" "*) die "Your home folder path contains a space, which Python cannot handle here. Please ask whoever sent you this installer." ;;
esac

if [ -n "$CONDA_PREFIX" ]; then
    warn "NOTE: another Python environment is currently active."
    warn "      If this install fails, run 'conda deactivate' and try again."
    printf "\n"
fi

# Reinstall rebuilds the engine only. Notebooks and the saved key survive.
if [ -d "$INSTALL_DIR" ]; then
    warn "It looks like you have installed this before."
    warn "Python will be rebuilt from scratch, which takes several minutes."
    printf "\n"
    warn "Anything in 'Notebooks' will NOT be touched, and your saved"
    warn "API key will be kept."
    printf "\n"
    printf "${PREFIX}%s\n\n" "Type 'yes' and press Return to continue."
    printf "${PREFIX}%s" "                    > "
    read confirmation
    if [ "$confirmation" != "yes" ]; then
        die "Setup cancelled. Nothing was changed."
    fi
    rm -rf "$INSTALL_DIR"
    printf "\n"
fi

mkdir -p "$INSTALL_DIR"

# ----------------------------------------------------------------------
# Python
# ----------------------------------------------------------------------

say "Step 1 of 5: downloading Python..."
curl -L "$MINIFORGE_URL" -o "/tmp/${MINIFORGE}" > /dev/null 2>&1 \
    || die "Download failed. Check your internet connection and try again."

say "Step 2 of 5: installing Python. This takes a few minutes..."
bash "/tmp/${MINIFORGE}" -b -p "${INSTALL_DIR}/python" >> "$LOG_FILE" 2>&1 \
    || die "Python installation failed. Please ask whoever sent you this installer."
rm -f "/tmp/${MINIFORGE}"

say "Step 3 of 5: creating the Python environment..."
"$CONDA" create -y -q -n "$ENV_NAME" "python=${PYTHON_VERSION}" >> "$LOG_FILE" 2>&1 \
    || die "Could not create the Python environment."

[ -x "$PY" ] || die "Python did not install where expected. Please ask whoever sent you this installer."

# ----------------------------------------------------------------------
# Packages
# ----------------------------------------------------------------------

mkdir -p "${INSTALL_DIR}/assets"

cat > "${INSTALL_DIR}/assets/requirements.txt" << 'REQUIREMENTS_EOF'
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

# --- Fairness ---------------------------------------------------------
fairlearn==0.11.0
REQUIREMENTS_EOF

cat > "${INSTALL_DIR}/assets/requirements-heavy.txt" << 'HEAVY_EOF'
# Optional. PyTorch (CPU build, roughly 200 MB) plus the reinforcement
# learning stack. Only needed to run transformer fine tuning or the
# reinforcement learning notebooks locally instead of in the cloud.
#
#   ~/mlfin/python/envs/mlfin/bin/pip install \
#       -r ~/mlfin/assets/requirements-heavy.txt \
#       --extra-index-url https://download.pytorch.org/whl/cpu

torch==2.4.1
accelerate==0.34.2
gymnasium==0.29.1
stable-baselines3==2.3.2

# shap pulls in numba and llvmlite. When pip cannot find a matching
# llvmlite wheel it tries to compile it, which needs CMake and fails on a
# clean machine. Installing numba from conda-forge first avoids that
# entirely, because conda ships a prebuilt llvmlite:
#
#   <conda> install -y numba
#   <pip> install shap==0.46.0
shap==0.46.0
HEAVY_EOF

say "Step 4 of 5: installing packages. This is the slow part..."
"$PIP" install --no-input -q -r "${INSTALL_DIR}/assets/requirements.txt" >> "$LOG_FILE" 2>&1 \
    || die "Package installation failed. Please send a screenshot of this window to whoever sent you this installer."

# Clear kernel name, so the picker is unambiguous if another Python exists.
"$PY" -m ipykernel install --user \
    --name "$ENV_NAME" \
    --display-name "ML_Finance (Python ${PYTHON_VERSION})" >> "$LOG_FILE" 2>&1 || true

# ----------------------------------------------------------------------
# Desktop folder
# ----------------------------------------------------------------------

say "Step 5 of 5: creating your Desktop folder..."

mkdir -p "$NOTEBOOK_DIR"

# The key lives beside the notebooks so python-dotenv finds it from the
# working directory. The launcher writes this file, nobody edits it by hand.
if [ ! -f "${NOTEBOOK_DIR}/.env" ]; then
    cat > "${NOTEBOOK_DIR}/.env" << 'ENV_EOF'
LLM_API_KEY=""
ENV_EOF
else
    say "        Found your saved API key, keeping it."
fi

cat > "${NOTEBOOK_DIR}/.gitignore" << 'GITIGNORE_EOF'
.env
.ipynb_checkpoints/
__pycache__/
*.pyc
GITIGNORE_EOF

# ---------------------------- certificate -----------------------------
# The endpoint uses a certificate from a private CA, which Python will not
# trust by default. Setting SSL_CERT_FILE does not help: the openai package
# uses httpx, which ignores that variable and loads certifi's bundle. So we
# append the CA to certifi's bundle inside this environment. Nothing outside
# ~/mlfin is touched, and notebooks then need no special TLS handling.
#
# This step is allowed to fail. The certificate is only needed for the LLM
# labs, so a network hiccup here should not sink the whole install.

if [ -n "$CA_CERT_URL" ]; then
    if curl -fsSL "$CA_CERT_URL" -o "${INSTALL_DIR}/assets/ca.crt" 2>>"$LOG_FILE"; then

        # Sanity check before trusting the download. A captive portal or a
        # 404 page would otherwise be appended to the trust store.
        if grep -q "BEGIN CERTIFICATE" "${INSTALL_DIR}/assets/ca.crt"; then

            BUNDLE="$("$PY" -c 'import certifi; print(certifi.where())' 2>>"$LOG_FILE")"

            if [ -n "$BUNDLE" ] && [ -f "$BUNDLE" ]; then
                # Keep a pristine copy, so re-running never double-appends.
                if [ ! -f "${BUNDLE}.original" ]; then
                    cp "$BUNDLE" "${BUNDLE}.original"
                fi
                cat "${BUNDLE}.original" > "$BUNDLE"
                printf '\n' >> "$BUNDLE"
                cat "${INSTALL_DIR}/assets/ca.crt" >> "$BUNDLE"
                echo "certificate appended to $BUNDLE" >> "$LOG_FILE"

                # A copy beside the notebooks, for anything that needs a path.
                cp "${INSTALL_DIR}/assets/ca.crt" "${NOTEBOOK_DIR}/ca.crt"
            else
                echo "could not locate certifi bundle" >> "$LOG_FILE"
            fi
        else
            echo "downloaded ca.crt is not a certificate, ignoring" >> "$LOG_FILE"
            rm -f "${INSTALL_DIR}/assets/ca.crt"
        fi
    else
        echo "certificate download failed, continuing without it" >> "$LOG_FILE"
    fi
fi

# ---------------------------- diagnostic ------------------------------
# Embedded rather than downloaded, so the whole install is a single
# network call and cannot half succeed.

cat > "${INSTALL_DIR}/assets/check_install.py" << 'CHECK_PY_EOF'
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


def show_log_tail(lines=25):
    """The install log is the only record of what conda and pip actually did."""
    log = Path(__file__).resolve().parent.parent / "install_log.txt"
    if not log.exists():
        return
    rule(f"5. Last {lines} lines of the install log")
    try:
        content = log.read_text(errors="replace").rstrip().split("\n")
    except Exception as exc:
        print(f"  Could not read the log: {exc}")
        return
    for line in content[-lines:]:
        print(f"  {line}")


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
    show_log_tail()

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
CHECK_PY_EOF

# ---------------------------- launcher --------------------------------

LAUNCHER="${DESKTOP_DIR}/Start Jupyter.command"
cat > "$LAUNCHER" << LAUNCHER_EOF
#!/bin/bash
# Double click this file to start working.

JUPYTER="${JUPYTER}"
NOTEBOOK_DIR="${NOTEBOOK_DIR}"
INTERFACE="${JUPYTER_INTERFACE}"
ENV_FILE="\${NOTEBOOK_DIR}/.env"

clear
echo ""
echo "   ${PROJECT_NAME}"
echo "   ======================================================"
echo ""

if [ ! -x "\$JUPYTER" ]; then
    echo "   Something is wrong with your Python installation."
    echo ""
    echo "   Please run the setup script again."
    echo ""
    echo "   Press Return to close this window."
    read _
    exit 1
fi

if [ ! -d "\$NOTEBOOK_DIR" ]; then
    echo "   Your 'Notebooks' folder is missing."
    echo ""
    echo "   Please run the setup script again."
    echo ""
    echo "   Press Return to close this window."
    read _
    exit 1
fi

# Ask for the API key on first run, so nobody has to find a hidden file.
CURRENT_KEY=""
if [ -f "\$ENV_FILE" ]; then
    CURRENT_KEY=\$(grep '^LLM_API_KEY=' "\$ENV_FILE" | cut -d'"' -f2)
fi

if [ -z "\$CURRENT_KEY" ]; then
    echo "   You have not entered your API key yet."
    echo ""
    echo "   You may not need it right away. You can skip this for now"
    echo "   and enter it later."
    echo ""
    echo "   Paste your key and press Return, or just press Return to skip."
    echo ""
    printf "   Key: "
    read TYPED_KEY

    TYPED_KEY=\$(echo "\$TYPED_KEY" | tr -d '[:space:]')

    if [ -n "\$TYPED_KEY" ]; then
        cat > "\$ENV_FILE" << KEYEOF
LLM_API_KEY="\$TYPED_KEY"
KEYEOF
        echo ""
        echo "   Key saved. You will not be asked again."
    else
        echo ""
        echo "   Skipped. You will be asked again next time."
    fi
    echo ""
    sleep 1
fi

clear
echo ""
echo "   ${PROJECT_NAME}"
echo "   ======================================================"
echo ""
echo "   Starting Jupyter. Your browser will open in a moment."
echo ""
echo "   Save any notebook files you receive into:"
echo "       Desktop / ML_Finance / Notebooks"
echo ""
echo "   Keep this window open while you work."
echo "   To stop, close this window or press Control and C together."
echo ""

cd "\$NOTEBOOK_DIR" || exit 1
"\$JUPYTER" "\$INTERFACE"
LAUNCHER_EOF
chmod +x "$LAUNCHER"

# ---------------------------- diagnostics -----------------------------

CHECKER="${DESKTOP_DIR}/Check Setup.command"
cat > "$CHECKER" << CHECKER_EOF
#!/bin/bash
# Double click this file if something is not working, then copy everything
# in the window and paste it into your message when asking for help.

clear
"${PY}" "${INSTALL_DIR}/assets/check_install.py"
echo ""
echo "   ======================================================"
echo "   Copy everything above and paste it into your email."
echo "   Your API key is hidden, so it is safe to send."
echo "   ======================================================"
echo ""
echo "   Press Return to close this window."
read _
CHECKER_EOF
chmod +x "$CHECKER"

# ---------------------------- readme ----------------------------------

cat > "${DESKTOP_DIR}/README.txt" << README_EOF
${PROJECT_NAME}
======================================================

HOW TO START WORKING
--------------------
Double click "Start Jupyter.command" in this folder.
Your browser will open with your notebooks listed.


WHEN YOU RECEIVE A NOTEBOOK FILE
--------------------------------
Download it, then drag it into the "Notebooks" folder inside
this folder. It will show up in Jupyter straight away.

If you already have Jupyter open, you can also drag the file directly
onto the file list in your browser. That does the same thing.


IF SOMETHING BREAKS
-------------------
Double click "Check Setup.command" in this folder. Copy everything
in the window that opens and include it when you ask for help. It
hides your API key automatically, so it is safe to send.


PLEASE DO NOT
-------------
Do not move or rename this folder.
Do not move or rename the "mlfin" folder in your home folder. You will
not normally see it, and you never need to open it, but deleting it
will stop everything from working.
README_EOF

# ----------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------

printf "\n"
printf "${PREFIX}${GREEN}%s${NC}\n" "======================================================"
printf "${PREFIX}${GREEN}%s${NC}\n" "  All done."
printf "${PREFIX}${GREEN}%s${NC}\n" "======================================================"
printf "\n"
printf "${PREFIX}%s\n"   "Look on your Desktop for a folder called:"
printf "${PREFIX}%s\n\n" "    ML_Finance"
printf "${PREFIX}%s\n"   "Open it and double click:"
printf "${PREFIX}%s\n\n" "    Start Jupyter.command"
printf "${PREFIX}%s\n"   "Save any notebook files you receive into the"
printf "${PREFIX}%s\n\n" "'Notebooks' folder inside it."
printf "${PREFIX}%s\n\n" "You can close this window now."

# Open the folder so the user sees it immediately.
open "$DESKTOP_DIR" 2>/dev/null || true
