#!/bin/bash
# Description: This script installs VS Code, sets up a Python virtual environment, and installs necessary packages.
# Tested on: Kubuntu 24.04
# Usage
# open a termial and provide password for sudo command:
# sudo ls
# run in the terminal:
# ./dev-stack/vscode-deploy.sh
# Version: 202505071517

set -e

INSTALL_DIR="${HOME}/tools/vscode"
PYTHON_VERSION="3.13"
VENV_DIR="${INSTALL_DIR}/.venv"

f_check_package() {
  if ! dpkg -s "$1" &> /dev/null; then
    echo "Installing $1..."
    sudo apt install -y "$1"
  else
    echo "$1 is already installed."
  fi
}

# Create installation directory
mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

# Ensure Python version and virtual environment are installed
echo "Checking if python${PYTHON_VERSION} and virtual environment are installed..."
f_check_package python${PYTHON_VERSION}-venv

# Create virtual environment
echo "Creating virtual environment at ${VENV_DIR}..."
python${PYTHON_VERSION} -m venv ${VENV_DIR}

# Activate virtual environment
source ${VENV_DIR}/bin/activate

echo "Upgrading pip..."
pip install --upgrade pip

echo "Installing Hugging Face Transformers and Ollama integration..."
pip install transformers ollama

# Check and install required packages for VS Code
echo "Checking for required packages for Visual Studio Code..."
REQUIRED_PACKAGES=(
  libx11-xcb1
  libxss1
  libasound2t64
  libgtk-3-0
  libx11-6
  libxkbfile1
)

for package in "${REQUIRED_PACKAGES[@]}"; do
  f_check_package "$package"
done

# Download and install VS Code
echo "Downloading and installing Visual Studio Code..."
wget -O /tmp/code_latest.deb https://go.microsoft.com/fwlink/?LinkID=760868 && sudo dpkg -i /tmp/code_latest.deb && rm -f /tmp/code_latest.deb

# Create a symbolic link to the VS Code executable
mkdir -p "${INSTALL_DIR}/bin"
ln -sf /usr/share/code/bin/code "${INSTALL_DIR}/bin/vscode"

# Install Python extension for VS Code
echo "Installing VS Code Python extension..."
"${INSTALL_DIR}/bin/vscode" --install-extension ms-python.python --force

# Restart VS Code
echo "Restarting VS Code..."
"${INSTALL_DIR}/bin/vscode" --reload

# Summary
echo "Deployment complete!"
echo "Virtual environment created at: ${VENV_DIR}"
echo "Installed packages: transformers, ollama"
echo "VS Code installed and Python extension configured."
echo "To activate the environment: source ${VENV_DIR}/bin/activate"
echo "Launch VS Code with: ${INSTALL_DIR}/bin/vscode"

