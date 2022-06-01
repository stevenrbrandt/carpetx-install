export USER=jovyan
curl -kLO https://raw.githubusercontent.com/gridaphobe/CRL/master/GetComponents
chmod a+x GetComponents
./GetComponents --parallel https://bitbucket.org/eschnett/cactusamrex/raw/master/azure-pipelines/carpetx.th
cd /home/jovyan/Cactus
./simfactory/bin/sim setup-silent
perl -p -i -e 's{ET_2020_05}{ET_2020_11}' /home/jovyan/carpetx.th
perl -p -i -e 's{CarpetX/AHFinder}{#$&}' /home/jovyan/carpetx.th
perl -p -i -e 's{CarpetX/WaveToyGPU}{#$&}' /home/jovyan/carpetx.th 
perl -p -i -e 's{CactusUtils/Formaline}{#$&}' /home/jovyan/carpetx.th
bash /usr/local/bin/build-gpu.sh
cd ..
zip -qr Cactus.zip Cactus
