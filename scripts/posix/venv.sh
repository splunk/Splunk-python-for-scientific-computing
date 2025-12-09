SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"
RED='\033[31m'
RESET='\033[0m'

if [ "$OS" = "Darwin" ] && [ "$ARCH" = "x86_64" ]; then
  export CONDA_OVERRIDE_OSX="11"
fi


if [ -z "$ENVIRONMENT_FILE" ]; then
  ENVIRONMENT_FILE="$PLATFORM_DIR/environment.yml";
  SOLVER="libmamba";
else
  ENVIRONMENT_FILE="$PROJECT_DIR/$ENVIRONMENT_FILE";
  SOLVER="classic";
fi

BLACKLISTED_PACKAGES=$(cat "$PLATFORM_DIR/blacklist.txt" | tr "\n" " ")

rm -r "$VENV_BUILD_DIR"

"$CONDA" config --remove channels defaults || true
"$CONDA" config --set channel_priority strict
"$CONDA" config --show channels
"$CONDA" config --show channel_priority

"$CONDA" install --prefix "$VENV_BUILD_DIR" -n base conda-libmamba-solver
#"$CONDA" config --prefix "$VENV_BUILD_DIR" --set solver libmamba
"$CONDA" env create --prefix "$VENV_BUILD_DIR" -f "$ENVIRONMENT_FILE" "--solver=$SOLVER"
eval "$($CONDA shell.bash hook)"

conda activate "$VENV_BUILD_DIR"
conda clean -tipy
"$CONDA" remove -p "$VENV_BUILD_DIR" -y --force $BLACKLISTED_PACKAGES || true

"$CONDA" list -p "$VENV_BUILD_DIR" | sed -E "s|(pkgs/[^ ]+)|${RED}\1${RESET}|g"
