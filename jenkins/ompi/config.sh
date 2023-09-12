export PATH="/hpc/local/bin:/usr/local/bin:/bin:/usr/bin:/usr/sbin:${PATH}"

hca_dev="mlx5_0"
help_txt_list="${help_txt_list:="oshmem ompi/mca/coll/hcoll ompi/mca/pml/ucx ompi/mca/spml/ucx"}"
hca_port="${hca_port:=1}"
ci_test_build=${ci_test_build:="yes"}
ci_test_examples=${ci_test_examples:="yes"}
ci_test_oshmem=${ci_test_oshmem:="yes"}
ci_test_check=${ci_test_check:="yes"}
ci_test_threads=${ci_test_threads:="no"}
ci_test_use_ucx_branch=${ci_test_use_ucx_branch:="yes"}
ci_test_ucx_branch=${ci_test_ucx_branch:="v1.15.x"}
ci_test_hcoll=${ci_test_hcoll:="yes"}

# Ensure that we will cleanup all temp files
# even if the application will fail and won't
# do that itself
EXECUTOR_NUMBER=${EXECUTOR_NUMBER:="none"}

if [ "${EXECUTOR_NUMBER}" != "none" ]; then
    AFFINITY_GLOB="taskset -c $((2 * EXECUTOR_NUMBER)),$((2 * EXECUTOR_NUMBER + 1))"
else
    AFFINITY_GLOB=""
fi

timeout_exe=${timout_exe:="${AFFINITY_GLOB} timeout -s SIGSEGV 17m"}

mpi_timeout="--report-state-on-timeout --get-stack-traces --timeout 900"

# global mpirun options
export OMPI_MCA_mpi_warn_on_fork="0"

OMPI_HOME="$WORKSPACE/ompi_install"
topdir="$WORKSPACE/rpms"

AUTOMAKE_JOBS=$(nproc)
export AUTOMAKE_JOBS

make_opt="-j$(nproc)"
rel_path=$(dirname "$0")
abs_path=$(readlink -f "${rel_path}")
extra_conf=${extra_conf:=""}
