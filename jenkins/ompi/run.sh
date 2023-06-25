#!/bin/bash -eEl
set -u
set -o pipefail
# shellcheck disable=SC2086,SC2046
REAL_PATH="$(dirname $(realpath "$0"))"

if [ "$DEBUG" = "true" ]; then
    set -x
fi

if [ -z "$WORKSPACE" ]; then
    echo "WARNING: WORKSPACE is not defined"
    WORKSPACE="$PWD"
fi

cd "$WORKSPACE"

function ci_cleanup {
    EXIT_CODE=$?
    echo "Script exited with code = ${EXIT_CODE}"

    if [ "${EXIT_CODE}" -eq 0 ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi

    exit ${EXIT_CODE}
}

trap ci_cleanup EXIT
#shellcheck source=config.sh
source "${REAL_PATH}"/config.sh
#shellcheck source=functions_ci.sh
source "${REAL_PATH}"/functions_ci.sh

if [ -d "${OMPI_HOME}" ]; then
    echo "WARNING: ${OMPI_HOME} already exists"
    ci_test_build="no"
    ci_test_check="no"
fi

if [ "${ci_test_threads}" = "yes" ]; then
    extra_conf="--enable-mpi-thread-multiple --enable-opal-multi-threads ${extra_conf}"
fi

trap "on_exit" INT TERM ILL FPE SEGV ALRM

case $1 in
build)
    fold "Preparation to build step"
    on_start
    endfold
    fold "Building UCX/OMPI"
    #shellcheck source=build_ompi.sh
    source "${REAL_PATH}"/build_ompi.sh
    endfold
    fold "Building tests"
    #shellcheck source=build_tests.sh
    source "${REAL_PATH}"/build_tests.sh
    endfold
    ;;
tests)
    echo "Running following tests:"
    set | grep ci_test_
    fold "Running test group 1"
    #shellcheck source=ompi_tests.sh
    source "${REAL_PATH}"/ompi_tests.sh
    endfold
    fold "Running test group 2"
    test_tune
    endfold
    ;;
*)
    echo "Do nothing !!!!"
    exit 1
    ;;
esac
