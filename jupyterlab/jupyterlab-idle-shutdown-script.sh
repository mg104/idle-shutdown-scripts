#!/bin/bash

# Initializing command line arguments
CONTAINER_NAME=""
SLEEP_SECONDS="300"
LOG_FILE=""
CHECK_INTERVAL="10"

# Function to show usage
usage() {
	echo "Usage: $0 -n <CONTAINER_NAME> [-s <SLEEP_SECONDS>] [-l <ABSOLUTE_LOG_FILE_PATH>]" >&2
	exit 1
}

# Parsing command line arguments
while getopts ":n:s:l:" opt; do
	case $opt in 
		n)
			CONTAINER_NAME="${OPTARG}"
			;;
		s)
			SLEEP_SECONDS="${OPTARG}"
			;;
		l)
			LOG_FILE="${OPTARG}"
			;;
		\?)
			echo "Invalid option: -${OPTARG}" >&2
			usage
			;;
		:)
			echo "Option -${OPTARG} requires an argument" >&2
			usage
			;;
	esac
done

if [ -z "${CONTAINER_NAME}" ]; then
	echo "Container name not provided" >&2
	usage	
fi

if [ -z "${LOG_FILE}" ]; then
	LOG_FILE="/dev/null"
fi

shift $((OPTIND-1))

# Making log file if not there already
if [ ! -f "${LOG_FILE}" ]; then
	echo "New file created on $(date)" > "${LOG_FILE}"
fi

# Emptying log file
echo '=============================Cleared log file from previous runs===============================' > "${LOG_FILE}"

exec >> "${LOG_FILE}" 2>&1

# Holding on till docker container starts up
echo "Checking if docker is running"
while true; do
	if docker info >/dev/null 2>&1; then
		echo "Docker is running"
		break
	else
		echo "Waiting for docker to start"
		sleep 1
	fi
done

#Printing env variables before going to sleep for 5 minutes

# Get the docker container's name from BASHRC file. Declare it in .bashrc file for purposes of being used at startup
echo "Container Name: ${CONTAINER_NAME}"

# Get the Jupyter Token from the running container
JUPYTER_TOKEN=$(/usr/bin/docker exec ${CONTAINER_NAME} printenv JUPYTER_TOKEN)
echo "Jupyter token: ${JUPYTER_TOKEN}"

# Create the jupyterlab api-session URL string
API_SESSION="localhost:8888/api/sessions?token=${JUPYTER_TOKEN}"
echo -e "API Session: ${API_SESSION}\n"
echo "---------------------------------------------------------------------------"

# Sleeping for some time to allow time to start notebooks
echo "Sleeping for ${SLEEP_SECONDS} seconds"
sleep ${SLEEP_SECONDS}

# Create a while loop to check every n seconds if there is no kernel running
while true; do
	RESPONSE=$(/usr/bin/docker exec ${CONTAINER_NAME} curl -s "${API_SESSION}")
	echo -e "Response:\n${RESPONSE}\n"
	if [ "${RESPONSE}" == "[]" ]; then
		echo -e "Jupyterlab curl API returned an empty array. Shutting down...\n"
		shutdown now
		SHUTDOWN_STATUS=$?
		if [ ${SHUTDOWN_STATUS} -ne 0 ]; then
			/mnt/c/WINDOWS/system32/wsl.exe -t Ubuntu-20.04
		fi
	else 
		echo "Received Response ============> Not shutting down"
	fi 
	echo "------------------------------------------------------------------------------"
	sleep ${CHECK_INTERVAL}
done
