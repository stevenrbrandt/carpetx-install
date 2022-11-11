#FROM nvidia/cuda:11.5.2-devel-ubuntu20.04
FROM ubuntu:20.04
#FROM stevenrbrandt/perimeter

ENV DEBIAN_FRONTEND noninteractive
RUN apt update -y && \
    apt-get install -y git curl vim gfortran subversion make cmake xz-utils file emacs \
    python3-dev zip python3-sympy python3-numpy python3-matplotlib ffmpeg gdb g++ gfortran && \
    rm -rf /var/lib/apt/lists/*


#RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10
#RUN update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-10 10

WORKDIR /usr/local
RUN git clone https://github.com/openPMD/openPMD-api.git
WORKDIR /usr/local/openPMD-api

COPY spack-cfg2.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/spack-cfg2.sh
WORKDIR /usr/carpetx-spack
RUN chmod 755 /usr/carpetx-spack

# Install all carpetx dependencies and create local.cfg
RUN bash /usr/local/bin/spack-cfg2.sh

# WORKDIR /usr/carpetx

# # Download carpetx
# RUN useradd -m jovyan -s /bin/bash

# # Finish installing openpmd
# COPY build-openpmd-api.sh /usr/local/bin/
# RUN bash /usr/local/bin/build-openpmd-api.sh

# COPY build-gpu.sh /usr/local/bin/
# COPY build-cpu.sh /usr/local/bin/
# RUN chmod 755 /usr/local/bin/build*.sh
# RUN mkdir -p /usr/local/data
# RUN echo ALL ALL=NOPASSWD: /usr/local/bin/link.sh >> /etc/sudoers
# COPY link.sh /usr/local/bin/
# RUN chmod +x /usr/local/bin/link.sh

# # Special location for openpmd
# RUN perl -p -i -e 's{^OPENPMD_DIR =.*}{OPENPMD_DIR = /usr/local}' /usr/carpetx-spack/*.cfg
# RUN perl -p -i -e 's{^OPENPMD_API_DIR =.*}{OPENPMD_API_DIR = /usr/local}' /usr/carpetx-spack/*.cfg
# #RUN perl -p -i -e 's{/usr/carpetx-spack/carpetx/bin/nvcc}{/usr/local/cuda/bin/nvcc}g' /usr/carpetx-spack/*.cfg

# #USER jovyan
# #WORKDIR /home/jovyan

# ## ENV USER jovyan

# #RUN echo hub > /home/jovyan/.hostname

# #RUN export USER=jovyan && curl -kLO https://raw.githubusercontent.com/gridaphobe/CRL/master/GetComponents && \
# #    chmod a+x GetComponents && \
# #    ./GetComponents --parallel https://bitbucket.org/eschnett/cactusamrex/raw/59638ede6b0a513c078169cb58420d057b25cbd9/azure-pipelines/carpetx.th && cd /home/jovyan/Cactus && \
# #  ./simfactory/bin/sim setup-silent && \
# #  perl -p -i -e 's{ET_2020_05}{ET_2020_11}' /home/jovyan/carpetx.th && \
# #  perl -p -i -e 's{CarpetX/AHFinder}{#$&}' /home/jovyan/carpetx.th && \
# #  perl -p -i -e 's{CarpetX/WaveToyGPU}{#$&}' /home/jovyan/carpetx.th && \
# #  perl -p -i -e 's{CactusUtils/Formaline}{#$&}' /home/jovyan/carpetx.th && \
# #  bash /usr/local/bin/build-gpu.sh && cd .. && zip -qr Cactus.zip Cactus && rm -fr Cactus

# #WORKDIR /home/jovyan
# #USER root
# #RUN ln -s /home/jovyan/Cactus.zip /usr/local/data/Cactus.zip
# RUN pip install --no-cache scrolldown celluloid
# ENV PYTHONPATH /usr/local/lib/python3.8/dist-packages:/usr/local/lib/python3.8/site-packages
# ENV LD_LIBRARY_PATH /usr/local/lib:/usr/local/nvidia/lib64
# COPY notebooks/*.ipynb /etc/skel/
# COPY setup-user.sh /usr/local/bin/
# COPY bash_profile /etc/skel/.bash_profile
# RUN chmod +x /usr/local/bin/setup-user.sh
# COPY singleuser/start-notebook.sh /usr/local/bin/
RUN apt update -y && \
    apt install -yq --no-install-recommends locales locales-all && \
    rm -rf /var/lib/apt/lists/*
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
ENV CCTK_HOSTNAME etworkshop
