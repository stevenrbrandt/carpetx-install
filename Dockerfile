FROM ubuntu:20.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y git python3 build-essential curl vim gfortran subversion python3-dev

WORKDIR /usr/local
ARG GH_TOKEN
COPY install-gh.sh .
RUN bash ./install-gh.sh
RUN git clone https://github.com/openPMD/openPMD-api.git
WORKDIR /usr/local/openPMD-api
RUN gh pr checkout 1223

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
RUN mkdir -p /usr/home
RUN useradd -m jovyan -d /usr/home/jovyan

# Finish installing openpmd
COPY build-openpmd-api.sh /usr/local/bin/
RUN bash /usr/local/bin/build-openpmd-api.sh

USER jovyan
WORKDIR /usr/home/jovyan

ENV USER jovyan
RUN /usr/carpetx/GetComponents --parallel https://bitbucket.org/eschnett/cactusamrex/raw/9114a0e471131edac70525ee12c6bb44e0dc3fe8/azure-pipelines/carpetx.th
WORKDIR /usr/home/jovyan/Cactus

# We don't want an ever-changing hostname to interfere
# with simfactory's build logic
RUN echo workshop > /usr/home/jovyan/.hostname

RUN ./simfactory/bin/sim setup-silent

# At present, building RePrimAnd is problematic. It doesn't work
# on GPUs anyway.
RUN perl -p -i -e 's{ExternalLibraries/RePrimAnd}{#$&}' /usr/home/jovyan/carpetx.th

# This thorn depends on RePrimAnd.
RUN perl -p -i -e 's{CarpetX/GRHydroToyGPU}{#$&}' /usr/home/jovyan/carpetx.th

# This thorn does not build on GPUs at the moment.
RUN perl -p -i -e 's{CarpetX/AHFinder}{#$&}' /usr/home/jovyan/carpetx.th

# Other stuff that's not needed
RUN perl -p -i -e 's{CactusUtils/Formaline}{#$&}' /usr/home/jovyan/carpetx.th
RUN perl -p -i -e 's{ExternalLibraries/PETSc}{#$&}' /usr/home/jovyan/carpetx.th

COPY --chown=jovyan build-gpu.sh ./
COPY --chown=jovyan build-cpu.sh ./
RUN chmod 755 ./build*.sh

RUN bash ./build-gpu.sh
