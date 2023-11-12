#!/bin/bash

# Default option values
# top command will run every 1 second
SLEEP_SECONDS=1
# CPU threshold is taken to be 2% after observing vscode usage
CPU_THRESHOLD=2
# Wait time after discovering activity in VSCode
WAIT_TIME_AFTER_ACTIVITY=900
# Log file location
LOG_FILE=""
# Initializing the idle counter
SECONDS_IDLE=0
# Number of idle seconds after which to shutdown
IDLE_THRESHOLD=1800
# Time interval to monitor CPU usage, after idle is detected
IDLE_CHECK_INTERVAL=0.1
# Number of times to run top command in a batch
TOP_COMMAND_TIMES=10
# Idle Second increment
IDLE_SECOND_INCREMENT=$(echo "${IDLE_CHECK_INTERVAL} * ${TOP_COMMAND_TIMES} " | bc | cut -d. -f1)


# Define the usage function that throws error on wrong command invocation
usage() {
	echo "Usage: $0 -n <CONTAINER_NAME> [-s <SLEEP_SECONDS>] [-w <WAIT_TIME_AFTER_ACTIVITY>] [-c <CPU_THRESHOLD>] [-l <LOG_FILE_LOCATION>] [-s <SECONDS_IDLE>] [-i <IDLE_THRESHOLD>] [-d <IDLE_CHECK_INTERVAL>]" >&2
	exit 1
}

# Parse the options supplied with the script name
while getopts ":n:s:w:c:s:i:l:d:t" opt; do
	case $opt in
		n) 
			CONTAINER_NAME="${OPTARG}"
			;;
		s) 
			SLEEP_SECONDS="${OPTARG}"
			;;
		w)
			WAIT_TIME_AFTER_ACTIVITY="${OPTARG}"
			;;
		c)
			CPU_THRESHOLD="${OPTARG}"
			;;
		l)
			LOG_FILE="${OPTARG}"
			;;
		s)
			SECONDS_IDLE="${OPTARG}"
			;;
		i)
			IDLE_THRESHOLD="${OPTARG}"
			;;
		d)	
			IDLE_CHECK_INTERVAL="${OPTARG}"
			;;
		t)
			TOP_COMMAND_TIMES="${OPTARG}"
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

# Discarding the options already processed
shift $((OPTIND-1))

# Throw an error if any of necessary options are not given
if [ -z "${CONTAINER_NAME}" ]; then
	echo "CONTAINER_NAME required" >&2
	usage
fi

if [ -z "${LOG_FILE}" ]; then
	LOG_FILE="/dev/null"
fi

# Making the log file if it doesn't already exist
if [ ! -f "${LOG_FILE}" ]; then
	touch "${LOG_FILE}"
	echo "New log file created on date: $(date)" > "${LOG_FILE}"
fi

# Ensuring that all future logs are written to above file
exec >> "${LOG_FILE}" 2>&1
echo -e "==================================== New monitoring job started on date: $(date) ==================================\n"

echo -e "CONTAINER_NAME: ${CONTAINER_NAME}\n"
echo -e "SLEEP_SECONDS: ${SLEEP_SECONDS}\n"
echo -e "WAIT_TIME_AFTER_ACTIVITY: ${WAIT_TIME_AFTER_ACTIVITY}\n"
echo -e "CPU_THRESHOLD: ${CPU_THRESHOLD}\n"
echo -e "LOG_FILE: ${LOG_FILE}\n"
echo -e "SECONDS_IDLE: ${SECONDS_IDLE}\n"
echo -e "IDLE_THRESHOLD: ${IDLE_THRESHOLD}\n"
echo -e "IDLE_CHECK_INTERVAL: ${IDLE_CHECK_INTERVAL}\n"
echo -e "TOP_COMMAND_TIMES: ${TOP_COMMAND_TIMES}\n"
echo -e "IDLE_SECOND_INCREMENT: ${IDLE_SECOND_INCREMENT}\n"



# Finding the process id of vscode, that is most responsive to interaction with its editor and terminal (I found this out by hit & trial and experimentation)
VSCODE_PID=$(/usr/bin/docker exec "${CONTAINER_NAME}" /usr/bin/ps aux | /usr/bin/grep -P "[c]ode.*renderer" | /usr/bin/awk '{print $2}')
echo -e "PID of the VSCode that is being monitored: ${VSCODE_PID}\n"

# Checking CPU usage at each 0.1 second. Checking if the VScode CPU usage is above a threshold for 10 consecutive readings and stopping the iteration for 15 minutes if so. If not, then incrementing
# a counter to countdown towards shutdown
while true; do
	echo -e "Starting checking that the average CPU Utilization of PID ${VSCODE_PID}, for ${TOP_COMMAND_TIMES} times in the last ${IDLE_SECOND_INCREMENT} seconds is greater than ${CPU_THRESHOLD}% or not, on $(date)\n"
	AVG_CPU_UTILIZATION=$(/usr/bin/docker exec "${CONTAINER_NAME}" /usr/bin/top -b -n "${TOP_COMMAND_TIMES}" -d "${IDLE_CHECK_INTERVAL}" | /usr/bin/grep -P "${VSCODE_PID}" | /usr/bin/awk '{print $9}' | /usr/bin/awk '{sum+=$1; count+=1} END {print sum/count}')
	if [ "$(echo "${AVG_CPU_UTILIZATION} < ${CPU_THRESHOLD}" | bc)" -eq 1 ]; then
		SECONDS_IDLE=$((${SECONDS_IDLE}+${IDLE_SECOND_INCREMENT}))
	else
		echo -e "Observed activity in VSCode on $(date). Waiting for next ${WAIT_TIME_AFTER_ACTIVITY} seconds...\n"
		SECONDS_IDLE=0
		sleep "${WAIT_TIME_AFTER_ACTIVITY}"
	fi

	if [ "${SECONDS_IDLE}" -gt "${IDLE_THRESHOLD}" ]; then
		echo -e "VSCode has been inactive for ${SECONDS_IDLE}. Giving signal to shutdown on $(date) by exiting with status 0...\n"
		echo -e "============================================== Shutdown script exited by giving shutdown signal on $(date) ========================================\n\n\n\n"
		exit 0
	fi
done

echo -e "============================================ Shutdown script didn't exit properly =============================================\n\n\n\n"


