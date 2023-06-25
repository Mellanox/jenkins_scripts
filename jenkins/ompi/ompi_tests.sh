if [ "${ci_test_threads}" = "yes" ]
then
    ci_test_hcoll_bkp="${ci_test_hcoll}"
    exe_dir="${OMPI_HOME}/thread_tests"

    if [ ! -d "${exe_dir}" ]
    then
        pushd .
        mkdir -p "${exe_dir}"
        cd "${exe_dir}"

        # Keep this test locally to avoid future connection problems
        wget --no-check-certificate http://www.mcs.anl.gov/~thakur/thread-tests/thread-tests-1.1.tar.gz
        ###--->   cp /hpc/local/mpitests/thread-tests-1.1.tar.gz .
        tar zxf thread-tests-1.1.tar.gz
        cd thread-tests-1.1
        make CC="${OMPI_HOME}/bin/mpicc"
        popd
    fi

    # Disable HCOLL for the MT case
    ci_test_hcoll="no"

    for exe in overlap latency
    do
        exe_path="${exe_dir}/thread-tests-1.1/$exe"
        (
            set +u
            PATH="${OMPI_HOME}/bin:$PATH" LD_LIBRARY_PATH="${OMPI_HOME}/lib:${LD_LIBRARY_PATH}" mpi_runner --no-bind 4 "${exe_path}"
            set -u
        )
    done

    for exe in latency_th bw_th message_rate_th
    do
        exe_path="${exe_dir}/thread-tests-1.1/$exe"
        (
            set +u
            PATH="${OMPI_HOME}/bin:$PATH" LD_LIBRARY_PATH="${OMPI_HOME}/lib:${LD_LIBRARY_PATH}" mpi_runner --no-bind 2 "${exe_path}" 4
            set -u
        )
    done

    ci_test_hcoll="${ci_test_hcoll_bkp}"
fi

for mpit in "${abs_path}"/*.c
do
    out_name="$(basename "$mpit" .c)"
    "${OMPI_HOME}/bin/mpicc" -o "${abs_path}/${out_name}" "$mpit" /GIT/ompi/ompi_install/lib/liboshmem.so
done