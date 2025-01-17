#!/bin/bash

echo "Starting qBittorrent port manager..."
echo "Server: ${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}"
echo "User: ${QBITTORRENT_USER}"

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
      CURRENT_PORT="$PORT"
    else
      echo "Error updating preferences. Status code: $PREF_STATUS"
    fi

  else
    echo "Login failed. Response: $LOGIN_RESPONSE"
  fi

  rm -f "$COOKIES"
}

LAST_PORT=""
while true; do
  if [ -f "$PORT_FORWARDED" ]; then
    # inotifywait is broken on my Asustor NAS
    # inotifywait -mq -e close_write $PORT_FORWARDED | while read change; do
    NEW_PORT=$(cat "$PORT_FORWARDED" 2>/dev/null || echo "") # Handle read errors
    if [[ "$NEW_PORT" != "$LAST_PORT" ]]; then
      update_port
      # Only update LAST_PORT if update_port was successful (CURRENT_PORT was updated)
      if [[ "$CURRENT_PORT" != "" ]]; then
          LAST_PORT="$CURRENT_PORT"
      fi
    fi
  else
    echo "Couldn't find file $PORT_FORWARDED"
    echo "Trying again in 10 seconds"
    sleep 10
  fi
done
