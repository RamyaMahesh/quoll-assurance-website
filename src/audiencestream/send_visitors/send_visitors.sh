#!/bin/bash

usage() {
cat << EOF
usage: $0 options

Send visitor events to uconnect

OPTIONS:
   -a      the account to use when sending visitor(s) to uconnect
   -p      the profile to use when sending visitor(s) to uconnect
   -n      the number of visitors to send
   -s      duration in seconds that the script will wait between each request to uconnect
   -d      the duration in seconds that the visitor will be active in DataCloud
   -f      the data file to use
   -i      the TID (visitor ID) value to send to uconnect
   -u      the user agent of the visitor(s)
   -t      the trace id value to send to uconnect
   -r      the request type to uconnect (could be 1, 2, 3 or 4)
   -m      the http request method (could be GET or POST)
   -h      show this message

EOF
}

# set defaults
ACCOUNT="qa15-jas2"
PROFILE="main"
NUM_VISITORS=1
SLEEP_TIME=0
TTL_DURATION=60
TRACE_ID=""
SCRIPT_LOCATION="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATA_FILE_PATH="$SCRIPT_LOCATION/data_json"
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/31.0.1650.57 Safari/537.37"
REQUEST_TYPE=2
REQUEST_METHOD="POST"

# process arguments
while getopts "a:p:n:s:d:f:i:r:t:u:m:h" OPTION; do
     case $OPTION in
         a) ACCOUNT=$OPTARG ;;
         p) PROFILE=$OPTARG ;;
         n) NUM_VISITORS=$OPTARG ;;
         s) SLEEP_TIME=$OPTARG ;;
         d) TTL_DURATION=$OPTARG ;;
         f) DATA_FILE_PATH=$OPTARG ;;
         i) TID=$OPTARG ;;
         r) REQUEST_TYPE=$OPTARG ;;
         t) TRACE_ID=$OPTARG ;;
         u) USER_AGENT=$OPTARG ;;
         m) REQUEST_METHOD=$OPTARG ;;
         h) usage; exit ;;
         ?) usage; exit ;;
     esac
done

#BASE_URL="http://qa16-collect-eu-west-1.tealiumiq.com/$ACCOUNT/$PROFILE/$REQUEST_TYPE/i.gif"
BASE_URL="https://qa12-collect.tealiumiq.com/qa12-mar/main/2/i.gif"
#BASE_URL="http://localhost:9090/tealium/main/2/i.gif"

if [ -n "$TID" ] ; then
  TID_COOKIE="TIDCD=$TID"
fi

echo "===============================================";
echo "Account: $ACCOUNT";
echo "Profile: $PROFILE";
echo "Number of visitors to send: $NUM_VISITORS";
echo "Sleep time between visitors (seconds): $SLEEP_TIME";
echo "TTL duration per visitor (seconds): $TTL_DURATION";
echo "Data file path: $DATA_FILE_PATH"
echo "TID (visitor ID) to use: $TID"
echo "User Agent to use: $USER_AGENT"
echo "TRACE_ID (trace ID) to use: $TRACE_ID"
echo "REQUEST_TYPE (request type) to use: $REQUEST_TYPE"
echo "===============================================";

TTL_DURATION_MS=$(($TTL_DURATION * 1000))
PAYLOAD_RAW=$(<$DATA_FILE_PATH)

# replace $$DC_TTL_VALUE$$ with the actual TTL value
PAYLOAD_RAW=${PAYLOAD_RAW/\$\$DC_TTL_VALUE\$\$/$TTL_DURATION_MS}

# replace $$TRACE_ID_VALUE$$ with the actual TRACE_ID value
PAYLOAD_RAW=${PAYLOAD_RAW/\$\$TRACE_ID_VALUE\$\$/$TRACE_ID}

COUNTER=0
while [ $COUNTER -lt $NUM_VISITORS ]; do
  BADGE_NUM=`jot -r 1 0 10`

  # set up the payload to send (add badge ID and escape it)
  PAYLOAD=${PAYLOAD_RAW/\$\$BADGE_VALUE\$\$/badge$BADGE_NUM}

  # send the request
  if [ $REQUEST_METHOD == "GET" ]; then

    # URL encode for GET requests
    PAYLOAD="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$PAYLOAD")"
    curl -H "Referer: http://172.16.3.15:8000/datacloudtest.html" -A "$USER_AGENT" -b "$TID_COOKIE" -w "Sending visitor #$COUNTER... (with badge=$BADGE_NUM) [result=%{http_code} - GET $BASE_URL]\n" "$BASE_URL?data=$PAYLOAD" -so /dev/null

  else
    # create a temp file for POST requests
    PID=$$
    if [ -f data_json_tmp_$PID ] ; then
      rm data_json_tmp_$PID
    fi
    echo "$PAYLOAD" > data_json_tmp_$PID

    curl -H "Referer: http://172.16.3.15:8000/datacloudtest.html" -A "$USER_AGENT" -b "$TID_COOKIE" -w "Sending visitor #$COUNTER... (with badge=$BADGE_NUM) [result=%{http_code} - POST $BASE_URL]\n" -X POST -F "data=@data_json_tmp_$PID" "$BASE_URL" -so /dev/null

    # clean up temp file
    if [ -f data_json_tmp_$PID ] ; then
      rm data_json_tmp_$PID
    fi
  fi

  # sleep if necessary
  echo "Sleeping $SLEEP_TIME seconds..."
  sleep $SLEEP_TIME
  let COUNTER=COUNTER+1
done
