#!/bin/bash

# Initializing command line arguments
CONTAINER_NAME=""
SLEEP_SECONDS="180"
LOG_FILE=""
CHECK_INTERVAL="180"

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

exec >> "${LOG_FILE}" 2>&1

# Recording new run
echo -e "============================= New idle shutdown script run on date: $(date) ===============================\n"

#Printing env variables before going to sleep for few minutes

# Get the docker container's name from BASHRC file. Declare it in .bashrc file for purposes of being used at startup
echo -e "Container Name: ${CONTAINER_NAME}\n"

# Get the Jupyter Token from the running container
JUPYTER_TOKEN=$(/usr/bin/docker exec ${CONTAINER_NAME} printenv JUPYTER_TOKEN)
echo -e "Jupyter token: ${JUPYTER_TOKEN}\n"

# Create the jupyterlab api-session URL string
API_SESSION="localhost:8888/api/sessions?token=${JUPYTER_TOKEN}"
echo -e "API Session: ${API_SESSION}\n"
echo -e "---------------------------------------------------------------------------\n"

# Sleeping for some time to allow time to start notebooks
echo -e "Sleeping for ${SLEEP_SECONDS} seconds to allow some time to start up the jupyterlab notebooks\n"
sleep ${SLEEP_SECONDS}
echo -e "Starting monitoring the jupyterlab activity on $(date)"

# Setting initial empty response count, to shut down only when we receive empty response the second time
EMPTY_RESPONSE_COUNT=0

# Create a while loop to check every n seconds if there is no kernel running
while true; do
	RESPONSE=$(/usr/bin/docker exec ${CONTAINER_NAME} curl -s "${API_SESSION}")
	if [ "${RESPONSE}" != "[]" ]; then
		if [ "${EMPTY_RESPONSE_COUNT}" == 1 ]; then
			echo "Jupyterlab notebook restarted on $(date) and therefore resetting the shutdown empty response counter"
		fi
		EMPTY_RESPONSE_COUNT=0
	elif [ "${RESPONSE}" == "[]" ]; then
		if [ ${EMPTY_RESPONSE_COUNT} -eq 0 ]; then
			echo -e "Jupyterlab curl API has returned an empty array for the first time on $(date). Waiting for it to return empty array the second time...\n"
			EMPTY_RESPONSE_COUNT=1
		else
			echo -e "Jupyterlab curl API returned an empty array for the second time on $(date). Giving signal to shut down by exiting with status 0...\n"
			echo -e "===================================Idle shutdown script recommended shutdown on date: $(date)==========================================\n\n\n\n"
			exit 0
		fi
	fi 
	sleep ${CHECK_INTERVAL}
done 

echo "========================================Idle shutdown script didn't run fully on date: $(date)========================================\n\n\n\n"
