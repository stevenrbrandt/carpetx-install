U=$1
if [ "$U" != "jovyan" ]
then
  rm -f /home/jovyan/Cactus
  ln -s /nfs/home/$U/Cactus /home/jovyan/Cactus
fi
