docker-compose -f docker-compose2.yml build --no-cache
docker-compose -f docker-compose2.yml down
docker-compose -f docker-compose2.yml up -d
sleep 5
docker cp etworkshop2:/home/jovyan/Cactus.zip .
docker cp etworkshop2:/home/jovyan/carpetx.th .
scp Cactus.zip carpetx.th hub:./
