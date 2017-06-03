#!/usr/bin/env bash

# This mount holds configs related to the services
MOUNT_POINT=/home/matt/dockerfs
# This mount point holds media that is shown in plex
MEDIA_MOUNT_POINT=/mnt/castle
# Where download(ing) files from utorrent are stored
DOWNLOAD_MOUNT_POINT=/home/matt/dockerfs/downloads

UID=1000
GID=1000

# ---------- Handlers ----------
PROGNAME=$(basename $0)

error_exit ()
{
	echo "${PROGNAME}: ${1:-Unexpected Error}" 1>&2
	exit 1
}

d_delete ()
{
	docker rm $1 > /dev/null || error_exit "Failed to delete container $1. Delete this container manually with `docker rm -f $1`  Aborting."
}

d_running ()
{
	docker inspect --format '{{.State.Running}}' $1 > /dev/null || error_exit "Failed to check running status of container $1. Aborting."
}

d_exists () {
	docker ps -a | grep $1 > /dev/null
}

full_delete ()
{
	if d_exists $1;
	then
		echo "Existing $1 container found. Removing."
		if d_running $1;
		then
			echo "Existing $1 container running. Stopping."
			docker stop $1 > /dev/null ||  error_exit "Failed to stop container $1. Aborting."
            	fi

		d_delete $1
	fi
}

full_start ()
{
	echo "Starting $1 container."

	docker start $1 > /dev/null || error_exit "Failed to start container $1. Aborting."
	IP_ADDRESS=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1 || "UNKNOWN")

	echo "Container Started: $1 with IP: $IP_ADDRESS"
	echo "Conatiner Accessible @: $IP_ADDRESS:$S_PORT"
}

# Setup the Sonarr Container
# https://hub.docker.com/r/linuxserver/sonarr/
# Deprecated into the localtime mount below. -e TZ=<timezone> \
create_sonarr ()
{
	# SONARR Variables
	SONARR_NAME='mc-sonarr'
	S_PORT=8091

	echo "Preparing for creation of container $SONARR_NAME"
	full_delete $SONARR_NAME

	echo "Creating $SONARR_NAME container."
	docker create \
   	--name $SONARR_NAME \
    	-v /etc/localtime:/etc/localtime:ro \
    	-v $MOUNT_POINT/sonarr-config:/config \
    	-v $DOWNLOAD_MOUNT_POINT/completed:/downloads \
    	-v $MOUNT_POINT/tv:/tv \
    	-p $S_PORT:$S_PORT \
    	-e PUID=$UID -e PGID=$GID \
    	linuxserver/sonarr > /dev/null || "Error creating container: $?"

	sleep 3;
	full_start $SONARR_NAME
}

# Setup the Radarr Container
# https://hub.docker.com/r/linuxserver/radarr/
create_radarr ()
{
#docker create \
#    --name=radarr \
#    -v $MOUNT_POINT/radarr-config:/config \
#    -v $DOWNLOAD_MOUNT_POINT/completed:/downloads \
#    -v $MOUNT_POINT/movies:/movies \
#    -e PGID=$GID -e PUID=$UID  \
#    -e TZ=US/Central \
#    -p 8988:8988 \
#    linuxserver/radarr

}


# ---------- MAIN ----------
cat << "EOF"
               ,'``.._   ,'``.
              :,--._:)\,:,._,.:       All Glory to
              :`--,''   :`...';\      the HYPNO TOAD!
               `,'       `---'  `.
               /                 :
              /                   \
            ,'                     :\.___,-.
           `...,---'``````-..._    |:       \
             (                 )   ;:    )   \  _,-.
              `.              (   //          `'    \
               :               `.//  )      )     , ;
             ,-|`.            _,'/       )    ) ,' ,'
            (  :`.`-..____..=:.-':     .     _,' ,'
             `,'\ ``--....-)='    `._,  \  ,') _ '``._
          _.-/ _ `.       (_)      /     )' ; / \ \`-.'
         `--(   `-:`.     `' ___..'  _,-'   |/   `.)
             `-. `.`.``-----``--,  .'
               |/`.\`'        ,','); SSt
                   `         (/  (/
EOF

create_sonarr
