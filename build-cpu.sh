cd ~/Cactus
if [ ! -e ~/carpetx.th ]
then
  cp /home/jovyan/carpetx.th ~/
fi
sudo /usr/local/bin/link.sh $USER
./simfactory/bin/sim setup-silent
./simfactory/bin/sim build -j10 sim-cpu --optionlist /usr/carpetx-spack/local-cpu.cfg --thornlist ~/carpetx.th |& tee make-cpu.out
