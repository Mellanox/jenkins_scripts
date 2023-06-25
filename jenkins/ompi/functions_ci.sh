#############################
#
#  function output end of group symbol fro GA "::endgroup::"
#  no args
#  no returns
# 
function endfold() {
    echo "::endgroup::"
}
#############################
#
#  function output start of group symbol fro GA "::endgroup::"
#  $1 name of fold (string)
#  no returns
# 
function fold() {
    echo "::group::$1"
}

function mpi_runner() {
    AFFINITY=${AFFINITY_GLOB}

    if [ "$1" = "--no-bind" ]; then
        AFFINITY=""
        shift
    fi

    local np="$1"
    local exe_path="$2"
    local exe_args="$3"
    local common_mca="--bind-to none"
    local mpirun="${OMPI_HOME}/bin/mpirun"
    common_mca="${common_mca} ${mpi_timeout}"

    if [ "${ci_test_hcoll}" = "no" ]; then
        common_mca="${common_mca} --mca coll ^hcoll"
    fi

    local mca="${common_mca}"

    #    for hca_dev in $(ibstat -l)
    #    do
    if [ -f "${exe_path}" ]; then
        local hca="${hca_dev}:${hca_port}"
        mca="${common_mca} -x UCX_NET_DEVICES=$hca"

        echo "Running ${exe_path} ${exe_args}"
        # shellcheck disable=SC2086
        ${timeout_exe} "$mpirun" --np "$np" $mca --mca pml ucx ${AFFINITY} "${exe_path}" "${exe_args}"
    fi
    #    done
}

function oshmem_runner() {
    AFFINITY=${AFFINITY_GLOB}

    if [ "$1" = "--no-bind" ]; then
        AFFINITY=""
        shift
    fi

    local np=$1
    local exe_path="$2"
    local exe_args=${3}
    local spml_ucx="--mca spml ucx"
    local oshrun="${OMPI_HOME}/bin/oshrun"
    local common_mca="--bind-to none -x SHMEM_SYMMETRIC_HEAP_SIZE=256M"
    common_mca="${common_mca} ${mpi_timeout}"

    if [ "${ci_test_hcoll}" = "no" ]; then
        common_mca="${common_mca} --mca coll ^hcoll"
    fi

    local mca="$common_mca"

    "${OMPI_HOME}/bin/oshmem_info" -a -l 9

    #    for hca_dev in $(ibstat -l)
    #    do
    if [ -f "${exe_path}" ]; then
        local hca="${hca_dev}:${hca_port}"
        mca="${common_mca}"
        mca="$mca -x UCX_NET_DEVICES=$hca"
        mca="$mca --mca rmaps_base_dist_hca $hca --mca sshmem_verbs_hca_name $hca"
        echo "Running ${exe_path} ${exe_args}"
        # shellcheck disable=SC2086
        ${timeout_exe} "$oshrun" --np "$np" $mca ${spml_ucx} --mca pml ucx --mca btl ^vader,tcp,openib,uct ${AFFINITY} "${exe_path}" "${exe_args}"
    fi
    #    done
}

function on_start() {
    echo "Starting on host: $(hostname)"

    export distro_name
    distro_name=$(python3 -c "import distro; os_distribution = distro.id(); os_distribution_lower = os_distribution.lower(); print(os_distribution_lower)")

    export distro_ver
    distro_ver=$(python3 -c "import distro; os_version = distro.version(); os_version_lower = os_version.lower(); print(os_version_lower)")

    if [ "${distro_name}" = "suse" ]; then
        patch_level=$(grep -E PATCHLEVEL /etc/SuSE-release | cut -f2 -d= | sed -e "s/ //g")
        if [ -n "${patch_level}" ]; then
            export distro_ver="${distro_ver}.${patch_level}"
        fi
    fi

    echo "${distro_name} -- ${distro_ver}"

    # save current environment to support debugging
    env | sed -ne "s/\(\w*\)=\(.*\)\$/export \1='\2'/p" >"$WORKSPACE/test_env.sh"
    chmod 755 "$WORKSPACE/test_env.sh"
}

function on_exit {
    rc=$((rc + $?))
    echo exit code=$rc
    if [ $rc -ne 0 ]; then
        # TODO: when rpmbuild fails, it leaves folders w/o any permissions even for owner
        # removing of such files may fail
        find "$topdir" -type d -exec chmod +x {} \;
    fi
}

function test_tune() {
    echo "check if mca_base_env_list parameter is supported in ${OMPI_HOME}"
    val=$("${OMPI_HOME}/bin/ompi_info" --param mca base --level 9 | grep --count mca_base_env_list || true)
    val=0 #disable all mca_base_env_list tests until ompi schizo is fixed

    mca="--mca pml ucx --mca btl ^vader,tcp,openib,uct"

    if [ "$val" -gt 0 ]; then
        #TODO disabled, need to re-visit for Open MPI 5.x
        #echo "test mca_base_env_list option in ${OMPI_HOME}"
        #export XXX_C=3 XXX_D=4 XXX_E=5
        ## shellcheck disable=SC2086
        #val=$("${OMPI_HOME}/bin/mpirun" $mca --np 2 --mca mca_base_env_list 'XXX_A=1;XXX_B=2;XXX_C;XXX_D;XXX_E' env | grep --count ^XXX_ || true)
        #if [ "$val" -ne 10 ]
        #then
        #    exit 1
        #fi

        # check amca param
        echo "mca_base_env_list=XXX_A=1;XXX_B=2;XXX_C;XXX_D;XXX_E" >"$WORKSPACE/test_amca.conf"
        # shellcheck disable=SC2086
        val=$("${OMPI_HOME}/bin/mpirun" $mca --np 2 --tune "$WORKSPACE/test_amca.conf" "${abs_path}/env_mpi" | grep --count ^XXX_ || true)
        if [ "$val" -ne 10 ]; then
            exit 1
        fi
    fi

    # testing -tune option (mca_base_envar_file_prefix mca parameter) which supports setting both mca and env vars
    echo "check if mca_base_envar_file_prefix parameter (a.k.a -tune cmd line option) is supported in ${OMPI_HOME}"
    val=$("${OMPI_HOME}/bin/ompi_info" --param mca base --level 9 | grep --count mca_base_envar_file_prefix || true)
    val=0 #disable all mca_base_env_list tests until ompi schizo is fixed
    if [ "$val" -gt 0 ]; then
        echo "test -tune option in ${OMPI_HOME}"
        echo "-x XXX_A=1 -x XXX_B=2 -x XXX_C -x XXX_D -x XXX_E" >"$WORKSPACE/test_tune.conf"
        # next line with magic sed operation does the following:
        # 1. cut all patterns XXX_.*= from the begining of each line, only values of env vars remain.
        # 2. replace \n by + at each line
        # 3. sum all values of env vars with given pattern.
        # shellcheck disable=SC2086
        val=$("${OMPI_HOME}/bin/mpirun" $mca --np 2 --tune "$WORKSPACE/test_tune.conf" -x XXX_A=6 "${abs_path}/env_mpi" | sed -n -e 's/^XXX_.*=//p' | sed -e ':a;N;$!ba;s/\n/+/g' | bc)
        # precedence goes left-to-right.
        # A is set to 1 in "tune" and then reset to 6 with the -x option
        # B is set to 2 in "tune"
        # C, D, E are taken from the environment as 3,4,5
        # return (6+2+3+4+5)*2=40
        if [ "$val" -ne 40 ]; then
            exit 1
        fi

        echo "--mca mca_base_env_list \"XXX_A=1;XXX_B=2;XXX_C;XXX_D;XXX_E\"" >"$WORKSPACE/test_tune.conf"
        # shellcheck disable=SC2086
        val=$("${OMPI_HOME}/bin/mpirun" $mca --np 2 --tune "$WORKSPACE/test_tune.conf" "${abs_path}/env_mpi" | sed -n -e 's/^XXX_.*=//p' | sed -e ':a;N;$!ba;s/\n/+/g' | bc)
        # precedence goes left-to-right.
        # A is set to 1 in "tune"
        # B is set to 2 in "tune"
        # C, D, E are taken from the environment as 3,4,5
        # return (1+2+3+4+5)*2=30
        if [ "$val" -ne 30 ]; then
            exit 1
        fi

        echo "--mca mca_base_env_list \"XXX_A=1;XXX_B=2;XXX_C;XXX_D;XXX_E\"" >"$WORKSPACE/test_tune.conf"
        # shellcheck disable=SC2086
        val=$("${OMPI_HOME}/bin/mpirun" $mca -np 2 --tune "$WORKSPACE/test_tune.conf" --mca mca_base_env_list \
            "XXX_A=7;XXX_B=8" "${abs_path}/env_mpi" | sed -n -e 's/^XXX_.*=//p' | sed -e ':a;N;$!ba;s/\n/+/g' | bc)
        # precedence goes left-to-right.
        # A is set to 1 in "tune", and then reset to 7 in the --mca parameter
        # B is set to 2 in "tune", and then reset to 8 in the --mca parameter
        # C, D, E are taken from the environment as 3,4,5
        # return (7+8+3+4+5)*2=54
        if [ "$val" -ne 54 ]; then
            exit 1
        fi

        # echo "--mca mca_base_env_list \"XXX_A=1;XXX_B=2;XXX_C;XXX_D;XXX_E\"" > "$WORKSPACE/test_tune.conf"
        # echo "mca_base_env_list=XXX_A=7;XXX_B=8" > "$WORKSPACE/test_amca.conf"
        # A is first set to 1 in "tune", and then reset to 7 in "amca".  <==== this is NOT allowed
        # B is first set to 2 in "tune", but then reset to 8 in "amca"   <==== this is NOT allowed
        #
        # REPLACEMENT:
        # A is set to 7 in "tune"
        # B is set to 8 in "amca"
        # C, D, E are taken from the environment as 3,4,5
        # return (7+8+3+4+5)*2=54
        echo "--mca mca_base_env_list \"XXX_A=7;XXX_C;XXX_D;XXX_E\"" >"$WORKSPACE/test_tune.conf"
        echo "mca_base_env_list=XXX_B=8" >"$WORKSPACE/test_amca.conf"
        # shellcheck disable=SC2086
        val=$("${OMPI_HOME}/bin/mpirun" $mca --np 2 --tune "$WORKSPACE/test_tune.conf" \
            --am "$WORKSPACE/test_amca.conf" "${abs_path}/env_mpi" | sed -n -e 's/^XXX_.*=//p' | sed -e ':a;N;$!ba;s/\n/+/g' | bc)
        if [ "$val" -ne 54 ]; then
            exit 1
        fi

        # echo "--mca mca_base_env_list \"XXX_A=1;XXX_B=2;XXX_C;XXX_D;XXX_E\"" > "$WORKSPACE/test_tune.conf"
        # echo "mca_base_env_list=XXX_A=7;XXX_B=8" > "$WORKSPACE/test_amca.conf"
        # A is first set to 1 in "tune", and then reset to 7 by "amca".  <==== this is NOT allowed
        # B is first set to 2 in "tune", but then reset to 8 in "amca"   <==== this is NOT allowed
        #
        # REPLACEMENT:
        # A is set to 7 in "tune", and then reset to 9 on the cmd line
        # B is set to 8 in "amca", and then reset to 10 on the cmd line
        # C, D, E are taken from the environment as 3,4,5
        #
        # shellcheck disable=SC2086
        echo "--mca mca_base_env_list \"XXX_A=7;XXX_C;XXX_D;XXX_E\"" >"$WORKSPACE/test_tune.conf"
        echo "mca_base_env_list=XXX_B=8" >"$WORKSPACE/test_amca.conf"
        # shellcheck disable=SC2086
        val=$("${OMPI_HOME}/bin/mpirun" $mca --np 2 --tune "$WORKSPACE/test_tune.conf" --am "$WORKSPACE/test_amca.conf" \
            --mca mca_base_env_list "XXX_A=9;XXX_B=10" "${abs_path}/env_mpi" | sed -n -e 's/^XXX_.*=//p' | sed -e ':a;N;$!ba;s/\n/+/g' | bc)
        # return (9+10+3+4+5)*2=62
        if [ "$val" -ne 62 ]; then
            exit 1
        fi

        echo "-x XXX_A=6 -x XXX_C=7 -x XXX_D=8" >"$WORKSPACE/test_tune.conf"
        echo "-x XXX_B=9 -x XXX_E" >"$WORKSPACE/test_tune2.conf"
        # shellcheck disable=SC2086
        val=$("${OMPI_HOME}/bin/mpirun" $mca --np 2 --tune "$WORKSPACE/test_tune.conf,$WORKSPACE/test_tune2.conf" \
            "${abs_path}/env_mpi" | sed -n -e 's/^XXX_.*=//p' | sed -e ':a;N;$!ba;s/\n/+/g' | bc)
        # precedence goes left-to-right.
        # A is set to 6 in "tune"
        # B is set to 9 in "tune2"
        # C is set to 7 in "tune"
        # D is set to 8 in "tune"
        # E is taken from the environment as 5
        # return (6+9+7+8+5)*2=70
        if [ "$val" -ne 70 ]; then
            exit 1
        fi
    fi
}
