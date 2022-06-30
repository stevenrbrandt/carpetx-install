set -e
export GCC_VER=9.4.0

export HERE="$PWD/cactus-spack"
export ENV_DIR="${HERE}/env"
export SPACK_ROOT="${HERE}/root"
export SPACK_USER_CONFIG_PATH="${HERE}/.spack"

echo "ENV_DIR=${ENV_DIR}"
echo "SPACK_USER_CONFIG_PATH=${SPACK_USER_CONFIG_PATH}"
echo "SPACK_ROOT=${SPACK_ROOT}"
echo

mkdir -p $HERE
if [ ! -d "$SPACK_ROOT" ]
then
  git clone https://github.com/spack/spack.git "$SPACK_ROOT"
  pushd "$SPACK_ROOT"
  git checkout d7fb5a6db47c8f4b84b8faa59aabf331dfcefabe
  popd
fi
perl -p -i -e 's/locks: true/locks: false/'  $SPACK_ROOT/etc/spack/defaults/config.yaml
source "$SPACK_ROOT/share/spack/setup-env.sh"

if [ ! -r env.sh ]
then
cat > env.sh << EOF
export HERE="$PWD/cactus-spack"
export ENV_DIR="${HERE}/env"
export SPACK_ROOT="${HERE}/root"
export SPACK_USER_CONFIG_PATH="${HERE}/.spack"

echo "ENV_DIR=${ENV_DIR}"
echo "SPACK_USER_CONFIG_PATH=${SPACK_USER_CONFIG_PATH}"
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
    compiler: [gcc]
    providers:
      mpi:
      - mpich
      - openmpi
  yaml-cpp:
      version: [0.6.3]
  hdf5:
      variants: +cxx +fortran +hl +mpi +threadsafe
  fftw:
      variants: +mpi +openmp
  adios2:
      variants: +hdf5 ~python
  amrex:
      variants: +cuda ~fortran ~hdf5 +openmp +particles +shared
  boost:
      variants: cxxstd=17 +context +mpi +system +filesystem
      version: [1.77.0]
  hpctoolkit:
      variants: +cuda +mpi
  memkind:
      version: [1.10.1]
  petsc:
      variants: +cuda +fftw +hwloc +openmp
  reprimand:
      version: [1.3]
  silo:
      version: [4.10.2-bsd]
  simulationio:
      variants: +asdf +hdf5 ~python +rnpl +silo
  xz:
      variants: +pic
  gcc:
      version: [11.2.0]
  openpmd-api:
      variants: +python
  python:
    buildable: False
    externals:
    - spec: python@3.8.10+bz2+ctypes+dbm+ensurepip+lzma+nis+pyexpat+pythoncmd+readline+sqlite3+ssl+tix+tkinter+uuid+zlib
      prefix: /usr
  cuda:
    buildable: False
    externals:
    - spec: cuda@11.0.3
      prefix: /usr/local/cuda
EOF
fi

if [ ! -d "$ENV_DIR" ]
then
    spack env create -d "$ENV_DIR"
fi

set +e

# Make sure we have a compiler
spack find gcc@${GCC_VER}
if [ $? = 0 ]
then
    GCC_FOUND=2
else
    spack compiler find
    grep gcc@${GCC_VER} $HERE/.spack/linux/compilers.yaml
    if [ $? = 0 ]
    then
        GCC_FOUND=1
    else
        GCC_FOUND=0
    fi
fi

# Make sure we have a few externals
spack external find perl diffutils findutils fortran cmake tar xz

# Make sure we have the exact compiler we want
if [ $GCC_FOUND != 0 ]
then
  echo gcc@${GCC_VER} was found
  set -e
else
  echo gcc@${GCC_VER} was NOT found
  set -e
  spack install --reuse gcc@${GCC_VER}
  spack load gcc@${GCC_VER}
  spack compiler find
fi

if [ $GCC_FOUND = 2 ]
then
    spack load gcc@${GCC_VER}
fi
which gfortran
which gcc
which g++
for pkg in mpich hdf5 libjpeg openssl fftw papi gsl hwloc adios2 amrex boost googletest gperftools memkind nsimd openblas rnpletal simulationio ssht yaml-cpp
do
    if grep $pkg "$ENV_DIR/spack.yaml"
    then
        echo found $pkg
    else
        spack --env-dir="$ENV_DIR" add $pkg 
    fi
done

if ! grep 'concretization: together' "$ENV_DIR/spack.yaml" >/dev/null 2>/dev/null
then
    echo "  concretization: together" >> "$ENV_DIR/spack.yaml"
    spack --env-dir="$ENV_DIR" concretize --reuse -f
fi
spack --env-dir="$ENV_DIR" install --reuse < /dev/null
set +e
rm -fr carpetx
spack view symlink -i carpetx mpich hdf5 libjpeg openssl fftw papi gsl hwloc adios2 boost googletest gperftools memkind nsimd openblas rnpletal simulationio ssht yaml-cpp
echo Create local-gpu.cfg
cat > template.cfg << EOF
# Option list for the Einstein Toolkit

# The "weird" options here should probably be made the default in the
# ET instead of being set here.

# Whenever this version string changes, the application is configured
# and rebuilt from scratch
VERSION = db-gpu-2021-11-17

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
AMREX_DIR = {AMREX_DIR}
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
#PETSC_DIR = {VIEW_DIR}
#PETSC_ARCH_LIBS = m
PTHREADS_DIR = NO_BUILD
#REPRIMAND_DIR = {VIEW_DIR}
#REPRIMAND_LIBS = RePrimAnd
RNPLETAL_DIR = {VIEW_DIR}
SILO_DIR = {VIEW_DIR}
SIMULATIONIO_DIR = {VIEW_DIR}
SSHT_DIR = {VIEW_DIR}
YAML_CPP_DIR = {VIEW_DIR}
ZLIB_DIR = {VIEW_DIR}
EOF
cp template.cfg local-gpu.cfg
export GCC_DIR=$(spack find --path gcc|tail -1|awk '{print $2}')
if [ "$GCC_DIR" = "No" ]
then
    export GCC_DIR=$(dirname $(dirname $(which gcc)))
fi
export NSIMD_DIR=$(spack find --path nsimd|tail -1|awk '{print $2}')
export NSIMD_ARCH=$(ls $NSIMD_DIR/lib/libnsimd_*.so | perl -p -e 's/.*libnsimd_//'|perl -p -e 's/\.so//')
export VIEW_DIR="$PWD/carpetx"
export AMREX_DIR=$(spack find --path amrex+cuda|tail -1|awk '{print $2}')
export CUDA_DIR=/usr/local/cuda
perl -p -i -e "s'{NSIMD_ARCH}'$NSIMD_ARCH'g" local-gpu.cfg
perl -p -i -e "s'{GCC_DIR}'$GCC_DIR'g" local-gpu.cfg
perl -p -i -e "s'{VIEW_DIR}'$VIEW_DIR'g" local-gpu.cfg
perl -p -i -e "s'{AMREX_DIR}'$AMREX_DIR'g" local-gpu.cfg
perl -p -i -e "s'{CUDA_DIR}'$CUDA_DIR'g" local-gpu.cfg

spack find amrex~cuda
if [ $? != 0 ]
then
  spack install --reuse amrex ~cuda ~hdf5 +openmp +particles +shared
fi
echo Create local-cpu.cfg
cat > template2.cfg << EOF
# Option list for the Einstein Toolkit

# The "weird" options here should probably be made the default in the
# ET instead of being set here.

# Whenever this version string changes, the application is configured
# and rebuilt from scratch
VERSION = db-gpu-2021-11-17

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
AMREX_DIR = {AMREX_DIR}
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
#PETSC_DIR = {VIEW_DIR}
#PETSC_ARCH_LIBS = m
PTHREADS_DIR = NO_BUILD
#REPRIMAND_DIR = {VIEW_DIR}
#REPRIMAND_LIBS = RePrimAnd
RNPLETAL_DIR = {VIEW_DIR}
SILO_DIR = {VIEW_DIR}
SIMULATIONIO_DIR = {VIEW_DIR}
SSHT_DIR = {VIEW_DIR}
YAML_CPP_DIR = {VIEW_DIR}
ZLIB_DIR = {VIEW_DIR}
EOF
cp template2.cfg local-cpu.cfg
export AMREX_DIR=$(spack find --path amrex~cuda|tail -1|awk '{print $2}')
perl -p -i -e "s'{NSIMD_ARCH}'$NSIMD_ARCH'g" local-cpu.cfg
perl -p -i -e "s'{GCC_DIR}'$GCC_DIR'g" local-cpu.cfg
perl -p -i -e "s'{VIEW_DIR}'$VIEW_DIR'g" local-cpu.cfg
perl -p -i -e "s'{AMREX_DIR}'$AMREX_DIR'g" local-cpu.cfg
spack gc -y
