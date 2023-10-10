export VIEW=gpu
export VIEW_DIR="$SPACK_ROOT/var/spack/environments/$VIEW/.spack-env/view"
export NSIMD_ARCH=$(ls $VIEW_DIR/lib/libnsimd_*.so | perl -p -e 's/.*libnsimd_//'|perl -p -e 's/\.so//')
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
VERSION = db-gpu-$(date +%Y-%M-%d)

CPP = ${GCC_DIR}/bin/cpp
FPP = ${GCC_DIR}/bin/cpp
CC = ${GCC_DIR}/bin/gcc
CXX = ${GCC_DIR}/bin/g++
CUCC = ${CUDA_DIR}/bin/nvcc --compiler-bindir ${GCC_DIR}/bin/g++
FC = ${GCC_DIR}/bin/gfortran
F90 = ${GCC_DIR}/bin/gfortran
LD = ${CUDA_DIR}/bin/nvcc --compiler-bindir ${GCC_DIR}/bin/g++ -forward-unknown-to-host-compiler -lnvToolsExt

AMREX_ENABLE_CUDA=yes

# - We use "--relocatable-device-code=true" to allow building with
#   debug versions of AMReX
#   <https://github.com/AMReX-Codes/amrex/issues/1829>
# - We use "--objdir-as-tempdir" to prevent errors such as
#   Call parameter type does not match function signature!
#     %tmp = load double, double* %x.addr, align 8, !dbg !1483
#     float  %1 = call i32 @__isnanf(double %tmp), !dbg !1483
CPPFLAGS = -DSIMD_CPU
CFLAGS = -pipe -g -march=native
CUCCFLAGS = -forward-unknown-to-host-compiler -std=c++17 --expt-relaxed-constexpr --extended-lambda -x cu
CXXFLAGS = -std=c++17
FPPFLAGS = -traditional
F90FLAGS = -pipe -g -march=native -fcray-pointer -ffixed-line-length-none
LDFLAGS = -Wl,-rpath,${VIEW_DIR}/targets/x86_64-linux/lib -Wl,-rpath,/usr/local/lib -Wl,-rpath,/usr/local/nvidia/lib64
LIBS = gfortran

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

# /usr does not support these
DISABLE_INT16 = yes
DISABLE_REAL16 = yes

VECTORISE = no

ADIOS2_DIR = ${VIEW_DIR}
ADIOS2_LIBS = adios2_fortran_mpi adios2_cxx11_mpi adios2_core_mpi adios2_fortran adios2_cxx11 adios2_c adios2_core
AMREX_DIR = ${VIEW_DIR}
ASDF_CXX_DIR = ${VIEW_DIR}
BOOST_DIR = ${VIEW_DIR}
FFTW3_DIR = ${VIEW_DIR}
GSL_DIR = ${VIEW_DIR}
PAPI_DIR = ${VIEW_DIR}
HDF5_DIR = ${VIEW_DIR}
HDF5_ENABLE_CXX = yes
HDF5_ENABLE_FORTRAN = yes
HDF5_INC_DIRS = ${VIEW_DIR}/include
HDF5_LIB_DIRS = ${VIEW_DIR}/lib
HDF5_LIBS = hdf5_hl_cpp hdf5_cpp hdf5_hl_f90cstub hdf5_f90cstub hdf5_hl_fortran hdf5_fortran hdf5_hl hdf5
HDF5_ENABLE_CXX = yes
HPX_DIR = ${VIEW_DIR}
BLAS_DIR = ${VIEW_DIR}
LAPACK_DIR = ${VIEW_DIR}
LAPACK_LIB_DIRS = ${VIEW_DIR}/lib
LAPACK_LIBS = lapack
HWLOC_DIR = ${VIEW_DIR}
JEMALLOC_DIR = ${VIEW_DIR}
LORENE_DIR = ${VIEW_DIR}
MPI_DIR = ${VIEW_DIR}
MPI_INC_DIRS = ${VIEW_DIR}/include
MPI_LIB_DIRS = ${VIEW_DIR}/lib
MPI_LIBS = mpi
NSIMD_DIR = ${VIEW_DIR}
NSIMD_INC_DIRS = ${VIEW_DIR}/include
NSIMD_LIB_DIRS = ${VIEW_DIR}/lib
NSIMD_ARCH = ${NSIMD_ARCH}
NSIMD_SIMD = ${NSIMD_ARCH}
OPENBLAS_DIR = ${VIEW_DIR}
OPENPMD_API_DIR = ${VIEW_DIR}
OPENPMD_DIR = ${VIEW_DIR}
OPENSSL_DIR = ${VIEW_DIR}
#PETSC_DIR = ${VIEW_DIR}
#PETSC_ARCH_LIBS = m
PTHREADS_DIR = NO_BUILD
#REPRIMAND_DIR = ${VIEW_DIR}
#REPRIMAND_LIBS = RePrimAnd
RNPLETAL_DIR = ${VIEW_DIR}
SILO_DIR = ${VIEW_DIR}
SSHT_DIR = ${VIEW_DIR}
YAML_CPP_DIR = ${VIEW_DIR}
ZLIB_DIR = ${VIEW_DIR}
EOF
mv template.cfg local-gpu.cfg
