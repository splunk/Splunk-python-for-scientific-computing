SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

# conda-repack only generates a tar file, so we untar the resulted archive
# in place of the environment the tar was created from
rm "$PACK_FILE_PATH"
"$CONDA" pack -p "$VENV_BUILD_DIR" -o "$PACK_FILE_PATH" --ignore-missing-files --force
