#FROM nvidia/cuda:11.5.2-devel-ubuntu20.04
#FROM nvidia/cuda:11.0.3-base-ubuntu20.04
FROM ubuntu:20.04
#FROM stevenrbrandt/perimeter

ENV DEBIAN_FRONTEND noninteractive
RUN apt update -y && \
    apt-get install -y git curl vim gfortran-10 subversion make cmake xz-utils file \
    emacs locales locales-all nvidia-driver-535 \
    python3-pip python3-dev zip python3-sympy python3-numpy python3-matplotlib ffmpeg gdb g++-10 cvs && \
    rm -rf /var/lib/apt/lists/*
# nvidia-cuda-devel

#RUN pip3 install nvidia-nsys

RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10
RUN update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-10 10

ENV PATH /usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

## Install all carpetx dependencies and create local.cfg
#RUN bash /usr/local/bin/spack-cfg2.sh

## WORKDIR /usr/carpetx

ENV BASE /usr/cactus

RUN useradd -m jovyan -s /bin/bash -d $BASE

COPY spack-setup.sh /usr/local/bin
RUN chmod +x /usr/local/bin/spack-setup.sh
USER jovyan
RUN spack-setup.sh

ENV SPACK_SKIP_MODULES 1
ENV SPACK_ROOT $BASE/spack-root
ENV SPACK_PYTHON /usr/bin/python3

RUN ${SPACK_ROOT}/bin/spack external find --not-buildable perl diffutils findutils fortran tar xz pkgconf zlib python cuda 

# Create the GPU spack environment
ENV SPACK_ENV_NAME=gpu
RUN ${SPACK_ROOT}/bin/spack env create $SPACK_ENV_NAME

ENV SPACK_ENV $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME
ENV ACLOCAL_PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/share/aclocal
ENV CMAKE_PREFIX_PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view
ENV PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/bin:$SPACK_ROOT/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
ENV PKG_CONFIG_PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/share/pkgconfig:$SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/lib64/pkgconfig:$SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/lib/pkgconfig

ENV AMREX_VER 23.09 +shared +particles build_type=RelWithDebInfo +openmp

RUN spack config add concretizer:reuse:true
RUN spack config add concretizer:unify:when_possible

RUN spack add netlib-lapack silo mpich openssl fftw papi hwloc adios2 boost googletest gperftools nsimd openblas ssht yaml-cpp openpmd-api lorene cuda amrex@${AMREX_VER} +cuda
RUN spack develop -p $BASE/amrex+cuda amrex @${AMREX_VER} +cuda

RUN spack concretize -f
RUN spack install --fail-fast --keep-stage

RUN mkdir -p $BASE/bin/
COPY --chown=jovyan mk-cfg-gpu.sh $BASE/bin/mk-cfg-gpu.sh
RUN chmod 755 $BASE/bin/mk-cfg-gpu.sh
WORKDIR $BASE
RUN $BASE/bin/mk-cfg-gpu.sh

# Create the CPU spack environment
ENV SPACK_ENV_NAME=cpu
RUN ${SPACK_ROOT}/bin/spack env create $SPACK_ENV_NAME

ENV SPACK_ENV $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME
ENV ACLOCAL_PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/share/aclocal
ENV CMAKE_PREFIX_PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view
ENV PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/bin:$SPACK_ROOT/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
ENV PKG_CONFIG_PATH $SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/share/pkgconfig:$SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/lib64/pkgconfig:$SPACK_ROOT/var/spack/environments/$SPACK_ENV_NAME/.spack-env/view/lib/pkgconfig

RUN spack config add concretizer:reuse:true
RUN spack config add concretizer:unify:when_possible

RUN spack add netlib-lapack silo mpich openssl fftw papi hwloc adios2 boost googletest gperftools nsimd openblas ssht yaml-cpp openpmd-api lorene amrex@${AMREX_VER} ~cuda
RUN spack develop -p $BASE/amrex~cuda amrex @${AMREX_VER} ~cuda

RUN spack concretize -f
RUN spack install --fail-fast --keep-stage

COPY --chown=jovyan mk-cfg-cpu.sh $BASE/bin/mk-cfg-cpu.sh
RUN chmod 755 $BASE/bin/mk-cfg-cpu.sh
RUN $BASE/bin/mk-cfg-cpu.sh

## # Finish installing openpmd
## COPY build-openpmd-api.sh /usr/local/bin/
## RUN bash /usr/local/bin/build-openpmd-api.sh

#COPY build-gpu.sh /usr/local/bin/
#COPY build-cpu.sh /usr/local/bin/
#RUN chmod 755 /usr/local/bin/build*.sh
#RUN mkdir -p /usr/local/data
#RUN echo ALL ALL=NOPASSWD: /usr/local/bin/link.sh >> /etc/sudoers
#COPY link.sh /usr/local/bin/
#RUN chmod +x /usr/local/bin/link.sh

## # Special location for openpmd
## RUN perl -p -i -e 's{^OPENPMD_DIR =.*}{OPENPMD_DIR = /usr/local}' /usr/carpetx-spack/*.cfg
## RUN perl -p -i -e 's{^OPENPMD_API_DIR =.*}{OPENPMD_API_DIR = /usr/local}' /usr/carpetx-spack/*.cfg
## #RUN perl -p -i -e 's{/usr/carpetx-spack/carpetx/bin/nvcc}{/usr/local/cuda/bin/nvcc}g' /usr/carpetx-spack/*.cfg

#USER jovyan
#WORKDIR /home/jovyan

#ENV USER jovyan

##RUN echo hub > /home/jovyan/.hostname

##RUN export USER=jovyan && curl -kLO https://raw.githubusercontent.com/gridaphobe/CRL/master/GetComponents && \
## #    chmod a+x GetComponents && \
## #    ./GetComponents --parallel https://bitbucket.org/eschnett/cactusamrex/raw/59638ede6b0a513c078169cb58420d057b25cbd9/azure-pipelines/carpetx.th && cd /home/jovyan/Cactus && \
## #  ./simfactory/bin/sim setup-silent && \
## #  perl -p -i -e 's{ET_2020_05}{ET_2020_11}' /home/jovyan/carpetx.th && \
## #  perl -p -i -e 's{CarpetX/AHFinder}{#$&}' /home/jovyan/carpetx.th && \
## #  perl -p -i -e 's{CarpetX/WaveToyGPU}{#$&}' /home/jovyan/carpetx.th && \
## #  perl -p -i -e 's{CactusUtils/Formaline}{#$&}' /home/jovyan/carpetx.th && \
## #  bash /usr/local/bin/build-gpu.sh && cd .. && zip -qr Cactus.zip Cactus && rm -fr Cactus

## #WORKDIR /home/jovyan
## #USER root
## #RUN ln -s /home/jovyan/Cactus.zip /usr/local/data/Cactus.zip
## RUN pip install --no-cache scrolldown celluloid
## ENV PYTHONPATH /usr/local/lib/python3.8/dist-packages:/usr/local/lib/python3.8/site-packages
## ENV LD_LIBRARY_PATH /usr/local/lib:/usr/local/nvidia/lib64
## COPY notebooks/*.ipynb /etc/skel/
## COPY setup-user.sh /usr/local/bin/
## COPY bash_profile /etc/skel/.bash_profile
## RUN chmod +x /usr/local/bin/setup-user.sh
## COPY singleuser/start-notebook.sh /usr/local/bin/
##RUN apt update -y && \
##    apt install -yq --no-install-recommends locales locales-all && \
##    rm -rf /var/lib/apt/lists/*
#USER root
#RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
#USER jovyan
#ENV CCTK_HOSTNAME etworkshop
