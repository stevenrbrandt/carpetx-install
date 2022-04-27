FROM ubuntu
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install -y git python3 build-essential curl vim gfortran subversion
COPY spack-cfg2.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/spack-cfg2.sh
WORKDIR /usr/carpetx-spack
RUN chmod 755 /usr/carpetx-spack
RUN bash /usr/local/bin/spack-cfg2.sh
WORKDIR /usr/carpetx
RUN curl -kLO https://raw.githubusercontent.com/gridaphobe/CRL/master/GetComponents
RUN chmod a+x GetComponents
RUN mkdir -p /usr/home
RUN useradd -m jovyan -d /usr/home/jovyan
USER jovyan
WORKDIR /usr/home/jovyan
ENV USER jovyan
RUN /usr/carpetx/GetComponents --parallel https://bitbucket.org/eschnett/cactusamrex/raw/9114a0e471131edac70525ee12c6bb44e0dc3fe8/azure-pipelines/carpetx.th
WORKDIR /usr/home/jovyan/Cactus
RUN echo workshop > /usr/home/jovyan/.hostname
RUN ./simfactory/bin/sim setup-silent
RUN perl -p -i -e 's{ExternalLibraries/RePrimAnd}{#$&}' /usr/home/jovyan/carpetx.th
RUN perl -p -i -e 's{CarpetX/GRHydroToyGPU}{#$&}' /usr/home/jovyan/carpetx.th
RUN perl -p -i -e 's{CarpetX/AHFinder}{#$&}' /usr/home/jovyan/carpetx.th
COPY --chown=jovyan build.sh ./
RUN chmod 755 ./build.sh
RUN bash ./build.sh
# RUN ./simfactory/bin/sim build -j10 --optionlist /usr/carpetx-spack/local.cfg --thornlist /usr/home/jovyan/carpetx.th
