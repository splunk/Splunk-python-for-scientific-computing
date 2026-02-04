#!/bin/bash
# Downloads and installs Micromamba with platform-specific binaries
# Verifies checksums and sets up the base conda environment

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"
source "$SCRIPT_DIR/micromamba_settings.sh"

# Verify required environment variables are set
is_set MICROMAMBA_VERSION
is_set LINUX_64_SHA256
is_set LINUX_AARCH64_SHA256
is_set LINUX_PPC64LE_SHA256
is_set DARWIN_64_SHA256
is_set DARWIN_ARM64_SHA256

# Determine platform-specific Micromamba binary
if [ "$OS" = "Linux" ]; then
  if [ "$ARCH" = "x86_64" ]; then
    MICROMAMBA_FILE="micromamba-linux-64"
  # Note: Other Linux architectures are commented out - currently focusing on x86_64 only
  # elif [ "$ARCH" = "aarch64" ]; then
  #   MICROMAMBA_FILE="micromamba-linux-aarch64"
  # elif [ "$ARCH" = "ppc64le" ]; then
  #   MICROMAMBA_FILE="micromamba-linux-ppc64le"
  else
    echo "[ERROR] Unsupported Linux architecture: $ARCH"
    exit 1
  fi
elif [ "$OS" = "Darwin" ]; then
  if [ "$ARCH" = "x86_64" ]; then
    MICROMAMBA_FILE="micromamba-osx-64"
  elif [ "$ARCH" = "arm64" ]; then
    MICROMAMBA_FILE="micromamba-osx-arm64"
  else
    echo "[ERROR] Unsupported macOS architecture: $ARCH"
    exit 1
  fi
else
  echo "[ERROR] Unsupported operating system: $OS"
  exit 1
fi

# Setup download paths
MICROMAMBA_DOWNLOAD_PATH="$BASE_BUILD_DIR/$MICROMAMBA_FILE"

# Clean up previous installations and create directories
rm -f "$MICROMAMBA_PATH"
rm -f "$MICROMAMBA_DOWNLOAD_PATH"
mkdir -p "$BASE_BUILD_DIR"

rm -rf "$MICROMAMBA_BUILD_DIR"
mkdir -p "$MICROMAMBA_BUILD_DIR/bin"

echo "[INFO] Micromamba build directory: $MICROMAMBA_BUILD_DIR"

# Download Micromamba if not already present
if [ ! -f "$MICROMAMBA_DOWNLOAD_PATH" ]; then
  if command -v curl; then
    echo "[INFO] Downloading Micromamba..."
    curl -o "$MICROMAMBA_DOWNLOAD_PATH" \
         "https://github.com/mamba-org/micromamba-releases/releases/download/$MICROMAMBA_VERSION/$MICROMAMBA_FILE" \
         -fsSL
  else
    echo "[ERROR] cURL not installed, cannot download Micromamba"
    exit 1
  fi
fi

# Set expected checksum based on platform
if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
  TARGET_CHECKSUM="$LINUX_64_SHA256"
# Commented out architectures not currently supported
# elif [ "$OS" = "Linux" ] && [ "$ARCH" = "aarch64" ]; then
#   TARGET_CHECKSUM="$LINUX_AARCH64_SHA256"
# elif [ "$OS" = "Linux" ] && [ "$ARCH" = "ppc64le" ]; then
#   TARGET_CHECKSUM="$LINUX_PPC64LE_SHA256"
elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "x86_64" ]; then
  TARGET_CHECKSUM="$DARWIN_64_SHA256"
elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ]; then
  TARGET_CHECKSUM="$DARWIN_ARM64_SHA256"
fi

# Verify file integrity with SHA256 checksum
MICROMAMBA_CHECKSUM=$(sha256sum "$MICROMAMBA_DOWNLOAD_PATH" | awk '{print $1}')
echo "[INFO] Computed SHA256: $MICROMAMBA_CHECKSUM"
echo "[INFO] Expected SHA256: $TARGET_CHECKSUM"

if [ "$MICROMAMBA_CHECKSUM" != "$TARGET_CHECKSUM" ]; then
  echo "[ERROR] Checksum verification failed! File may be corrupted."
  exit 1
fi

# Install Micromamba and set permissions
cp "$MICROMAMBA_DOWNLOAD_PATH" "$MICROMAMBA"
chmod +x "${MICROMAMBA}"

# Create base environment with PyTorch and required packages
echo "[INFO] Creating base conda environment..."
"$MICROMAMBA" create -r "$MICROMAMBA_BUILD_DIR" -n base -c conda-forge pytorch --strict-channel-priority -y

# Activate environment and install additional packages
source "$MICROMAMBA_BUILD_DIR/etc/profile.d/micromamba.sh"
"$MICROMAMBA" activate base

echo "[INFO] Installing additional packages..."
"$MICROMAMBA" install -r "$MICROMAMBA_BUILD_DIR" -n base -c conda-forge \
              conda-pack conda-tree pytorch --strict-channel-priority -y