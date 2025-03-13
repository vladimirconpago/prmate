#!/bin/bash

set -e  # Exit on error

INSTALL_DIR="$HOME/.tools"
SCRIPT_NAME="prmate.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
SYMLINK_PATH="/usr/local/bin/prmate"

# Function to detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) echo "linux" ;;
        *) echo "unsupported" ;;
    esac
}

OS=$(detect_os)

if [[ "$OS" == "unsupported" ]]; then
    echo "❌ Unsupported OS. Only MacOS and Linux are supported."
    exit 1
fi

# Create ~/.tools directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "📁 Creating tools directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Copy the script to ~/.tools
echo "📄 Installing prmate script to $SCRIPT_PATH"
cp prmate.sh "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

# Check if we have permission to create symlink in /usr/local/bin
if [[ -w /usr/local/bin ]]; then
    echo "🔗 Creating symlink: $SYMLINK_PATH -> $SCRIPT_PATH"
    ln -sf "$SCRIPT_PATH" "$SYMLINK_PATH"
else
    echo "⚠️ No write permissions for /usr/local/bin. Trying sudo..."
    sudo ln -sf "$SCRIPT_PATH" "$SYMLINK_PATH"
fi

# Verify installation
if command -v prmate &> /dev/null; then
    echo "✅ prmate installed successfully!"
    echo "🛠️ Run 'prmate --dry-run' to test it."
else
    echo "❌ Installation failed. Try restarting your shell or manually adding $INSTALL_DIR to PATH."
fi

