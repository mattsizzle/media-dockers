#!/usr/bin/env bash

# This mount holds configs related to the services
MOUNT_POINT=/home/matt/dockerfs
# This mount point holds media that is shown in plex
MEDIA_MOUNT_POINT=/mnt/castle
# Where download(ing) files from utorrent are stored
DOWNLOAD_MOUNT_POINT=/home/matt/dockerfs/downloads
# The timezone used by the containers
TIMEZONE=US/Central

PUID=1000
PGID=1000

# ---------- Handlers ----------
PROGNAME=$(basename $0)

error_exit () {
	echo "${PROGNAME}: ${1:-Unexpected Error}" 1>&2
	exit 1
}

d_delete () {
	docker rm $1 > /dev/null || error_exit "Failed to delete container $1. Delete this container manually with `docker rm -f $1`  Aborting."
}

d_running () {
	docker inspect --format '{{.State.Running}}' $1 > /dev/null || error_exit "Failed to check running status of container $1. Aborting."
}

d_exists () {
	docker ps -a | grep $1 > /dev/null
}

full_delete () {
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

full_start () {
	echo "Starting $1 container."

	docker start $1 > /dev/null || error_exit "Failed to start container $1. Aborting."
	IP_ADDRESS=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1 || "UNKNOWN")

	echo "Container Started: $1 with IP: $IP_ADDRESS"
	echo "Conatiner Accessible @: $IP_ADDRESS:$S_PORT"
}

full_stop () {
	echo "Stoping $1 container."
	docker stop $1 > /dev/null || error_exit "Failed to stop container $1. Aborting."
	echo "Container Stoped: $1"
}

full_create () {
	name=$1
	container=$2
	shift 2
	args=("$@")

	echo "Creating $SONARR_NAME container."
	docker create --name $name ${args[@]} $container > /dev/null || "Error creating container: $?"

	sleep 3;
	full_start $name
}

create_sonarr () {
	# Setup the Sonarr Container
	# https://hub.docker.com/r/linuxserver/sonarr/
	# Deprecated into the localtime mount below. -e TZ=<timezone> \

	# SONARR Variables
	BASE_CONTAINER='linuxserver/sonarr'
	SONARR_NAME='mc-sonarr'
	I_PORT=8989
	S_PORT=8989
	declare -a S_OPTS=(
		"-v /etc/localtime:/etc/localtime:ro"
		"-v $MOUNT_POINT/sonarr-config:/config"
		"-v $DOWNLOAD_MOUNT_POINT/completed:/downloads"
		#"-v $MEDIA_MOUNT_POINT/tv:/tv"
		"-p $I_PORT:$S_PORT"
		"-e PPUID=$PUID -e PPGID=$PGID"
	);

	printf "Prepping for creation of container [$BASE_CONTAINER] $SONARR_NAME\n"
	printf "Using Options:\n"
	printf '  %s\n' "${S_OPTS[@]}"

	full_delete $SONARR_NAME
	full_create $SONARR_NAME $BASE_CONTAINER "${S_OPTS[@]}"
}

create_radarr () {
	# Setup the Radarr Container
	# https://hub.docker.com/r/linuxserver/radarr/

	# RADARR Variables
	BASE_CONTAINER='linuxserver/radarr'
	RADARR_NAME='mc-radarr'
	I_PORT=7878
	S_PORT=7878
	declare -a S_OPTS=(
		"-v $MOUNT_POINT/radarr-config:/config"
		"-v $DOWNLOAD_MOUNT_POINT/completed:/downloads"
		#"-v $MEDIA_MOUNT_POINT/movies:/movies"
		"-e PPGID=$PGID -e PPUID=$PUID"
		"-e TZ=$TIMEZONE"
		"-p $I_PORT:$S_PORT"
	);
	
	printf "Prepping for creation of container [$BASE_CONTAINER] $RADARR_NAME\n"
	printf "Using Options:\n"
	printf '  %s\n' "${S_OPTS[@]}"

	full_delete $RADARR_NAME
	full_create $RADARR_NAME $BASE_CONTAINER "${S_OPTS[@]}"
}

create_jackett () {
	# Setup the Jackett Container
	# https://hub.docker.com/r/linuxserver/jackett/

	# JACKETT Variables
	BASE_CONTAINER='linuxserver/jackett'
	JACKETT_NAME='mc-jackett'
	I_PORT=9117
	S_PORT=9117
	declare -a S_OPTS=(
		"-v $MOUNT_POINT/jackett-config:/config"
		"-v $DOWNLOAD_MOUNT_POINT:/downloads"
		"-e PPGID=$PGID -e PPUID=$PUID"
		"-e TZ=$TIMEZONE"
		"-p $I_PORT:$S_PORT"
	);

	printf "Prepping for creation of container [$BASE_CONTAINER] $JACKETT_NAME\n"
	printf "Using Options:\n"
	printf '  %s\n' "${S_OPTS[@]}"

	full_delete $JACKETT_NAME
	full_create $JACKETT_NAME $BASE_CONTAINER "${S_OPTS[@]}"
}

create_rutorrent () {
	# Setup the Rutorrent Container
	# https://hub.docker.com/r/linuxserver/rutorrent/
	# Deprecated into the localtime mount below. -e TZ=<timezone> \

	# RUTORRENT Variables
	BASE_CONTAINER='linuxserver/rutorrent'
	RUTORRENT_NAME='mc-rutorrent'
	I_PORT=80
	S_PORT=80
	declare -a S_OPTS=(
		"-v $MOUNT_POINT/rutorrent-config:/config"
		"-v $DOWNLOAD_MOUNT_POINT:/downloads"
		"-e PGID=$PGID -e PUID=$PUID"
		"-e TZ=$TIMEZONE"
		"-p $S_PORT:$I_PORT -p 5000:5000"
		"-p 51413:51413 -p 6881:6881/udp"
	);

	printf "Prepping for creation of container [$BASE_CONTAINER] $RUTORRENT_NAME\n"
	printf "Using Options:\n"
	printf '  %s\n' "${S_OPTS[@]}"

	full_delete $RUTORRENT_NAME
	full_create $RUTORRENT_NAME $BASE_CONTAINER "${S_OPTS[@]}"
}

create_all () {
	printf "Creatomg All Docker Containers\n"

	full_create "mc-jackett"
	full_create "mc-sonarr"
	full_create "mc-radarr"
	full_create "mc-rutorrent"
}

start_all () {
	printf "Starting All Docker Containers\n"

	full_start "mc-jackett"
	full_start "mc-sonarr"
	full_start "mc-radarr"
	full_start "mc-rutorrent"
}

stop_all () {
	printf "Stoping All Docker Containers\n"

	full_stop "mc-jackett"
	full_stop "mc-sonarr"
	full_stop "mc-radarr"
	full_stop "mc-rutorrent"
}

create_init () {
	if [ -z "$1" ];
	then
		usage
	fi

	while [ "$1" != "" ]; do
		case $1 in
			all | All )         create_all
								;;
			* )                 full_create $1
		esac
		shift
	done
	exit 0;
}

start_init () {
	if [ -z "$1" ];
	then
		usage
	fi

	while [ "$1" != "" ]; do
		case $1 in
			all | All )         start_all
								;;
			* )                 full_start $1
		esac
		shift
	done
	exit 0;
}

stop_init () {
	if [ -z "$1" ];
	then
		usage
	fi

	while [ "$1" != "" ]; do
		case $1 in
			all | All )         stop_all
								;;
			* )                 full_stop $1
		esac
		shift
	done
	exit 0;
}

usage() { 
	printf "Usage:	$0 COMMAND\n"
	cat <<"EOF"

A management wrapper around various HTPC related docker containers

Options:

  --help	Print usage

  --create	Given a valid container name destructively creates a new container of that type.
  		With no additional agruments an interactive creation menu is presented.

  --start	Given a valid container name (re)starts the container and displays the containers details.
  		With no additonal agruments it will start all the known (mc-*) containers.			

  --stop	Given a valid container name stops the containersss.
  		With no additonal agruments it will start all the known (mc-*) containers.
EOF
	exit 1;
}

# ---- MAIN -----
if [ -z "$1" ];
then
	usage
fi
declare COMMAND
while [ "$1" != "" ]; do
    case $1 in
        -c | create )	shift
                        COMMAND=$1 # TODO || interactive()
						create_init $COMMAND
                        ;;
        -s | start )    shift
                        COMMAND=$1 # TODO || interactive()
						start_init $COMMAND
						;;
        -r | stop )     shift
                        COMMAND=$1 # TODO || interactive()
						stop_init $COMMAND
                        ;;
        -h | help )     usage
                        exit
                        ;;
        * )             usage
                        exit 1
    esac
    shift
done
printf '\n'