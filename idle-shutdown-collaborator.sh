#!/bin/bash

#### Enumerate the scripts and their respective options into 2 lists (1 list containing each script and the other one containing that script's corresponding options)

# Error function
master_script_usage() {
	echo "Usage: $0 -- script1 [args] script2 [args] ..." >&2
	exit 0
}

# Checking if only the script name has been provided without any containers to be monitored
if [ "$#" -eq 0 ]; then
	echo "Scripts monitoring some containers are required."
	master_script_usage
fi

# Get container names from all scripts
CONTAINER_NAMES=$(echo "$*" | grep -oP "\-n\s+\K\S+" | tr "\n" " " | sed "s/ $//")
echo "CONTAINER_NAMES: ${CONTAINER_NAMES}"

# Finding number of containers being monitored
CONTAINER_COUNT=$(echo "${CONTAINER_NAMES}" | wc -w)
echo "CONTAINER_COUNT: ${CONTAINER_COUNT}"

# Initialize the empty arrays
declare -a SCRIPT_ARRAY=()
declare -a OPTIONS_ARRAY=()
declare -a CURRENT_ARGS=()

# Function to add each script and its options to the above arrays
add_script_and_options() {
	SCRIPT_ARRAY+=("$1")
	shift
	OPTIONS_ARRAY+=("$*")
}

# Looping through all arguments to put those between 2 "--" strings into SCRIPT_ARRAY and OPTIONS_ARRAY
for arg in "$@"; do
	if [ "$arg" == "--" ]; then
		if [ "${#CURRENT_ARGS[@]}" -gt 0 ]; then
			add_script_and_options "${CURRENT_ARGS[0]}" "${CURRENT_ARGS[@]:1}"
		fi
		CURRENT_ARGS=()
	else
		CURRENT_ARGS+=("$arg")
	fi
done

# Capturing the script name and options after the last "--" string
if [ "${#CURRENT_ARGS[@]}" -gt 0 ]; then
	add_script_and_options "${CURRENT_ARGS[0]}" "${CURRENT_ARGS[@]:1}"
fi

# Check if docker is running
while true; do
	if docker info > /dev/null 2>&1; then
		echo "Docker is running"
		break
	else
		echo "Docker is not running. Waiting for 10 seconds..."
		sleep 10
	fi
done

# Check if the docker containers listed in the scripts are running or not

check_container_status() {
	if docker ps --format "{{.Names}}" | grep -wq "^$1$"; then
		echo "Docker container $1 is running."
	else
		echo "Docker container $1 is not running. Waiting..."
		sleep 10
		check_container_status "$1"
	fi
}

for CONTAINER in $CONTAINER_NAMES; do
	check_container_status "${CONTAINER}"
done

# Creating an array capturing the PID of the script running. This list will be used to check the exit status of the asynchronously running scripts and decrement CONTAINER_COUNT accordingly
declare -a PID_ARRAY=()

# Run a while true loop that runs both the scripts (asynchronously) at regular intervals, and shuts down the host computer if all the scripts return an exit status of 1 (error) or SHUTDOWN_SIGNAL=1
for i in "${!SCRIPT_ARRAY[@]}"; do
	echo "Running script ${SCRIPT_ARRAY[i]} ${OPTIONS_ARRAY[i]}"
	"${SCRIPT_ARRAY[i]}" ${OPTIONS_ARRAY[i]} &
	PID_ARRAY+=("$!")
	echo "PID: $!"
done

# Checking the exit statuses of asynchronously running and exited scripts and decrementing the CONTAINER_COUNT if both give shutdown signal by exiting with status 0
for PID in "${PID_ARRAY[@]}"; do
	wait "${PID}"
	EXIT_STATUS="$?"
	if [ "${EXIT_STATUS}" -eq 0 ]; then
		CONTAINER_COUNT=$((${CONTAINER_COUNT}-1))
		echo "Script with PID ${PID} has given go ahead to shutdown its container. Proceeding to next step..."
	fi
done

echo "Ran both the scripts"

# Shutting down the host if the all above scripts have exited indicating that all containers are idle
if [ "${CONTAINER_COUNT}" -eq 0 ]; then
	/usr/sbin/shutdown now
	SHUTDOWN_STATUS=$?
	if [ ${SHUTDOWN_STATUS} -ne 0 ]; then
		/mnt/c/WINDOWS/system32/wsl.exe -t Ubuntu-20.04
	fi
else
	echo "One or more shutdown scripts didn't execute fully."
fi
