# make a virtualenv with a shorter list of "primary" packages
# the list does not contain secondary dependencies
# after the virtualenv is made, we generate a complete list of
# all packages for a particular platform type

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

OUTPUT_PACKAGE_LIST_FILE="$PLATFORM_DIR/environment.yml"

"$CONDA" activate "$VENV_BUILD_DIR"

"$CONDA" list --explicit > "$PLATFORM_DIR/requirements.txt"

"$CONDA" env export -p "$VENV_BUILD_DIR" > "$OUTPUT_PACKAGE_LIST_FILE"
# remove the last line in the newly generated environment.yml file, since it has
# information specific to the build system, and it's not being used by conda
if [ "$OS" = "Darwin" ]; then
  sed -i '' -e '$ d' "$OUTPUT_PACKAGE_LIST_FILE"
else
  sed -i '$ d' "$OUTPUT_PACKAGE_LIST_FILE"
fi
# Remove the path of the build dir from the end result environment.yml file
if [ "$OS" = "Darwin" ]; then
  sed -i '' -e "s/${PROJECT_DIR//\//\\/}\///" "$OUTPUT_PACKAGE_LIST_FILE"
else
  sed -i "s/${PROJECT_DIR//\//\\/}\///" "$OUTPUT_PACKAGE_LIST_FILE"
fi

git diff "$OUTPUT_PACKAGE_LIST_FILE"
