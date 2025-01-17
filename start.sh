#!/bin/bash

echo "Starting qBittorrent port manager..."
echo "Server: ${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}"
echo "User: ${QBITTORRENT_USER}"

COOKIES="/tmp/cookies.txt"

update_port() {
  local PORT=$(cat "$PORT_FORWARDED")
  local PREF_STATUS

  # Check if cookies exist, assume logged in if they do
  if [ -f "$COOKIES" ]; then
    # Update preferences and check status code
    PREF_STATUS=$(curl -s -o /dev/null -b "$COOKIES" -w "%{http_code}" --data 'json={"listen_port": "'"$PORT"'"}' "${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/app/setPreferences")
  else
      PREF_STATUS="403" # force login
  fi

  # Handle 403 by logging in
  if [[ "$PREF_STATUS" == "403" ]]; then
    echo "Session expired or cookies missing. Attempting to log in."
    # Login and check for success
    LOGIN_RESPONSE=$(curl -s -c "$COOKIES" --data "username=$QBITTORRENT_USER&password=$QBITTORRENT_PASS" "${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/auth/login")

    if [[ "$LOGIN_RESPONSE" == "Ok." ]]; then
      echo "Login successful."

      # Retry updating preferences
      PREF_STATUS=$(curl -s -o /dev/null -b "$COOKIES" -w "%{http_code}" --data 'json={"listen_port": "'"$PORT"'"}' "${HTTP_S}://${QBITTORRENT_SERVER}:${QBITTORRENT_PORT}/api/v2/app/setPreferences")
    else
      echo "Login failed. Response: $LOGIN_RESPONSE"
    fi
  fi

  # Check the final status of setPreferences
  if [[ "$PREF_STATUS" == "200" ]]; then
    echo "Successfully updated qBittorrent to port $PORT"
    CURRENT_PORT="$PORT"
  else
    echo "Error updating preferences. Status code: $PREF_STATUS"
  fi
}

LAST_PORT=""
while true; do
  if [ -f "$PORT_FORWARDED" ]; then
    NEW_PORT=$(cat "$PORT_FORWARDED" 2>/dev/null || echo "") # Handle read errors
    if [[ "$NEW_PORT" != "$LAST_PORT" ]]; then
      update_port
      # Only update LAST_PORT if update_port was successful
      if [[ "$CURRENT_PORT" != "" ]]; then
        LAST_PORT="$CURRENT_PORT"
      fi
    fi
    sleep 10
  else
    echo "Couldn't find file $PORT_FORWARDED"
    echo "Trying again in 10 seconds"
    sleep 10
  fi
done
