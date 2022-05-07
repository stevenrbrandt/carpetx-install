source /usr/carpetx-spack/env.sh
perl -p -i -e 's/locks: true/locks: false/' $SPACK_ROOT/etc/spack/defaults/config.yaml
cd /usr/local/openPMD-api
rm -fr build
for p in gcc mpich hdf5 adios2 cmake
do
echo "Loading package: $p"
spack load $p
done
mkdir -p build
cd build
cmake -DopenPMD_USE_MPI=ON -DopenPMD_USE_PYTHON=ON -DopenPMD_USE_ADIOS2=ON ..
make -j10 install
