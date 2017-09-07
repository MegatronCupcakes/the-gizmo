#!/bin/sh

# Log message markers
LOG="\n[gizmo setup]\n"
END_LOG="\n[gizmo setup]\n"

# grab user, group, and IP
USER=`id -u -n`
USERID=`id -u`
GROUP=`id -gn`
GROUPID=`getent group ${GROUP} | awk -F: '{printf "%d\n", $3}'`
IP_ADDRESS=`hostname -I | xargs`

# get user details
echo "one thing to note.... I'm making the assumption that your gizmo has a static IP address.  I'm hardcoding ${IP_ADDRESS} in the config...."
sleep 5
clear
echo "ok, let's get started.  First I need some details about your drivepool...."
sleep 3
clear
echo "what is the full path of your TV directory?"
read TV_DIR
clear
echo "what is the full path of your MOVIE directory?"
read MOVIES_DIR
clear
echo "what is the full path of your MUSIC directory?"
read MUSIC_DIR
clear
echo "what is the full path of your LazyLibrarian library?"
read LIBRARY_DIR
clear
echo "since I'm going to generate your autoProcessTV.cfg file for you I need some info about how you plan to secure your gizmo apps...."
sleep 5
clear
echo 'enter the username you would like to use for your gizmo apps:'
read GIZMO_NAME
clear
echo 'enter the password you would like to use for your gizmo apps:'
read GIZMO_PASSWORD
clear
echo 'enter the url for downloading Plex Media Server:'
read LATEST_PMS_RELEASE
clear

echo ${LOG} Some steps require sudo, so you will be prompted for your password at some point... ${END_LOG}
sleep 3
clear
echo ${LOG} Creating Gizmo directories... ${END_LOG}

GIZMOTIC_DIR=/home/${USER}/tools/gizmotic
mkdir -p ${GIZMOTIC_DIR}
DOCKER_COMPOSE_DIR=${GIZMOTIC_DIR}/docker-compose
mkdir -p ${DOCKER_COMPOSE_DIR}
DOWNLOAD_DIR=${GIZMOTIC_DIR}/downloads/complete
mkdir -p ${DOWNLOAD_DIR}
mkdir -p ${DOWNLOAD_DIR}/tv
mkdir -p ${DOWNLOAD_DIR}/movies
mkdir -p ${DOWNLOAD_DIR}/music
mkdir -p ${DOWNLOAD_DIR}/library

INCOMPLETE_DOWNLOAD_DIR=${GIZMOTIC_DIR}/downloads/incomplete
mkdir -p ${INCOMPLETE_DOWNLOAD_DIR}
SABNZBD_CONFIG_DIR=${GIZMOTIC_DIR}/config/sabnzbd
mkdir -p ${SABNZBD_CONFIG_DIR}
SICKBEARD_CONFIG_DIR=${GIZMOTIC_DIR}/config/sickbeard
mkdir -p ${SICKBEARD_CONFIG_DIR}
COUCHPOTATO_CONFIG_DIR=${GIZMOTIC_DIR}/config/couchpotato
mkdir -p ${COUCHPOTATO_CONFIG_DIR}
HEADPHONES_CONFIG_DIR=${GIZMOTIC_DIR}/config/headphones
mkdir -p ${HEADPHONES_CONFIG_DIR}
LAZYLIBRARIAN_CONFIG_DIR=${GIZMOTIC_DIR}/config/lazylibrarian
mkdir -p ${LAZYLIBRARIAN_CONFIG_DIR}
PLEX_PY_CONFIG_DIR=${GIZMOTIC_DIR}/config/plexpy
mkdir -p ${PLEX_PY_CONFIG_DIR}
SONARR_CONFIG_DIR=${GIZMOTIC_DIR}/config/sonarr
mkdir -p ${SONARR_CONFIG_DIR}

sleep 3
clear
# grab dependencies
echo ${LOG} Installing supporting packages ${END_LOG}
sudo apt-get update
sudo apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual apt-transport-https ca-certificates curl software-properties-common wget

sleep 3
clear

# Create a temporary directory
TEMPDIR=`mktemp -d`
CURRENT_DIR=`pwd`
echo ${LOG} Using temp dir: ${TEMPDIR} ${END_LOG}
cd ${TEMPDIR}

sleep 3
clear

echo ${LOG} Downloading Plex ${END_LOG}
wget ${LATEST_PMS_RELEASE}

sleep 3
clear

echo ${LOG} Installing Plex ${END_LOG}
sudo dpkg -i *.deb

sleep 3
clear

# install Docker
echo ${LOG} Configuring Docker repository ${END_LOG}
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update

sleep 3
clear

echo ${LOG} Installing Docker ${END_LOG}
sudo apt-get install -y docker-ce

sleep 3
clear

echo ${LOG} "Adding user to the docker group; this may require your password" ${END_LOG} ${END_LOG}
sudo usermod -aG docker ${USER}
sudo systemctl enable docker

sleep 3
clear

echo ${LOG} "Making sure Docker is running...." ${END_LOG}
sudo service docker start

sleep 3
clear

echo ${LOG} Installing Docker-Compose ${END_LOG}
wget https://github.com/docker/compose/releases/download/1.16.1/docker-compose-Linux-x86_64
sudo mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sleep 3
clear

echo ${LOG} 'Writing autoProcessTV.cfg based on user-provided access information' ${END_LOG}
cat >${TEMPDIR}/autoProcessTV.cfg <<EOM
# Sick Beard autoProcessTV configuration file
# Used in combination with scripts like sabToSickBeard that call autoProcessTV
#
# Rename (or copy) autoProcessTV.cfg.sample to autoProcessTV.cfg
# Change the host, port, username, and password values
# to the appropriate settings for your Sick Beard server.
#
# Example:  Sick Beard can be accessed on http://localhost:8081
#           without username/password
#
# host=localhost    # Sick Beard host (localhost or IP address)
# port=8081         # Sick Beard port
# username=         # Credentials for logging into Sick Beard
# password=         # Credentials for logging into Sick Beard (no special characters)
# web_root=         # Sick Beard web_root
# ssl=0             # http (ssl=0) (for https use ssl=1)

[SickBeard]
host=localhost
port=8081
username=${GIZMO_NAME}
password=${GIZMO_PASSWORD}
web_root=/
ssl=0
EOM

cat >${DOCKER_COMPOSE_DIR}/docker-compose.yml <<EOM
version: '2'
services:
  sickbeard:
    image: linuxserver/sickbeard
    container_name: sickbeard
    environment:
      - PGID=${GROUPID}
      - PUID=${USERID}
      - TZ=America/Louisville
    volumes:
      - ${SICKBEARD_CONFIG_DIR}:/config
      - autoProcessTV:/app/sickbeard/autoProcessTV
      - ${DOWNLOAD_DIR}/tv:/downloads
      - ${TV_DIR}:/tv
    ports:
      - 8081:8081
    networks:
      - gizmo
    restart: always
    extra_hosts:
      - "thegizmo:${IP_ADDRESS}"
  sabnzbd:
    image: linuxserver/sabnzbd
    container_name: sabnzbd
    environment:
      - PGID=${GROUPID}
      - PUID=${USERID}
      - TZ=America/Louisville
    volumes:
      - ${SABNZBD_CONFIG_DIR}:/config
      - ${DOWNLOAD_DIR}:/downloads
      - ${INCOMPLETE_DOWNLOAD_DIR}:/incomplete-downloads
      - autoProcessTV:/autoProcessTV
    ports:
      - 8080:8080
      - 9090:9090
    networks:
      - gizmo
    restart: always
    extra_hosts:
      - "thegizmo:${IP_ADDRESS}"
  couchpotato:
    image: linuxserver/couchpotato
    container_name: couchpotato
    environment:
      - PGID=${GROUPID}
      - PUID=${USERID}
      - TZ=America/Louisville
    ports:
      - 5050:5050
    volumes:
      - ${COUCHPOTATO_CONFIG_DIR}:/config
      - ${DOWNLOAD_DIR}/movies:/downloads
      - ${MOVIES_DIR}:/movies
    networks:
      - gizmo
    restart: always
    extra_hosts:
      - "thegizmo:${IP_ADDRESS}"
  headphones:
    image: linuxserver/headphones
    container_name: headphones
    environment:
      - PGID=${GROUPID}
      - PUID=${USERID}
      - TZ=America/Louisville
    ports:
      - 8181:8181
    volumes:
      - ${HEADPHONES_CONFIG_DIR}:/config
      - ${DOWNLOAD_DIR}/music:/downloads
      - ${MUSIC_DIR}:/music
    networks:
      - gizmo
    restart: always
    extra_hosts:
      - "thegizmo:${IP_ADDRESS}"
  lazylibrarian:
    image: linuxserver/lazylibrarian
    container_name: lazylibrarian
    environment:
      - PGID=${GROUPID}
      - PUID=${USERID}
      - TZ=America/Louisville
    ports:
      - 5299:5299
    volumes:
      - ${LAZYLIBRARIAN_CONFIG_DIR}:/config
      - ${DOWNLOAD_DIR}/library:/downloads
      - ${LIBRARY_DIR}:/books
    networks:
      - gizmo
    restart: always
    extra_hosts:
      - "thegizmo:${IP_ADDRESS}"
  plexpy:
    image: linuxserver/plexpy
    container_name: plexpy
    environment:
      - PGID=${GROUPID}
      - PUID=${USERID}
      - TZ=America/Louisville
    ports:
      - 8182:8181
    volumes:
      - ${PLEX_PY_CONFIG_DIR}:/config
      - /var/lib/plexmediaserver/Library/Application\ Support/Plex\ Media\ Server/Logs:/logs
    networks:
      - gizmo
    restart: always
    extra_hosts:
      - "thegizmo:${IP_ADDRESS}"
  sonarr:
    image: linuxserver/sonarr
    container_name: sonarr
    environment:
      - PGID=${GROUPID}
      - PUID=${USERID}
      - TZ=America/Louisville
    ports:
      - 8989:8989
    volumes:
      - ${DOWNLOAD_DIR}/tv:/downloads
      - ${TV_DIR}:/tv
      - /etc/localtime:/etc/localtime:ro
      - ${SONARR_CONFIG_DIR}:/config
    networks:
      - gizmo
    restart: always
    extra_hosts:
      - "thegizmo:${IP_ADDRESS}"
volumes:
  autoProcessTV:
networks:
  gizmo:
EOM

sleep 3
clear

cd ${DOCKER_COMPOSE_DIR}
echo ${LOG} 'Creating Docker Volume for shared TV Processing configuration' ${END_LOG}
sg docker -c 'docker volume create autoProcessTV'

sleep 3
clear

echo ${LOG} Launching Gizmo apps via Docker-Compose ${END_LOG}
sg docker -c 'docker-compose up -d'

sleep 3
clear

echo ${LOG} "Copying shared configuration to Docker Volume" ${END_LOG}
cd ${TEMPDIR}
sg docker -c 'docker cp ./autoProcessTV.cfg sickbeard:/app/sickbeard/autoProcessTV/autoProcessTV.cfg'

sleep 3
clear

echo ${LOG} "Restarting SABNZBD and Sickbeard" ${END_LOG}
sg docker -c 'docker restart sabnzbd'
sg docker -c 'docker restart sickbeard'

sleep 3
clear

cd ${CURRENT_DIR}
echo ${LOG} Cleaning up ${END_LOG}
rm -dr ${TEMPDIR}
sudo apt-get autoremove -y

sleep 3
clear

echo ${LOG}
echo "\nDone!\n"
echo "SABNZBD is running on port 8081"
echo "SickBeard is running on port 8080"
echo "Couchpotato is running on port 5050"
echo "Headphones is running on port 8181"
echo "LazyLibrarian is running on port 5299"
echo "PlexPy is running on port 8182"
echo "Sonarr is running on port 8989"
echo "\nDocker networking is a little strange.... I create a special host entry pointed to your machine's IP address to get around this"
echo "When configuring the apps to talk to each other (like when configuring the SABnzbd URL in SickBeard) use the hostname \"thegizmo\" e.g. http://thegizmo:8081/"
echo "\nWhen you access the gizmo for normal usage, you can do it like you always do... by IP (${IP_ADDRESS}) or by hostname or by any domain name you might have configured for it."
echo "\nAlso note that directory structure within each Dockerized app differs from your machine. Your gizmo directories are mapped to special directories within each Docker container."
echo "You can see all these mappings in the docker-compose.yml file I generated during setup (${DOCKER_COMPOSE_DIR}/docker-compose.yml)"
echo "\nEnjoy!"
echo ${END_LOG}
