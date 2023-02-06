SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/prereq.sh"

# FOSSA analyze
eval "$($CONDA shell.bash hook)"
conda activate "$VENV_BUILD_DIR"
if ! command -v fossa &> /dev/null
then
  curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/fossas/fossa-cli/master/install-latest.sh | bash
fi
fossa analyze -c fossa/.fossa.yml --team "FOSSA Sandbox"
