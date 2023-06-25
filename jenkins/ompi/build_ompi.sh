if [ "${ci_test_build}" = "yes" ]
then
    if [ "${ci_test_use_ucx_branch}" = "yes" ]
    then
        fold "Building UCX"
        export ucx_root="$WORKSPACE/ucx_local"
        git clone https://github.com/openucx/ucx -b ${ci_test_ucx_branch} "${ucx_root}"
        (cd "${ucx_root}";\
            ./autogen.sh;\
            ./contrib/configure-release --prefix="${ucx_root}/install";\
            make -j"$(nproc)" install; )
        export UCX_DIR=$ucx_root/install

       # We need to override LD_LIBRARY_PATH because.
       # `module load hpcx-gcc-stack` will pull the legacy
       # UCX files that will interfere with our custom-built
       # UCX during configuration and the runtime I guess
        export LD_LIBRARY_PATH="${UCX_DIR}/lib:${LD_LIBRARY_PATH}"
        endfold
    fi

    fold "Building Open MPI..."

    if [ -x "autogen.sh" ]
    then
        autogen_script="./autogen.sh"
    else
        autogen_script="./autogen.pl"
    fi

    # control mellanox platform file, select various configure flags
    export mellanox_autodetect="yes"
    export mellanox_debug="yes"

    configure_args="--with-platform=contrib/platform/mellanox/optimized --with-ompi-param-check --enable-picky ${extra_conf}"

    ${autogen_script}
    echo "./configure ${configure_args} --prefix=${OMPI_HOME}" | bash -xeE
    make "${make_opt}" install
    endfold

    if [ "${ci_test_check}" = "yes" ]
    then
        fold "OMPI Make check"
        make "${make_opt}" check || exit 12
        endfold
    fi
fi