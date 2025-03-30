#!/usr/bin/env bash
# Script to move complete TV shows, update Sonarr, and invoke "Refresh and Scan" with a delay
# ---------------------------
# Configuration
# ---------------------------
API_KEY="ADD-YOUR-API-KEY-HERE"
SONARR_URL="http://192.168.1.10:8989"
DOCKER_PATH_TV_NEW="/data/TV-new"
DOCKER_PATH_TV="/data/tv"
HOST_PATH_TV_NEW="/mnt/user/media/TV-new"
HOST_PATH_TV="/mnt/user/media/tv"
DRY_RUN=true  # Set to true for dry run, false for actual execution
REFRESH_DELAY=10  # Delay in seconds before invoking "Refresh and Scan"

# ---------------------------
# Helper Functions
# ---------------------------
translate_docker_to_host() {
  local docker_path="$1"
  echo "${docker_path//$DOCKER_PATH_TV_NEW/$HOST_PATH_TV_NEW}" | \
       sed "s|$DOCKER_PATH_TV|$HOST_PATH_TV|"
}

translate_host_to_docker() {
  local host_path="$1"
  echo "${host_path//$HOST_PATH_TV_NEW/$DOCKER_PATH_TV_NEW}" | \
       sed "s|$HOST_PATH_TV|$DOCKER_PATH_TV|"
}

refresh_and_scan_series() {
  local series_id="$1"
  echo "Waiting for $REFRESH_DELAY seconds before invoking 'Refresh and Scan' for series ID $series_id..."
  sleep $REFRESH_DELAY
  echo "Invoking 'Refresh and Scan' for series ID $series_id..."
  REFRESH_PAYLOAD=$(jq -n --argjson seriesId "$series_id" '{"name": "RefreshSeries", "seriesId": $seriesId}')
  RESPONSE=$(curl -s -X POST \
    -H "X-Api-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$REFRESH_PAYLOAD" \
    "$SONARR_URL/api/v3/command")
  
  if echo "$RESPONSE" | jq -e '.id' > /dev/null; then
    echo "Successfully invoked 'Refresh and Scan' for series ID $series_id."
  else
    echo "WARNING: Failed to invoke 'Refresh and Scan' for series ID $series_id. Response: $RESPONSE"
  fi
}

# ---------------------------
# Main Logic
# ---------------------------
echo "Retrieving all series from Sonarr..."
SHOWS_JSON=$(curl -s -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/series")

# Verify if the API call was successful
if [ -z "$SHOWS_JSON" ]; then
  echo "ERROR: Unable to retrieve series data from Sonarr. Exiting..."
  exit 1
fi

echo "Identifying shows in $DOCKER_PATH_TV_NEW..."
SHOWS_IN_SOURCE=$(echo "$SHOWS_JSON" | jq -c '.[] | select(.path | contains("'"$DOCKER_PATH_TV_NEW"'"))')

if [ -z "$SHOWS_IN_SOURCE" ]; then
  echo "No shows found in $DOCKER_PATH_TV_NEW. Exiting..."
  exit 0
fi

echo "Processing shows in $DOCKER_PATH_TV_NEW..."
while read -r SHOW; do
  SHOW_ID=$(echo "$SHOW" | jq '.id')
  SHOW_TITLE=$(echo "$SHOW" | jq -r '.title')
  DOCKER_SHOW_PATH=$(echo "$SHOW" | jq -r '.path')

  # Translate Docker path to host path for file operations
  SHOW_PATH=$(translate_docker_to_host "$DOCKER_SHOW_PATH")
  NEW_PATH=$(translate_docker_to_host "$DOCKER_PATH_TV/$(basename "$DOCKER_SHOW_PATH")")

  echo "Checking \"$SHOW_TITLE\" for complete aired seasons..."
  COMPLETE_SEASONS=$(echo "$SHOW" | jq '[.seasons[] | select(.monitored == true and .statistics.nextAiring == null and .statistics.episodeFileCount == .statistics.episodeCount)]')

  if [ "$(echo "$COMPLETE_SEASONS" | jq 'length')" -gt 0 ]; then
    echo "===> \"$SHOW_TITLE\" has complete aired seasons!"

    # Debugging: Check if the source directory exists
    if [ -d "$SHOW_PATH" ]; then
      echo "Source directory \"$SHOW_PATH\" exists. Proceeding to move..."
      if [ "$DRY_RUN" = true ]; then
        # Dry run: simulate the move and update
        echo "[DRY RUN] Would move \"$SHOW_TITLE\" from \"$SHOW_PATH\" to \"$NEW_PATH\"."
        echo "[DRY RUN] Would update Sonarr with new path: \"$DOCKER_PATH_TV/$(basename "$DOCKER_SHOW_PATH")\"."
      else
        # Actual execution: move and update
        mv "$SHOW_PATH" "$NEW_PATH"
        if [ $? -eq 0 ]; then
          echo "Successfully moved \"$SHOW_TITLE\" to \"$NEW_PATH\"."

          # Retrieve additional required fields for the show
          TVDB_ID=$(echo "$SHOW" | jq '.tvdbId')
          TMDB_ID=$(echo "$SHOW" | jq '.tmdbId')
          IMDB_ID=$(echo "$SHOW" | jq -r '.imdbId')
          QUALITY_PROFILE_ID=$(echo "$SHOW" | jq '.qualityProfileId')
          MONITORED=$(echo "$SHOW" | jq '.monitored')
          TITLE=$(echo "$SHOW" | jq -r '.title')
          SEASON_FOLDER=$(echo "$SHOW" | jq '.seasonFolder')

          if [ -z "$QUALITY_PROFILE_ID" ] || [ "$QUALITY_PROFILE_ID" -le 0 ]; then
            echo "ERROR: Invalid QualityProfileId for \"$SHOW_TITLE\". Skipping Sonarr update..."
          else
            # Translate host path back to Docker path for Sonarr update
            DOCKER_NEW_PATH=$(translate_host_to_docker "$NEW_PATH")
            echo "Updating Sonarr for \"$SHOW_TITLE\"..."
            UPDATE_PAYLOAD=$(jq -n \
              --arg id "$SHOW_ID" \
              --arg path "$DOCKER_NEW_PATH" \
              --argjson tvdbId "$TVDB_ID" \
              --argjson tmdbId "$TMDB_ID" \
              --arg imdbId "$IMDB_ID" \
              --argjson qualityProfileId "$QUALITY_PROFILE_ID" \
              --argjson monitored "$MONITORED" \
              --arg title "$TITLE" \
              --argjson seasonFolder "$SEASON_FOLDER" \
              '{"id": ($id|tonumber), "path": $path, "tvdbId": $tvdbId, "tmdbId": $tmdbId, "imdbId": $imdbId, "qualityProfileId": $qualityProfileId, "monitored": $monitored, "title": $title, "seasonFolder": $seasonFolder}')
            
            RESPONSE=$(curl -s -X PUT \
              -H "X-Api-Key: $API_KEY" \
              -H "Content-Type: application/json" \
              -d "$UPDATE_PAYLOAD" \
              "$SONARR_URL/api/v3/series")
            
            if echo "$RESPONSE" | jq -e '.id' > /dev/null; then
              echo "Sonarr successfully updated \"$SHOW_TITLE\" with the new path."
              # Invoke "Refresh and Scan" with a delay
              refresh_and_scan_series "$SHOW_ID"
            else
              echo "WARNING: Failed to update Sonarr for \"$SHOW_TITLE\". Response: $RESPONSE"
            fi
          fi
        else
          echo "ERROR: Failed to move \"$SHOW_TITLE\" to \"$NEW_PATH\"."
        fi
      fi
    else
      echo "ERROR: Source directory \"$SHOW_PATH\" does not exist. Skipping \"$SHOW_TITLE\"."
    fi
  else
    echo "===> \"$SHOW_TITLE\" has no complete aired seasons. Skipping..."
  fi
done <<< "$(echo "$SHOWS_IN_SOURCE" | jq -c '.')"

echo "Script completed."
