#!/bin/bash

declare -A LOGGING_LEVELS=( # associate logging levels with numbers
    ["NONE"]=-1
    ["ERROR"]=0
    ["INFO"]=1
    ["DEBUG"]=2
)

LOGGING_LEVEL="ERROR" # set default logging level
WRITING_MODE="JSON" # set default writing mode

log() {
    # $1 = message level, $2 = message
    LEVEL=$1
    MSG=$2

    # only log if LEVEL <= LOGGING_LEVEL
    if [ ${LOGGING_LEVELS[$LEVEL]} -le ${LOGGING_LEVELS[$LOGGING_LEVEL]} ]; then
        case $LEVEL in
            DEBUG) COLOR="\e[36m";;   # cyan
            INFO) COLOR="\e[32m";;     # green
            ERROR) COLOR="\e[31m";;   # red
            *) COLOR="\e[0m";;
        esac
        printf '%b' "$COLOR[$LEVEL | $(date '+%Y-%m-%d %H:%M:%S')] $MSG\e[0m"
    fi
}

get_minutes_until_bus() {
    # $1 = time when the bus arrives in seconds since midnight
    BUS_TIME=$1

    seconds_now=$( date +%s )
    seconds_at_midnight=$( date -d "today 00:00:00" +%s )
    seconds_since_midnight=$(( seconds_now - seconds_at_midnight ))
    seconds_until_bus=$(( BUS_TIME - seconds_since_midnight ))
    minutes_until_bus=$(( seconds_until_bus / 60 ))

    echo $minutes_until_bus
}

while getopts "hs:o:l:" opt; do
    case $opt in
        h)
            echo "Usage: $0 [OPTIONS]
-h      Show this help message and exit
-s      [MANDATORY] Specify stop id (usually a 4-digit integer, get here: https://docs.google.com/spreadsheets/d/1FaRhmFvxCVLVhHCnEjrGq3l42fSa1R648fk2H3xqHuQ/pubhtml)
-o      Specify output writing mode(JSON/COMMAND_LINE), default: JSON
-l      Specify logging level(NONE/ERROR/INFO/DEBUG), default: ERROR"
            exit
            ;;
        s)
            STOP_ID="$OPTARG"
            ;;
        o)
            case "$OPTARG" in
                JSON|COMMAND_LINE)
                    WRITING_MODE="$OPTARG"
                    ;;
                *)
                    log "ERROR" "Invalid writing mode: $OPTARG; run getBusStopInfo -h for help\n"
                    exit
                    ;;
            esac
            ;;
        l)
            case "$OPTARG" in
                NONE|ERROR|INFO|DEBUG)
                    LOGGING_LEVEL="$OPTARG"
                    ;;
                *)
                    log "ERROR" "Invalid logging level: $OPTARG; run getBusStopInfo -h for help\n"
                    exit
                    ;;
            esac
            ;;
        *)
            exit
            ;;
    esac
done

URL="https://www.stops.lt/vilnius/departures2.php?stopid=$STOP_ID"

# positions of information in each line of the response body. positions are separated by ','
BUS_TYPE=0
BUS_NUM=1
BUS_TIME=3
BUS_DIRECTION=5

if [ -z "$STOP_ID" ]; then
    log "ERROR" "Stop id was not provided; run getBusStopInfo -h for help\n"
    exit
fi

log "INFO" "Sending GET request to $URL\n"

# -D - : show headers
# -m 10: timeout after 10 seconds
# -s: don't show progress
RESPONSE=$(curl -s -m 10 -D - "$URL")
CURL_EXIT_CODE=$?

if [ $CURL_EXIT_CODE -ne 0 ]; then
    log "ERROR" "Request failed with curl exit code $CURL_EXIT_CODE\n"
    exit
fi

HEADERS=$(echo "$RESPONSE" | sed -n '/^\r$/q;p')
BODY=$(echo "$RESPONSE" | sed -n '/^\r$/,$p' | sed '1d')

if [ -z "$BODY" ]; then
    log "ERROR" "Invalid stop id: $STOP_ID; run getBusStopInfo -h for help\n"
    exit
fi

log "INFO" "Request succeeded\n"
log "DEBUG" "Response headers: \n$HEADERS\n"
log "DEBUG" "Response body: \n$BODY\n"

log "INFO" "Building associative arrays\n"
mapfile -t buses <<< "$BODY" # split $BODY by '\n'
if [ $WRITING_MODE = "JSON" ]; then
    output="{\"$STOP_ID\":{"
else
    output="STOP: $STOP_ID\n"
fi

for i in "${!buses[@]}"; do 
    if [ $i -eq 0 ]; then # the first element is the stop id, which we already have
        continue
    fi

    declare -A "bus$i"
    declare -n bus="bus$i"
    mapfile -t bus_info < <(echo "${buses[$i]}" | tr ',' '\n') # split each line into positions. mapfile only splits by '\n', so we need to replace all ',' with '\n'

    bus=( # create associative arrays for each bus
        [bus_type]="${bus_info[$BUS_TYPE]}"
        [bus_num]="${bus_info[$BUS_NUM]}"
        [bus_time]="$(get_minutes_until_bus ${bus_info[$BUS_TIME]}) min"
        [bus_direction]="${bus_info[$BUS_DIRECTION]}"
    )

    log "DEBUG" "Built bus$i: ${bus[bus_type]} ${bus[bus_num]}\n"

    if [ $WRITING_MODE = "JSON" ]; then
        # append bus to json string
        output+="\"bus$i\":{"
        output+="\"bus_type\":\"${bus[bus_type]}\","
        output+="\"bus_num\":\"${bus[bus_num]}\","
        output+="\"bus_time\":\"${bus[bus_time]}\","
        output+="\"bus_direction\":\"${bus[bus_direction]}\""
        output+="},"
    else
        # append bus to command line output string
        output+="${bus[bus_type]^} ${bus[bus_num]^^} heading towards ${bus[bus_direction]} is in ${bus[bus_time]}\n"
    fi

done

if [ $WRITING_MODE = "JSON" ]; then
    output="${output%,}}}" # remove trailing comma and close json

    log "INFO" "Json string built\n"
    log "DEBUG" "Built json string: $output\n"

    log "INFO" "Writing to $STOP_ID.json\n"
    echo -n $output > "$STOP_ID.json"
else
    log "INFO" "Human-readable output string built\n"
    log "DEBUG" "Built human-readable output string: \n$output"
    printf '%b' "$output"
fi

log "INFO" "Completed\n"