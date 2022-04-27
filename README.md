# carpetx-install
This repo builds a docker image that contains
spack-cfg2.sh, a shell script that installs all the carpetx dependencies using spack. It sets SPACK_ROOT and SPACK_USER_CONFIG_PATH, putting all spack files under one directory. The script also creates local.cfg, a configuration for use by simfactory to build carpetx.
It also contains an installation of Cactus.
