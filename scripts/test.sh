#!/bin/bash

set -e
set -x

##=============================================================================
## Main configuration processing
COREMLTOOLS_HOME=$( cd "$( dirname "$0" )/.." && pwd )
COREMLTOOLS_NAME=$(basename $COREMLTOOLS_HOME)
BUILD_DIR="${COREMLTOOLS_HOME}/build"
XML_PATH="${BUILD_DIR}/py-test-report.xml"
WHEEL_PATH=""
FAST=0
SLOW=0
COV=""
CHECK_ENV=1
TIME_OUT=600

# command flag options
PYTHON="3.7"

unknown_option() {
  echo "Unknown option $1. Exiting."
  exit 1
}

print_help() {
  echo "Test the wheel by running all unit tests"
  echo
  echo "Usage: zsh -i test.sh"
  echo
  echo "  --wheel-path=*          Specify which wheel to test. Otherwise, test the current coremltools dir."
  echo "  --xml-path=*            Path to test xml file."
  echo "  --test-package=*        Test package to run."
  echo "  --python=*              Python to use for configuration."
  echo "  --requirements=*        [Optional] Path to the requirements.txt file."
  echo "  --cov=*                 Generate coverage report for these dirs."
  echo "  --fast                  Run only fast tests."
  echo "  --slow                  Run only slow tests."
  echo "  --timeout               Timeout limit (on each test)"
  echo "  --no-check-env          Don't check the environment to verify it's up to date."
  echo
  exit 0
} # end of print help

# command flag options
# Parse command line configure flags ------------------------------------------
while [ $# -gt 0 ]
  do case $1 in
    --requirements=*)    REQUIREMENTS=${1##--requirements=} ;;
    --python=*)          PYTHON=${1##--python=} ;;
    --test-package=*)    TEST_PACKAGE=${1##--test-package=} ;;
    --wheel-path=*)      WHEEL_PATH=${1##--wheel-path=} ;;
    --xml-path=*)        XML_PATH=${1##--xml-path=} ;;
    --cov=*)             COV=${1##--cov=} ;;
    --fast)              FAST=1;;
    --slow)              SLOW=1;;
    --no-check-env)      CHECK_ENV=0 ;;
    --timeout=*)         TIME_OUT=${1##--timeout=} ;;
    --help)              print_help ;;
    *) unknown_option $1 ;;
  esac
  shift
done

if [[ $TEST_PACKAGE == "" ]]; then
    echo "\"--test-package\" is a required paramter."
    exit 1
fi

# First configure
cd ${COREMLTOOLS_HOME}
if [[ $CHECK_ENV == 1 ]]; then
    zsh -i -e scripts/env_create.sh --python=$PYTHON
fi

# Setup the right python
source scripts/env_activate.sh --python=$PYTHON
echo
echo "Using python from $(which python)"
echo

if [[ $WHEEL_PATH == "" ]]; then
    cd ..
    $PIP_EXECUTABLE install -e ${COREMLTOOLS_NAME}  --upgrade --no-deps
    cd ${COREMLTOOLS_NAME}
else
    $PIP_EXECUTABLE install $~WHEEL_PATH --upgrade --no-deps --force-reinstall
fi

# Install dependencies if specified
if [ ! -z "${REQUIREMENTS}" ]; then
   $PIP_EXECUTABLE install -r "${REQUIREMENTS}"
fi

if [[ ! -z "${WHEEL_PATH}" ]]; then
   # in a test of a wheel, need to run from ${COREMLTOOLS_HOME}/coremltools for some reason.
   # otherwise pytest picks up tests in deps, env, etc.
   cd ${COREMLTOOLS_HOME}/coremltools/test
fi

# Now run the tests
echo "Running tests"

TEST_CMD=($PYTEST_EXECUTABLE -v -ra -W "ignore::UserWarning" -W "ignore::FutureWarning" -W "ignore::DeprecationWarning" --durations=100 --pyargs ${TEST_PACKAGE} --junitxml=${XML_PATH} --timeout=${TIME_OUT})

if [[ $SLOW != 1 || $FAST != 1 ]]; then
    if [[ $SLOW == 1 ]]; then
        TEST_CMD+=(-m "slow")
    elif [[ $FAST == 1 ]]; then
        TEST_CMD+=(-m "not slow")
    fi
fi

if [[ $COV != "" ]]; then
    TEST_CMD+=(--cov $COV)
fi

echo $TEST_CMD
${TEST_CMD[@]}

pip uninstall -y coremltools
