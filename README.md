# carpetx-install
To build this image, do the following:

```
# This builds an image similar to
# one of Dustin's. I copied and
# edited from him.
cd single-user
docker-compose build

# This is the main container.
cd ..
docker-compose build

# To make the zip ball
# and push it to the server
bash ./zipball.sh 
```
