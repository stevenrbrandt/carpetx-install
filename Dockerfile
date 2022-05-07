FROM nvidia/cuda:11.5.2-devel-ubuntu20.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt update -y
RUN apt-get install -y git curl vim gfortran subversion \
    python3-dev zip python3-sympy python3-numpy python3-matplotlib ffmpeg gdb g++-10 gfortran-10
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10
RUN update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-10 10

WORKDIR /usr/local
#ARG GH_TOKEN
#COPY install-gh.sh .
#RUN bash ./install-gh.sh
RUN git clone https://github.com/openPMD/openPMD-api.git
WORKDIR /usr/local/openPMD-api
#RUN gh pr checkout 1223

COPY spack-cfg2.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/spack-cfg2.sh
WORKDIR /usr/carpetx-spack
RUN chmod 755 /usr/carpetx-spack

# Install all carpetx dependencies and create local.cfg
RUN bash /usr/local/bin/spack-cfg2.sh

WORKDIR /usr/carpetx

# Download carpetx
RUN curl -kLO https://raw.githubusercontent.com/gridaphobe/CRL/master/GetComponents
RUN chmod a+x GetComponents
RUN useradd -m jovyan -s /bin/bash

# Finish installing openpmd
COPY build-openpmd-api.sh /usr/local/bin/
RUN bash /usr/local/bin/build-openpmd-api.sh

COPY build-gpu.sh /usr/local/bin/
COPY build-cpu.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/build*.sh
RUN mkdir -p /usr/local/data

# Special location for openpmd
RUN perl -p -i -e 's{^OPENPMD_DIR =.*}{OPENPMD_DIR = /usr/local}' /usr/carpetx-spack/*.cfg
RUN perl -p -i -e 's{^OPENPMD_API_DIR =.*}{OPENPMD_API_DIR = /usr/local}' /usr/carpetx-spack/*.cfg
RUN perl -p -i -e 's{/usr/carpetx-spack/carpetx/bin/nvcc}{/usr/local/cuda/bin/nvcc}g' /usr/carpetx-spack/*.cfg

USER jovyan
WORKDIR /home/jovyan

ENV USER jovyan
RUN /usr/carpetx/GetComponents --parallel https://bitbucket.org/eschnett/cactusamrex/raw/59638ede6b0a513c078169cb58420d057b25cbd9/azure-pipelines/carpetx.th
WORKDIR /home/jovyan/Cactus

# We don't want an ever-changing hostname to interfere
# with simfactory's build logic
RUN echo workshop > /home/jovyan/.hostname

RUN ./simfactory/bin/sim setup-silent

# Use a newer cactus
RUN perl -p -i -e 's{ET_2020_05}{ET_2020_11}' /home/jovyan/carpetx.th

# This thorn does not build on GPUs at the moment.
RUN perl -p -i -e 's{CarpetX/AHFinder}{#$&}' /home/jovyan/carpetx.th

# Other stuff that's not needed
RUN perl -p -i -e 's{CactusUtils/Formaline}{#$&}' /home/jovyan/carpetx.th

RUN bash /usr/local/bin/build-gpu.sh && cd .. && zip -qr Cactus.zip Cactus && rm -fr Cactus
WORKDIR /home/jovyan
USER root
RUN ln -s /home/jovyan/Cactus.zip /usr/local/data/Cactus.zip
