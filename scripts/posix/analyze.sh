#!/bin/bash
# Analyzes the dependency tree of the Python environment
# Uses conda-tree to generate a visual representation of package dependencies

# Import common variables and functions from prerequisites
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

# Path to the conda-tree executable installed in the micromamba environment
CONDA_TREE="$MICROMAMBA_BUILD_DIR/bin/conda-tree"

echo "[INFO] Analyzing dependency tree for environment: $MAMBA_VENV_PREFIX"

# Generate dependency tree analysis
# This shows how packages depend on each other in a tree structure
# Helps identify which packages are pulling in specific dependencies
"$CONDA_TREE" -p "$MAMBA_VENV_PREFIX" deptree

echo "[INFO] Dependency analysis complete"