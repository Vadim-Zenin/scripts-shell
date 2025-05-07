#!/bin/bash
# Description: This script installs a predefined set of VSCode extensions.
# Tested on: Kubuntu 24.04
# Usage: ./dev-stack/vscode_plugins.sh
# Version: 202505071517

echo "Installing extensions..."

# List of extensions with correct IDs
extensions=(
    "ms-python.python"
    "ms-python.pylance"
    "ms-toolsai.jupyter"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-ssh-edit"
    "mads-hartmann.bash-ide-vscode"
    "timonwong.shellcheck"
    "rogalmic.bash-debug"
    "formulahendry.code-runner"
    "ms-azuretools.vscode-docker"
    "eamodio.gitlens"
    "shardulm94.trailing-spaces"
    "esbenp.prettier-vscode"
    "vscode-icons-team.vscode-icons"
    "DavidAnson.vscode-markdownlint"
)

# Function to check if an extension is installed
is_installed() {
    code --list-extensions | grep -q "^$1$"
}

installed_extensions=()

for extension in "${extensions[@]}"; do
    if is_installed "$extension"; then
        echo "Extension '$extension' is already installed."
    else
        echo "Installing extension: $extension"
        code --install-extension "$extension" && installed_extensions+=("$extension") || echo "Failed installing extension: $extension"
    fi
done

# Summary of installed extensions
echo "Summary of installed extensions:"
for installed in "${installed_extensions[@]}"; do
    echo "- $installed"
done

echo "Installation process completed!"
