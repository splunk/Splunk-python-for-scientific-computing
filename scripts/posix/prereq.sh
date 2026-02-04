#!/bin/bash
# Prerequisites and environment setup for PSC build system
# Sets up common variables, paths, and utility functions used across all build scripts

# Application configuration
APP_NAME="Splunk_SA_Scientific_Python"

# Directory structure setup
PROJECT_DIR=$(cd "$(dirname $(dirname $(dirname "${BASH_SOURCE[0]}")))" && pwd)
OS="$(uname)"
ARCH="$(uname -m)"
PLATFORM="$(echo "${OS}_$ARCH" | tr '[:upper:]' '[:lower:]')"
PLATFORM_DIR="$PROJECT_DIR/$PLATFORM"

# Build directories
BASE_BUILD_DIR="$PROJECT_DIR/build"
MICROMAMBA_BUILD_DIR="$BASE_BUILD_DIR/micromamba"
VENV_BUILD_DIR="$BASE_BUILD_DIR/venv"
APP_BUILD_DIR="$BASE_BUILD_DIR/${APP_NAME}_$PLATFORM"
DIST_BUILD_DIR="$APP_BUILD_DIR/bin/$PLATFORM"

# Package and archive paths
PACK_FILE_PATH="$BASE_BUILD_DIR/miniconda-repack.tar.gz"
MAMBA_PACK_FILE_PATH="$BASE_BUILD_DIR/micromamba-repack.tar.bz2"

# Tool executables
CONDA="$MINICONDA_BUILD_DIR/bin/conda"
MICROMAMBA="$MICROMAMBA_BUILD_DIR/bin/micromamba"

# Virtual environment configuration
MAMBA_ROOT_PREFIX=$VENV_BUILD_DIR
MAMBA_VENV_PREFIX="$VENV_BUILD_DIR/envs/base"

# Platform validation - ensure we're running on a supported platform
if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
  : # Linux x86_64 supported
elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "x86_64" ]; then
  : # macOS x86_64 supported
elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "arm64" ]; then
  : # macOS ARM64 supported
else
  echo "[ERROR] This script does not support platform \"`uname`\", aborting."
  exit 1
fi

# Utility function to check if required environment variables are set
is_set() {
  if [ -z "${!1}" ]; then
    echo "[ERROR] Environment variable $1 is required but not set"
    exit 1
  fi
}