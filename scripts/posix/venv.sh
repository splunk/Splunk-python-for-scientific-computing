SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

if [ -z "$ENVIRONMENT_FILE" ]; then
  ENVIRONMENT_FILE="$PLATFORM_DIR/environment.yml";
  SOLVER="libmamba";
else
  ENVIRONMENT_FILE="$PROJECT_DIR/$ENVIRONMENT_FILE";
  SOLVER="classic";
fi

BLACKLISTED_PACKAGES=$(cat "$PLATFORM_DIR/blacklist.txt" | tr "\n" " ")

rm -r "$VENV_BUILD_DIR"
"$CONDA" install --prefix "$VENV_BUILD_DIR" -n base conda-libmamba-solver
#"$CONDA" config --prefix "$VENV_BUILD_DIR" --set solver libmamba
"$CONDA" env create --prefix "$VENV_BUILD_DIR" -f "$ENVIRONMENT_FILE" "--solver=$SOLVER"
conda activate "$VENV_BUILD_DIR"
conda clean -tipy
"$CONDA" remove -p "$VENV_BUILD_DIR" -y --force $BLACKLISTED_PACKAGES || true