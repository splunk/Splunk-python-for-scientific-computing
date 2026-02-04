SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

rm "$MAMBA_PACK_FILE_PATH"

"$MICROMAMBA" package compress "$MAMBA_VENV_PREFIX" "$MAMBA_PACK_FILE_PATH" --compression-level 9

echo "Successfully packed environment into $MAMBA_PACK_FILE_PATH"