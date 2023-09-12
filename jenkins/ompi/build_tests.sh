if [ "${ci_test_examples}" = "yes" ]; then
    exe_dir="${OMPI_HOME}/examples"

    if [ ! -d "${exe_dir}" ]; then
        echo "Running examples for ${OMPI_HOME}"
        fold "building OMPI examples"
        cp -prf "${WORKSPACE}/examples" "${OMPI_HOME}"
        (
            PATH="${OMPI_HOME}/bin:$PATH" LD_LIBRARY_PATH="${OMPI_HOME}/lib:${LD_LIBRARY_PATH}" make -C "${exe_dir}" all
        )
        endfold
    fi

    for exe in hello_c ring_c; do
        exe_path="${exe_dir}/$exe"
        (
            fold "mpi_runner ${exe}"
            set +u
            PATH="${OMPI_HOME}/bin:$PATH" LD_LIBRARY_PATH="${OMPI_HOME}/lib:${LD_LIBRARY_PATH}" mpi_runner 4 "${exe_path}"
            set -u
            endfold
        )
    done

    if [ "${ci_test_oshmem}" = "yes" ]; then
        for exe in hello_oshmem oshmem_circular_shift oshmem_shmalloc oshmem_strided_puts oshmem_symmetric_data; do
            fold "oshmem_runner ${exe}"
            exe_path="${exe_dir}/$exe"
            (
                set +u
                PATH="${OMPI_HOME}/bin:$PATH" LD_LIBRARY_PATH="${OMPI_HOME}/lib:${LD_LIBRARY_PATH}" oshmem_runner 4 "${exe_path}"
                set -u
            )
            endfold
        done

        if [ "$(command -v clang)" ]; then
            if [ -f "${OMPI_HOME}/include/pshmem.h" ]; then
                pshmem_def="-DENABLE_PSHMEM"
            fi

            clang "${abs_path}/c11_test.c" -std=c11 ${pshmem_def} -o /tmp/c11_test -I"${OMPI_HOME}/include" \
                -L"${OMPI_HOME}/lib" -loshmem
        fi
    fi
fi
