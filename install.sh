#!/bin/sh
#################################################################
# INSTALACION DE HOME-ASSISTANT EN DOCKER EN UBUNTU 18.04.3 LTS #
#################################################################

#################################################################
# Cambio de uso horario a Madrid
timedatectl set-timezone Europe/Madrid

#################################################################
# Permisos sobre USB
sudo usermod -a -G dialout domotica

#################################################################
# Creacion de directorios

mkdir /homeassistant
chmod 777 /homeassistant

mkdir /mqtt
chmod 777 /mqtt

mkdir /z2m
chmod 777 /z2m

mkdir /dockermon
chmod 777 /dockermon

mkdir /unifi
mkdir /unifi/unifi
mkdir /unifi/var
chmod -R 777 /unifi

#################################################################
# Instalacion de Dependencias

apt update -y && apt upgrade -y && apt autoremove -y && apt install cifs-utils samba bash jq curl avahi-daemon dbus apparmor-utils network-manager socat gnupg-agent apt-transport-https ca-certificates software-properties-common bluetooth -y

#################################################################
# Instalacion de DOCKER

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update -y && apt upgrade -y && apt autoremove -y && apt install docker-ce docker-ce-cli containerd.io -y
apt update -y && apt upgrade -y && apt autoremove -y

##################################################################
# Instalacion del Contenedor Portainer

docker volume create portainer_data
docker run -d \
--name=portainer \
--net=host \
--restart always \
-v /var/run/docker.sock:/var/run/docker.sock \
-v portainer_data:/data \
portainer/portainer

#################################################################
# Instalacion del Contenedor de Home-Assistant

docker create \
--name home-assistant \
--net=host \
--privileged -it \
-v /homeassistant:/config \
-e TZ=Europe/Madrid \
-v /dev/bus/usb:/dev/bus/usb \
-v /var/run/dbus:/var/run/dbus \
homeassistant/home-assistant

#################################################################
# Instalacion del Contenedor de Z2M

docker create \
--name z2m \
--net=host \
--privileged -it \
--device=/dev/ttyACM0 \
-v /z2m:/app/data \
-e TZ=Europe/Madrid \
koenkk/zigbee2mqtt:latest

#################################################################
# Instalacion del Contenedor de Z2M-DEV

docker create \
--name z2m-dev \
--net=host \
--privileged -it \
--device=/dev/ttyACM0 \
-v /z2m:/app/data \
-e TZ=Europe/Madrid \
koenkk/zigbee2mqtt:latest-dev

#################################################################
# Instalacion del Zigbee2mqtt Assistant

docker create \
--name z2m-assistant \
--net=host \
--privileged -it \
-e TZ=Europe/Madrid \
-e Z2MA_SETTINGS__MQTTSERVER=127.0.0.1 \
carldebilly/zigbee2mqttassistant

#################################################################
# Instalacion del Contenedor de MQTT

docker create \
--name mqtt \
--net=host \
-v /mqtt/config/mosquitto.conf:/mosquitto/config/mosquitto.conf \
-v /mqtt/data:/mosquitto/data \
-v /mqtt/log:/mosquitto/log \
-v /mqtt/config:/mosquitto/config \
eclipse-mosquitto

#################################################################
# Instalacion del Contenedor de Dockermon

docker run -d \
--name dockermon \
--net=host \
--restart always \
--privileged -it \
-v /dockermon:/config \
-v /var/run/docker.sock:/var/run/docker.sock \
philhawthorne/ha-dockermon:latest

#################################################################
# Instalacion del Contenedor de Ouroboros
#-e NOTIFIERS=tgram://GRUPONUMEROLARGUISMO/CLIENTE \

docker create \
--name ouroboros \
--net=host \
--privileged -it \
-e TZ=Europe/Madrid \
-v /var/run/docker.sock:/var/run/docker.sock \
pyouroboros/ouroboros:latest

#################################################################
# Instalacion del Controlador Unifi

docker create \
--name unifi \
--net=host \
--restart always \
--privileged -it \
-v /unifi/unifi:/unifi \
-v /unifi/var/:/var/run/unifi \
-e TZ=Europe/Madrid \
jacobalberty/unifi:stable

#################################################################
# Instalacion y configuracion de SAMBA

tee -a /etc/samba/smb.conf << EOF
[HomeAssistant]
  comment=Configuracion HA
  path=/homeassistant
  valid users = root
  force user = root
  force group = root
  browseable = yes
  writeable = yes
  admin users = root
  public = yes
  create mask = 0777
  directory mask = 0777

[z2m]
  comment=Zigbee2Mqtt
  path=/z2m
  valid users = root
  force user = root
  force group = root
  browseable = yes
  writeable = yes
  admin users = root
  public = yes
  create mask = 0777
  directory mask = 0777

[mqtt]
  comment=MQTT
  path=/mqtt
  valid users = root
  force user = root
  force group = root
  browseable = yes
  writeable = yes
  admin users = root
  public = yes
  create mask = 0777
  directory mask = 0777
EOF

# Se añade sudo
sudo smbpasswd -a root
sudo /usr/sbin/service smbd restart
