# Install dependencies for the latest Einstein Toolkit, as well as thorns
# that are under development. This image works for cuda as well as generic
# cpu installations. This image is available on dockerhub as stevenrbrandt/etworkshop.
#
# Use it, or this file, at your peril. :)
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive

# Basic packages needed. We chose a slightly newer version of gcc than is available by default.
# cvs is only needed by the LORENE package (installed by spack below).
RUN apt update -y && \
    apt-get install -y git curl vim gfortran-10 subversion make cmake xz-utils file \
    emacs locales locales-all nvidia-driver-535 \
    python3-pip python3-dev zip python3-sympy python3-numpy python3-matplotlib ffmpeg gdb g++-10 cvs && \
    rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10
RUN update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-10 10

ENV PATH /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

ENV BASE /usr/cactus

RUN useradd -m jovyan -s /bin/bash -d $BASE

COPY spack-setup.sh /usr/local/bin
RUN chmod +x /usr/local/bin/spack-setup.sh
USER jovyan

# Basically checks out spack and finds the compilers.
RUN spack-setup.sh

ENV SPACK_SKIP_MODULES 1
ENV SPACK_ROOT $BASE/spack-root
ENV SPACK_PYTHON /usr/bin/python3
ENV PATH $SPACK_ROOT/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

RUN ${SPACK_ROOT}/bin/spack external find --not-buildable perl diffutils findutils fortran tar pkgconf zlib cuda 

# Here we create the spack installation for the gpu. Most of them take the defaults.
# The exceptions are:
#  1) AMReX: We use spack develop to preserve the source code. This may be important for this package.
#  2) hdf5
#  3) silo
#  4) boost
ENV SPACK_ENV_NAME=gpu
RUN spack env create $SPACK_ENV_NAME

ENV AMREX_VER 23.09 +shared +particles build_type=RelWithDebInfo +openmp

# Avoid having multiple versions of packages
RUN spack -e $SPACK_ENV_NAME config add concretizer:reuse:true
RUN spack -e $SPACK_ENV_NAME config add concretizer:unify:true

RUN spack -e $SPACK_ENV_NAME add netlib-lapack gsl silo+hdf5 hdf5+hl+fortran+cxx+mpi mpich openssl fftw papi hwloc adios2 boost+system+filesystem googletest gperftools nsimd openblas ssht yaml-cpp openpmd-api lorene cuda amrex@${AMREX_VER} +cuda
RUN spack -e $SPACK_ENV_NAME develop -p $BASE/amrex+cuda amrex @${AMREX_VER} +cuda

RUN spack -e $SPACK_ENV_NAME concretize -f
RUN spack -e $SPACK_ENV_NAME install --fail-fast 

# Make a thornlist for the gpu.
RUN mkdir -p $BASE/bin/
COPY --chown=jovyan mk-cfg-gpu.sh $BASE/bin/mk-cfg-gpu.sh
RUN chmod 755 $BASE/bin/mk-cfg-gpu.sh
WORKDIR $BASE
RUN $BASE/bin/mk-cfg-gpu.sh

ENV SPACK_ENV_NAME=cpu
RUN ${SPACK_ROOT}/bin/spack env create $SPACK_ENV_NAME

# Avoid having multiple versions of packages
RUN spack -e $SPACK_ENV_NAME config add concretizer:reuse:true
RUN spack -e $SPACK_ENV_NAME config add concretizer:unify:true

RUN spack -e $SPACK_ENV_NAME add netlib-lapack gsl silo+hdf5 hdf5+hl+fortran+cxx+mpi mpich openssl fftw papi hwloc adios2 boost+system+filesystem googletest gperftools nsimd openblas ssht yaml-cpp openpmd-api lorene amrex@${AMREX_VER} ~cuda
RUN spack -e $SPACK_ENV_NAME develop -p $BASE/amrex~cuda amrex @${AMREX_VER} ~cuda

RUN spack -e $SPACK_ENV_NAME concretize -f
RUN spack -e $SPACK_ENV_NAME install --fail-fast 

# Make a thornlist for the cpu.
COPY --chown=jovyan mk-cfg-cpu.sh $BASE/bin/mk-cfg-cpu.sh
RUN chmod 755 $BASE/bin/mk-cfg-cpu.sh
RUN $BASE/bin/mk-cfg-cpu.sh

# Just to have a convenient place for cuda.
RUN ln -s $(spack -e gpu location -i cuda) /usr/cactus/cuda

# We can't install hpctoolkit in the cpu or gpu images above
# because it installs a package called dynainst which puts
# headers into the view that conflict with headers used by
# several Cactus thorns.

# Hpctoolkit without cuda
ENV SPACK_ENV_NAME=hpctool
RUN spack env create ${SPACK_ENV_NAME}

# Avoid having multiple versions of packages
RUN spack -e $SPACK_ENV_NAME config add concretizer:reuse:true
RUN spack -e $SPACK_ENV_NAME config add concretizer:unify:true

RUN spack -e $SPACK_ENV_NAME add hpctoolkit~cuda
RUN spack -e $SPACK_ENV_NAME install --fail-fast

# Hpctoolkit with cuda
ENV SPACK_ENV_NAME=hpctoolcuda
RUN spack env create ${SPACK_ENV_NAME}

# Avoid having multiple versions of packages
RUN spack -e $SPACK_ENV_NAME config add concretizer:reuse:true
RUN spack -e $SPACK_ENV_NAME config add concretizer:unify:true

RUN spack -e $SPACK_ENV_NAME add hpctoolkit+cuda
RUN spack -e $SPACK_ENV_NAME install --fail-fast

# Without this setting the spack in this image might
# conflict with the locally installed spack.
ENV SPACK_SYSTEM_CONFIG_PATH=/usr/cactus/.spack
