#!/bin/bash
set -e
export GCC_VER=9.4.0
export AMREX_VER=23.02
export CUDA_VER=11.0.3
export SPACK_SKIP_MODULES=1

export HERE="$PWD/cactus-spack"
export SPACK_ROOT="${HERE}/root"
export SPACK_USER_CONFIG_PATH="${HERE}/.spack"
export SPACK_USER_CACHE_PATH="${HERE}/.spack"

echo "SPACK_USER_CONFIG_PATH=${SPACK_USER_CONFIG_PATH}"
echo "SPACK_USER_CACHE_PATH=${SPACK_USER_CACHE_PATH}"
echo "SPACK_ROOT=${SPACK_ROOT}"
echo

mkdir -p $HERE
if [ ! -d "$SPACK_ROOT" ]
then
  git clone https://github.com/spack/spack.git "$SPACK_ROOT"
  source "$SPACK_ROOT/share/spack/setup-env.sh"
  spack compiler find
else
  source "$SPACK_ROOT/share/spack/setup-env.sh"
fi

if [ ! -r env.sh ]
then
cat > env.sh << EOF
export HERE="$PWD/cactus-spack"
export SPACK_ROOT="${HERE}/root"
export SPACK_USER_CONFIG_PATH="${HERE}/.spack"
export SPACK_SKIP_MODULES=1

echo "SPACK_USER_CONFIG_PATH=${SPACK_USER_CONFIG_PATH}"
echo "SPACK_ROOT=${SPACK_ROOT}"
echo
source "$SPACK_ROOT/share/spack/setup-env.sh"
EOF
fi

if [ ! -r env2.sh ]
then
cat > env2.sh << EOF
  export HERE="$PWD/cactus-spack"
export SPACK_ROOT="${HERE}/root"
export SPACK_SKIP_MODULES=1

echo "SPACK_ROOT=${SPACK_ROOT}"
echo
source "$SPACK_ROOT/share/spack/setup-env.sh"
EOF
fi

mkdir -p "$SPACK_USER_CONFIG_PATH"
if [ ! -r "$SPACK_USER_CONFIG_PATH/packages.yaml" ]
then
cat > "$SPACK_USER_CONFIG_PATH/packages.yaml" << EOF
packages:
  all:
    require: "%gcc@${GCC_VER}"
    providers:
      mpi:
      - mpich
      - openmpi
  nsimd:
      version: [3.0.1]
  yaml-cpp:
      version: [0.6.3]
  hdf5:
      variants: +cxx +fortran +hl +mpi +threadsafe
  fftw:
      variants: +mpi +openmp
  adios2:
      variants: +hdf5 ~python
  boost:
      variants: cxxstd=17 +context +mpi +system +filesystem
      version: [1.77.0]
  hpctoolkit:
      variants: +mpi
  memkind:
      version: [1.10.1]
  gsl:
      version: [2.7]
  petsc:
      variants: +fftw +hwloc +openmp ~cuda
  hypre:
      variants: ~cuda
  reprimand:
      version: [1.3]
  silo:
      version: [4.10.2-bsd]
  xz:
      variants: +pic
  openpmd-api:
      variants: +python -hdf5
  cuda:
      version: [$CUDA_VER]
  amrex:
      variants: +shared +particles build_type=RelWithDebInfo
  mpich:
      variants: +fortran 
EOF
fi

# Make sure we have a few externals
spack external find --not-buildable perl diffutils findutils fortran tar xz pkgconf zlib python cuda 

## GPU Environment
if [ ! -d $SPACK_ROOT/var/spack/environments/gpu ]
then
    spack env create gpu
fi
spack env activate gpu

spack config add concretizer:reuse:true
spack config add concretizer:unify:when_possible
spack config add "packages:all:variants: +cuda"

spack add netlib-lapack silo mpich libjpeg openssl fftw papi gsl hwloc adios2 boost googletest gperftools nsimd openblas ssht yaml-cpp openpmd-api lorene cuda amrex @${AMREX_VER} 
spack develop -p /usr/amrex+cuda amrex @${AMREX_VER} +cuda

# spack spec zlib
# spack buildcache list

spack concretize -f
spack develop -p /usr/amrex+cuda amrex@${AMREX_VER}
spack install --fail-fast --keep-stage
spack env deactivate

## CPU Environment
if [ ! -d $SPACK_ROOT/var/spack/environments/cpu ]
then
    spack env create cpu
fi
spack env activate cpu

spack config add concretizer:reuse:true
spack config add concretizer:unify:when_possible
spack config add "packages:all:variants: ~cuda"

spack add netlib-lapack silo mpich libjpeg openssl fftw papi gsl hwloc adios2 boost googletest gperftools nsimd openblas ssht yaml-cpp openpmd-api lorene amrex @${AMREX_VER} ~cuda
spack develop -p /usr/amrex~cuda amrex @${AMREX_VER} ~cuda

spack install --fail-fast
spack env deactivate

## CPU Environment without AMReX
if [ ! -d $SPACK_ROOT/var/spack/environments/noamrex ]
then
    spack env create noamrex
fi
spack env activate noamrex

spack config add concretizer:reuse:true
spack config add concretizer:unify:when_possible
spack config add "packages:all:variants: ~cuda"

spack add netlib-lapack silo mpich libjpeg openssl fftw papi gsl hwloc adios2 boost googletest gperftools nsimd openblas ssht yaml-cpp openpmd-api lorene

spack install --fail-fast
spack env deactivate

export GCC_DIR="$(spack location -i gcc 2>/dev/null)"
if [ "$GCC_DIR" = "" ]
then
    export GCC_DIR=$(dirname $(dirname $(which gcc)))
fi

export CUDA_DIR="$(spack location -i cuda 2>/dev/null)"
if [ "$CUDA_DIR" = "" ]
then
    export CUDA_DIR=$(dirname $(dirname $(which nvcc)))
fi

cat > template.cfg << EOF
# Option list for the Einstein Toolkit

# The "weird" options here should probably be made the default in the
# ET instead of being set here.

# Whenever this version string changes, the application is configured
# and rebuilt from scratch
VERSION = db-2023-01-18

CPP = {GCC_DIR}/bin/cpp
FPP = {GCC_DIR}/bin/cpp
CC = {GCC_DIR}/bin/gcc
CXX = {CUDA_DIR}/bin/nvcc --compiler-bindir {GCC_DIR}/bin/g++ -x cu
FC = {GCC_DIR}/bin/gfortran
F90 = {GCC_DIR}/bin/gfortran
LD = {CUDA_DIR}/bin/nvcc --compiler-bindir {GCC_DIR}/bin/g++

CPPFLAGS = -DSIMD_CPU
CFLAGS = -pipe -g -march=native
# - We use "--relocatable-device-code=true" to allow building with
#   debug versions of AMReX
#   <https://github.com/AMReX-Codes/amrex/issues/1829>
# - We use "--objdir-as-tempdir" to prevent errors such as
#   Call parameter type does not match function signature!
#     %tmp = load double, double* %x.addr, align 8, !dbg !1483
#     float  %1 = call i32 @__isnanf(double %tmp), !dbg !1483
CXXFLAGS = -pipe -g --compiler-options -march=native -std=c++17 --compiler-options -std=gnu++17 --expt-relaxed-constexpr --extended-lambda --gpu-architecture sm_70 --forward-unknown-to-host-compiler --Werror ext-lambda-captures-this --relocatable-device-code=true --objdir-as-tempdir
FPPFLAGS = -traditional
F90FLAGS = -pipe -g -march=native -fcray-pointer -ffixed-line-length-none
LDFLAGS = -Wl,-rpath,{VIEW_DIR}/targets/x86_64-linux/lib -Wl,-rpath,/usr/local/lib -Wl,-rpath,/usr/local/nvidia/lib64
LIBS = nvToolsExt

C_LINE_DIRECTIVES = yes
F_LINE_DIRECTIVES = yes

DEBUG = no
CPP_DEBUG_FLAGS = -DCARPET_DEBUG
C_DEBUG_FLAGS = -fbounds-check -fsanitize=undefined -fstack-protector-all -ftrapv
CXX_DEBUG_FLAGS = -fbounds-check -fsanitize=undefined -fstack-protector-all -ftrapv -lineinfo
FPP_DEBUG_FLAGS = -DCARPET_DEBUG
F90_DEBUG_FLAGS = -fcheck=bounds,do,mem,pointer,recursion -finit-character=65 -finit-integer=42424242 -finit-real=nan -fsanitize=undefined -fstack-protector-all -ftrapv

OPTIMISE = yes
C_OPTIMISE_FLAGS = -O3 -fcx-limited-range -fexcess-precision=fast -fno-math-errno -fno-rounding-math -fno-signaling-nans -funsafe-math-optimizations
CXX_OPTIMISE_FLAGS = -O3 -fcx-limited-range -fexcess-precision=fast -fno-math-errno -fno-rounding-math -fno-signaling-nans -funsafe-math-optimizations
F90_OPTIMISE_FLAGS = -O3 -fcx-limited-range -fexcess-precision=fast -fno-math-errno -fno-rounding-math -fno-signaling-nans -funsafe-math-optimizations

OPENMP = yes
CPP_OPENMP_FLAGS = -fopenmp
FPP_OPENMP_FLAGS = -D_OPENMP

WARN = yes

# {GCC_DIR} does not support these
DISABLE_INT16 = yes
DISABLE_REAL16 = yes

VECTORISE = no

ADIOS2_DIR = {VIEW_DIR}
ADIOS2_LIBS = adios2_fortran_mpi adios2_cxx11_mpi adios2_core_mpi adios2_fortran adios2_cxx11 adios2_c adios2_core
AMREX_DIR = {VIEW_DIR}
ASDF_CXX_DIR = {VIEW_DIR}
BOOST_DIR = {VIEW_DIR}
FFTW3_DIR = {VIEW_DIR}
GSL_DIR = {VIEW_DIR}
HDF5_DIR = {VIEW_DIR}
HDF5_ENABLE_CXX = yes
HDF5_ENABLE_FORTRAN = yes
HDF5_INC_DIRS = {VIEW_DIR}/include
HDF5_LIB_DIRS = {VIEW_DIR}/lib
HDF5_LIBS = hdf5_hl_cpp hdf5_cpp hdf5_hl_f90cstub hdf5_f90cstub hdf5_hl_fortran hdf5_fortran hdf5_hl hdf5
HDF5_ENABLE_CXX = yes
HPX_DIR = {VIEW_DIR}
HWLOC_DIR = {VIEW_DIR}
JEMALLOC_DIR = {VIEW_DIR}
LORENE_DIR = {VIEW_DIR}
MPI_DIR = {VIEW_DIR}
MPI_INC_DIRS = {VIEW_DIR}/include
MPI_LIB_DIRS = {VIEW_DIR}/lib
MPI_LIBS = mpi
NSIMD_DIR = {VIEW_DIR}
NSIMD_INC_DIRS = {VIEW_DIR}/include
NSIMD_LIB_DIRS = {VIEW_DIR}/lib
NSIMD_ARCH = {NSIMD_ARCH}
NSIMD_SIMD = {NSIMD_ARCH}
OPENBLAS_DIR = {VIEW_DIR}
OPENPMD_API_DIR = {VIEW_DIR}
OPENPMD_DIR = {VIEW_DIR}
OPENSSL_DIR = {VIEW_DIR}
PETSC_DIR = {VIEW_DIR}
PETSC_ARCH_LIBS = m
PTHREADS_DIR = NO_BUILD
#REPRIMAND_DIR = {VIEW_DIR}
#REPRIMAND_LIBS = RePrimAnd
RNPLETAL_DIR = {VIEW_DIR}
SILO_DIR = {VIEW_DIR}
SSHT_DIR = {VIEW_DIR}
YAML_CPP_DIR = {VIEW_DIR}
ZLIB_DIR = {VIEW_DIR}
EOF
cp template.cfg local-gpu.cfg
export NSIMD_DIR=$(spack location -i nsimd)
export NSIMD_ARCH=$(ls $NSIMD_DIR/lib/libnsimd_*.so | perl -p -e 's/.*libnsimd_//'|perl -p -e 's/\.so//')
export VIEW_DIR="$HERE/root/var/spack/environments/gpu/.spack-env/view"
perl -p -i -e "s'{NSIMD_ARCH}'$NSIMD_ARCH'g" local-gpu.cfg
perl -p -i -e "s'{GCC_DIR}'$GCC_DIR'g" local-gpu.cfg
perl -p -i -e "s'{VIEW_DIR}'$VIEW_DIR'g" local-gpu.cfg
perl -p -i -e "s'{CUDA_DIR}'$CUDA_DIR'g" local-gpu.cfg

echo Create local-cpu.cfg
cat > template2.cfg << EOF
# Option list for the Einstein Toolkit

# The "weird" options here should probably be made the default in the
# ET instead of being set here.

# Whenever this version string changes, the application is configured
# and rebuilt from scratch
VERSION = db-gpu-2023-01-18

CPP = {GCC_DIR}/bin/cpp
FPP = {GCC_DIR}/bin/cpp
CC = {GCC_DIR}/bin/gcc
CXX = {GCC_DIR}/bin/g++
FC = {GCC_DIR}/bin/gfortran
F90 = {GCC_DIR}/bin/gfortran
LD = {GCC_DIR}/bin/g++

CPPFLAGS = -DSIMD_CPU
CFLAGS = -pipe -g -march=native
# - We use "--relocatable-device-code=true" to allow building with
#   debug versions of AMReX
#   <https://github.com/AMReX-Codes/amrex/issues/1829>
# - We use "--objdir-as-tempdir" to prevent errors such as
#   Call parameter type does not match function signature!
#     %tmp = load double, double* %x.addr, align 8, !dbg !1483
#     float  %1 = call i32 @__isnanf(double %tmp), !dbg !1483
CXXFLAGS = -g -std=c++17
FPPFLAGS = -traditional
F90FLAGS = -pipe -g -march=native -fcray-pointer -ffixed-line-length-none
LDFLAGS = -Wl,-rpath,{VIEW_DIR}/targets/x86_64-linux/lib -Wl,-rpath,/usr/local/lib
LIBS =

C_LINE_DIRECTIVES = yes
F_LINE_DIRECTIVES = yes

DEBUG = no
CPP_DEBUG_FLAGS = -DCARPET_DEBUG
C_DEBUG_FLAGS = -fbounds-check -fsanitize=undefined -fstack-protector-all -ftrapv
CXX_DEBUG_FLAGS = -fbounds-check -fsanitize=undefined -fstack-protector-all -ftrapv -lineinfo
FPP_DEBUG_FLAGS = -DCARPET_DEBUG
F90_DEBUG_FLAGS = -fcheck=bounds,do,mem,pointer,recursion -finit-character=65 -finit-integer=42424242 -finit-real=nan -fsanitize=undefined -fstack-protector-all -ftrapv

OPTIMISE = yes
C_OPTIMISE_FLAGS = -O3 -fcx-limited-range -fexcess-precision=fast -fno-math-errno -fno-rounding-math -fno-signaling-nans -funsafe-math-optimizations
CXX_OPTIMISE_FLAGS = -O3 -fcx-limited-range -fexcess-precision=fast -fno-math-errno -fno-rounding-math -fno-signaling-nans -funsafe-math-optimizations
F90_OPTIMISE_FLAGS = -O3 -fcx-limited-range -fexcess-precision=fast -fno-math-errno -fno-rounding-math -fno-signaling-nans -funsafe-math-optimizations

OPENMP = yes
CPP_OPENMP_FLAGS = -fopenmp
FPP_OPENMP_FLAGS = -D_OPENMP

WARN = yes

# {GCC_DIR} does not support these
DISABLE_INT16 = yes
DISABLE_REAL16 = yes

VECTORISE = no

ADIOS2_DIR = {VIEW_DIR}
ADIOS2_LIBS = adios2_fortran_mpi adios2_cxx11_mpi adios2_core_mpi adios2_fortran adios2_cxx11 adios2_c adios2_core
AMREX_DIR = {VIEW_DIR}
ASDF_CXX_DIR = {VIEW_DIR}
BOOST_DIR = {VIEW_DIR}
FFTW3_DIR = {VIEW_DIR}
GSL_DIR = {VIEW_DIR}
HDF5_DIR = {VIEW_DIR}
HDF5_ENABLE_CXX = yes
HDF5_ENABLE_FORTRAN = yes
HDF5_INC_DIRS = {VIEW_DIR}/include
HDF5_LIB_DIRS = {VIEW_DIR}/lib
HDF5_LIBS = hdf5_hl_cpp hdf5_cpp hdf5_hl_f90cstub hdf5_f90cstub hdf5_hl_fortran hdf5_fortran hdf5_hl hdf5
HDF5_ENABLE_CXX = yes
HPX_DIR = {VIEW_DIR}
HWLOC_DIR = {VIEW_DIR}
JEMALLOC_DIR = {VIEW_DIR}
LORENE_DIR = {VIEW_DIR}
MPI_DIR = {VIEW_DIR}
MPI_INC_DIRS = {VIEW_DIR}/include
MPI_LIB_DIRS = {VIEW_DIR}/lib
MPI_LIBS = mpi
NSIMD_DIR = {VIEW_DIR}
NSIMD_INC_DIRS = {VIEW_DIR}/include
NSIMD_LIB_DIRS = {VIEW_DIR}/lib
NSIMD_ARCH = {NSIMD_ARCH}
NSIMD_SIMD = {NSIMD_ARCH}
OPENBLAS_DIR = {VIEW_DIR}
OPENPMD_API_DIR = {VIEW_DIR}
OPENPMD_DIR = {VIEW_DIR}
OPENSSL_DIR = {VIEW_DIR}
PETSC_DIR = {VIEW_DIR}
PETSC_ARCH_LIBS = m
PTHREADS_DIR = NO_BUILD
#REPRIMAND_DIR = {VIEW_DIR}
#REPRIMAND_LIBS = RePrimAnd
RNPLETAL_DIR = {VIEW_DIR}
SILO_DIR = {VIEW_DIR}
SSHT_DIR = {VIEW_DIR}
YAML_CPP_DIR = {VIEW_DIR}
ZLIB_DIR = {VIEW_DIR}
EOF

cp template2.cfg local-cpu.cfg
export VIEW_DIR="$HERE/root/var/spack/environments/cpu/.spack-env/view"
perl -p -i -e "s'{NSIMD_ARCH}'$NSIMD_ARCH'g" local-cpu.cfg
perl -p -i -e "s'{GCC_DIR}'$GCC_DIR'g" local-cpu.cfg
perl -p -i -e "s'{VIEW_DIR}'$VIEW_DIR'g" local-cpu.cfg

cat template2.cfg |grep -v AMREX_DIR > local-noamrex.cfg
export VIEW_DIR="$HERE/root/var/spack/environments/noamrex/.spack-env/view"
perl -p -i -e "s'{NSIMD_ARCH}'$NSIMD_ARCH'g" local-cpu.cfg
perl -p -i -e "s'{GCC_DIR}'$GCC_DIR'g" local-cpu.cfg
perl -p -i -e "s'{VIEW_DIR}'$VIEW_DIR'g" local-cpu.cfg
#spack module tcl refresh -y
