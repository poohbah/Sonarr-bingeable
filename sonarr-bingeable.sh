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
LOG_FILE="/var/log/sonarr_move_complete.log"

# ---------------------------
# Helper Functions
# ---------------------------
log() {
  local message="$1"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $message"
  if [ -n "$LOG_FILE" ]; then
    echo "[$timestamp] $message" >> "$LOG_FILE"
  fi
}

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
  log "Waiting for $REFRESH_DELAY seconds before invoking 'Refresh and Scan' for series ID $series_id..."
  sleep $REFRESH_DELAY
  log "Invoking 'Refresh and Scan' for series ID $series_id..."
  REFRESH_PAYLOAD=$(jq -n --argjson seriesId "$series_id" '{"name": "RefreshSeries", "seriesId": $seriesId}')
  RESPONSE=$(curl -s -X POST \
    -H "X-Api-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$REFRESH_PAYLOAD" \
    "$SONARR_URL/api/v3/command")
  
  if echo "$RESPONSE" | jq -e '.id' > /dev/null; then
    log "Successfully invoked 'Refresh and Scan' for series ID $series_id."
  else
    log "WARNING: Failed to invoke 'Refresh and Scan' for series ID $series_id. Response: $RESPONSE"
  fi
}

# ---------------------------
# Main Logic
# ---------------------------
# Create log directory if it doesn't exist
if [ -n "$LOG_FILE" ]; then
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE=""
  if [ -z "$LOG_FILE" ]; then
    echo "Warning: Could not create log directory. Logging to file disabled."
  fi
fi

log "=========== Starting TV Show Management Script ==========="
log "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "ACTUAL EXECUTION")"

log "Retrieving all series from Sonarr..."
SHOWS_JSON=$(curl -s -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/series")

# Verify if the API call was successful
if [ -z "$SHOWS_JSON" ]; then
  log "ERROR: Unable to retrieve series data from Sonarr. Exiting..."
  exit 1
fi

log "Identifying shows in $DOCKER_PATH_TV_NEW..."
SHOWS_IN_SOURCE=$(echo "$SHOWS_JSON" | jq -c '.[] | select(.path | contains("'"$DOCKER_PATH_TV_NEW"'"))')

if [ -z "$SHOWS_IN_SOURCE" ]; then
  log "No shows found in $DOCKER_PATH_TV_NEW. Exiting..."
  exit 0
fi

log "Found $(echo "$SHOWS_IN_SOURCE" | jq -s 'length') shows in $DOCKER_PATH_TV_NEW."
log "Processing shows in $DOCKER_PATH_TV_NEW..."

PROCESSED_COUNT=0
MOVED_COUNT=0
ERROR_COUNT=0

while read -r SHOW; do
  SHOW_ID=$(echo "$SHOW" | jq '.id')
  SHOW_TITLE=$(echo "$SHOW" | jq -r '.title')
  DOCKER_SHOW_PATH=$(echo "$SHOW" | jq -r '.path')

  # Translate Docker path to host path for file operations
  SHOW_PATH=$(translate_docker_to_host "$DOCKER_SHOW_PATH")
  NEW_PATH=$(translate_docker_to_host "$DOCKER_PATH_TV/$(basename "$DOCKER_SHOW_PATH")")

  log "Checking \"$SHOW_TITLE\" for complete aired seasons..."
  COMPLETE_SEASONS=$(echo "$SHOW" | jq '[.seasons[] | select(.monitored == true and .statistics.nextAiring == null and .statistics.episodeFileCount == .statistics.episodeCount)]')
  COMPLETE_COUNT=$(echo "$COMPLETE_SEASONS" | jq 'length')

  PROCESSED_COUNT=$((PROCESSED_COUNT + 1))

  if [ "$COMPLETE_COUNT" -gt 0 ]; then
    log "===> \"$SHOW_TITLE\" has $COMPLETE_COUNT complete aired seasons!"

    # Check if destination already exists to prevent overwriting
    if [ -d "$NEW_PATH" ]; then
      log "WARNING: Destination \"$NEW_PATH\" already exists. Skipping to prevent overwriting."
      ERROR_COUNT=$((ERROR_COUNT + 1))
      continue
    fi

    # Check if the source directory exists
    if [ -d "$SHOW_PATH" ]; then
      log "Source directory \"$SHOW_PATH\" exists. Proceeding to move..."
      if [ "$DRY_RUN" = true ]; then
        # Dry run: simulate the move and update
        log "[DRY RUN] Would move \"$SHOW_TITLE\" from \"$SHOW_PATH\" to \"$NEW_PATH\"."
        log "[DRY RUN] Would update Sonarr with new path: \"$DOCKER_PATH_TV/$(basename "$DOCKER_SHOW_PATH")\"."
      else
        # Ensure the destination parent directory exists
        mkdir -p "$(dirname "$NEW_PATH")" 2>/dev/null
        
        # Actual execution: move and update
        log "Moving \"$SHOW_TITLE\" to \"$NEW_PATH\"..."
        mv "$SHOW_PATH" "$NEW_PATH"
        if [ $? -eq 0 ]; then
          log "Successfully moved \"$SHOW_TITLE\" to \"$NEW_PATH\"."
          MOVED_COUNT=$((MOVED_COUNT + 1))

          # Retrieve additional required fields for the show
          TVDB_ID=$(echo "$SHOW" | jq '.tvdbId')
          TMDB_ID=$(echo "$SHOW" | jq '.tmdbId')
          IMDB_ID=$(echo "$SHOW" | jq -r '.imdbId')
          QUALITY_PROFILE_ID=$(echo "$SHOW" | jq '.qualityProfileId')
          MONITORED=$(echo "$SHOW" | jq '.monitored')
          TITLE=$(echo "$SHOW" | jq -r '.title')
          SEASON_FOLDER=$(echo "$SHOW" | jq '.seasonFolder')

          if [ -z "$QUALITY_PROFILE_ID" ] || [ "$QUALITY_PROFILE_ID" -le 0 ]; then
            log "ERROR: Invalid QualityProfileId for \"$SHOW_TITLE\". Skipping Sonarr update..."
            ERROR_COUNT=$((ERROR_COUNT + 1))
          else
            # Translate host path back to Docker path for Sonarr update
            DOCKER_NEW_PATH=$(translate_host_to_docker "$NEW_PATH")
            log "Updating Sonarr for \"$SHOW_TITLE\"..."
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
              log "Sonarr successfully updated \"$SHOW_TITLE\" with the new path."
              # Invoke "Refresh and Scan" with a delay
              refresh_and_scan_series "$SHOW_ID"
            else
              log "WARNING: Failed to update Sonarr for \"$SHOW_TITLE\". Response: $RESPONSE"
              ERROR_COUNT=$((ERROR_COUNT + 1))
            fi
          fi
        else
          log "ERROR: Failed to move \"$SHOW_TITLE\" to \"$NEW_PATH\"."
          ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
      fi
    else
      log "ERROR: Source directory \"$SHOW_PATH\" does not exist. Skipping \"$SHOW_TITLE\"."
      ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
  else
    log "===> \"$SHOW_TITLE\" has no complete aired seasons. Skipping..."
  fi
done <<< "$(echo "$SHOWS_IN_SOURCE" | jq -c '.')"

log "=========== Summary ==========="
log "Processed: $PROCESSED_COUNT shows"
log "Moved: $MOVED_COUNT shows"
log "Errors: $ERROR_COUNT shows"
log "Script completed."
