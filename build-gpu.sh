cd
./simfactory/bin/sim setup-silent
./simfactory/bin/sim build -j10 sim-gpu --optionlist /usr/carpetx-spack/local-gpu.cfg --thornlist /home/jovyan/carpetx.th |& tee make-gpu.out
