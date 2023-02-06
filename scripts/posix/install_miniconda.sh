SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"
source "$SCRIPT_DIR/miniconda_settings.sh"

is_set MINICONDA_VERSION
is_set LINUX_X86_64_SHA256
is_set DARWIN_X86_64_SHA256

if [ "$OS" = "Linux" ]; then
  MINICONDA_PLATFORM="$OS-$ARCH"
elif [ "$OS" = "Darwin" ]; then
  MINICONDA_PLATFORM="MacOSX-$ARCH"
fi

MINICONDA_FILE="Miniconda3-${MINICONDA_VERSION}-${MINICONDA_PLATFORM}.sh"
MINICONDA_PATH="$BASE_BUILD_DIR/$MINICONDA_FILE"

rm $MINICONDA_PATH
mkdir -p "$BASE_BUILD_DIR"

if ! test -f "$MINICONDA_PATH"; then
  if command -v curl; then
    curl -o "$MINICONDA_PATH" "https://repo.anaconda.com/miniconda/$MINICONDA_FILE"
  else
    echo "[ERROR] cURL not installed, can not find miniconda installation file"
    exit 1
  fi
fi

if [ "$OS" = "Linux" ] && [ "$ARCH" = "x86_64" ]; then
  MINICONDA_CHECKSUM=$(sha256sum < "$MINICONDA_PATH" | awk '{print $1}')
  TARGET_CHECKSUM="$LINUX_X86_64_SHA256"
elif [ "$OS" = "Darwin" ] && [ "$ARCH" = "x86_64" ]; then
  MINICONDA_CHECKSUM=$(sha256sum < "$MINICONDA_PATH" | awk '{print $1}')
  TARGET_CHECKSUM="$DARWIN_X86_64_SHA256"
fi

if [ "$MINICONDA_CHECKSUM" != "$TARGET_CHECKSUM" ]; then
  echo "[ERROR] checksum of $MINICONDA_PATH is $MINICONDA_CHECKSUM, does not match $TARGET_CHECKSUM, please check file integrity"
  exit 1
fi


rm -rf "$MINICONDA_BUILD_DIR"

bash "$MINICONDA_PATH" -b -p "$MINICONDA_BUILD_DIR"
"$CONDA" install -y -c conda-forge conda-pack conda-tree
