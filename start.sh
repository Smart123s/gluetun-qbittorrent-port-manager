#!/bin/bash

COOKIES="/tmp/cookies.txt"

update_port() {
  local PORT=$(cat "$PORT_FORWARDED")
  rm -f "$COOKIES"

  # Login and check for success
  LOGIN_RESPONSE=$(curl -s -c "$COOKIES" --data "username=$QBITTORRENT_USER&password=$QBITTORRENT_PASS" "${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/auth/login")

  if [[ "$LOGIN_RESPONSE" == "Ok." ]]; then
    echo "Login successful."

    # Update preferences and check status code
    PREF_STATUS=$(curl -s -o /dev/null -b "$COOKIES" -w "%{http_code}" --data 'json={"listen_port": "'"$PORT"'"}' "${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/app/setPreferences")

    if [[ "$PREF_STATUS" == "200" ]]; then
      echo "Successfully updated qBittorrent to port $PORT"
    else
      echo "Error updating preferences. Status code: $PREF_STATUS"
    fi

  else
    echo "Login failed. Response: $LOGIN_RESPONSE"
  fi

  rm -f "$COOKIES"
}

while true; do
  if [ -f $PORT_FORWARDED ]; then
    # inotifywait is broken on my Asustor NAS
    # inotifywait -mq -e close_write $PORT_FORWARDED | while read change; do
    while true; do
      update_port
      sleep 30
    done
  else
    echo "Couldn't find file $PORT_FORWARDED"
    echo "Trying again in 10 seconds"
    sleep 10
  fi
done
