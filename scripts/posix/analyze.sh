SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

CONDA_TREE="$MINICONDA_BUILD_DIR/bin/conda-tree"
"$CONDA_TREE" -p "$VENV_BUILD_DIR" deptree
