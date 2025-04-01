#!/bin/bash
# Script to check all shows in a given sonarr path, and unmonitor old seasons with no episodes

# --- Configuration ---
API_KEY="YOUR_API_KEY_HERE" # Your Sonarr API Key
SONARR_URL="http://192.168.1.10:8989"     # Your Sonarr URL (NO trailing slash)
DOCKER_PATH_TV_NEW="/data/TV-new"         # The specific root folder path *inside Docker* to check

# --- Safety Switch ---
# Set to true to only print actions without modifying Sonarr.
# Set to false to actually unmonitor seasons.
DRY_RUN=false

# --- Script Logic ---

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' command not found. Please install jq."
    exit 1
fi

# Get current date in seconds since epoch for comparison
current_epoch=$(date +%s)

echo "--- Sonarr Season Unmonitor Script ---"
echo "Sonarr URL: $SONARR_URL"
echo "Target Path: $DOCKER_PATH_TV_NEW"
echo "Dry Run: $DRY_RUN"
echo "------------------------------------"

# 1. Get all series from Sonarr
echo "Fetching all series from Sonarr..."
series_json=$(curl -s -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/series")

# Check if curl succeeded
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to fetch series from Sonarr API."
    exit 1
fi

# Check if response is valid JSON (basic check)
if ! echo "$series_json" | jq empty > /dev/null 2>&1; then
   echo "Error: Invalid JSON received from Sonarr API when fetching series."
   # echo "Response: $series_json" # Uncomment for debugging
   exit 1
fi

echo "Processing series..."

# 2. Filter series by the specified root folder path and iterate
echo "$series_json" | jq -c --arg path "$DOCKER_PATH_TV_NEW" '.[] | select(.rootFolderPath == $path)' | while IFS= read -r series_data; do
    series_id=$(echo "$series_data" | jq -r '.id')
    series_title=$(echo "$series_data" | jq -r '.title')
    series_path=$(echo "$series_data" | jq -r '.rootFolderPath')

    echo "Checking Series: '$series_title' (ID: $series_id, Path: $series_path)"

    # 3. Iterate through seasons of the current series
    echo "$series_data" | jq -c '.seasons[] | select(.monitored == true)' | while IFS= read -r season_data; do
        season_number=$(echo "$season_data" | jq -r '.seasonNumber')
        # Skip Specials season (Season 0) if desired - uncomment the next line
        # [[ "$season_number" -eq 0 ]] && continue

        echo "  -> Checking Monitored Season: $season_number"

        # Get statistics for the season to check if it has episodes aired
        episode_count=$(echo "$season_data" | jq -r '.statistics.episodeCount // 0')
        total_episode_count=$(echo "$season_data" | jq -r '.statistics.totalEpisodeCount // 0')

        # If season has no episodes defined in Sonarr, skip it
        if [[ "$total_episode_count" -eq 0 ]]; then
            echo "      - Skipping Season $season_number: No total episodes listed in Sonarr statistics."
            continue
        fi

        # 4. Fetch episode details for this specific season to find the last episode's air date
        echo "      - Fetching episode details for Season $season_number..."
        episodes_json=$(curl -s -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/episode?seriesId=$series_id&seasonNumber=$season_number")

        if [[ $? -ne 0 ]]; then
            echo "      - Error: Failed to fetch episodes for Series ID $series_id, Season $season_number."
            continue
        fi

         # Check if response is valid JSON (basic check)
        if ! echo "$episodes_json" | jq empty > /dev/null 2>&1; then
           echo "      - Error: Invalid JSON received from Sonarr API when fetching episodes for Series ID $series_id, Season $season_number."
           # echo "Response: $episodes_json" # Uncomment for debugging
           continue
        fi

        # Find the last episode by sorting and check its air date
        # We select episodes with an airDateUtc, sort by episode number descending, take the first (last), and get its airDateUtc.
        last_episode_air_date_utc=$(echo "$episodes_json" | jq -r '[.[] | select(.airDateUtc != null)] | sort_by(.episodeNumber) | .[-1].airDateUtc // empty')

        if [[ -z "$last_episode_air_date_utc" || "$last_episode_air_date_utc" == "null" ]]; then
            echo "      - Skipping Season $season_number: Could not determine air date of the last episode."
            continue
        fi

        # Convert air date to epoch seconds. Handle potential date parsing errors.
        last_episode_epoch=$(date -d "$last_episode_air_date_utc" +%s 2>/dev/null)

        if [[ -z "$last_episode_epoch" ]]; then
             echo "      - Skipping Season $season_number: Could not parse air date '$last_episode_air_date_utc'."
             continue
        fi

        # 5. Compare last episode air date with current date
        if [[ "$last_episode_epoch" -lt "$current_epoch" ]]; then
            echo "      - Action: Season $season_number's last episode aired on $last_episode_air_date_utc (in the past)."

            if [[ "$DRY_RUN" == "true" ]]; then
                echo "      - DRY RUN: Would unmonitor Season $season_number for '$series_title'."
            else
                echo "      - EXECUTING: Unmonitoring Season $season_number for '$series_title'..."

                # Need to fetch the *entire* series object again to modify it correctly for the PUT request
                current_series_data_for_put=$(curl -s -H "X-Api-Key: $API_KEY" "$SONARR_URL/api/v3/series/$series_id")
                 if [[ $? -ne 0 ]] || ! echo "$current_series_data_for_put" | jq empty > /dev/null 2>&1; then
                    echo "      - Error: Failed to fetch current series data (ID: $series_id) before update. Skipping modification."
                    continue
                fi

                # Modify the specific season's monitored status using jq
                # We pass the season number as an argument to jq for safety
                modified_series_data=$(echo "$current_series_data_for_put" | jq --argjson sNum "$season_number" '
                    .seasons = ([.seasons[] | if .seasonNumber == $sNum then .monitored = false else . end])
                ')

                # Send the PUT request with the modified series data
                put_response=$(curl -s -X PUT -H "Content-Type: application/json" -H "X-Api-Key: $API_KEY" --data "$modified_series_data" "$SONARR_URL/api/v3/series/$series_id")
                # Optional: Check response status code if Sonarr API provides it or validate JSON response

                 if [[ $? -ne 0 ]]; then
                    echo "      - Error: Failed to send update request to Sonarr for Series ID $series_id, Season $season_number."
                 elif echo "$put_response" | jq -e '.id' > /dev/null 2>&1 ; then # Basic check if response looks like a series object
                     echo "      - SUCCESS: Successfully unmonitored Season $season_number for '$series_title'."
                 else
                    echo "      - WARNING: Update command sent, but response validation failed. Check Sonarr UI. Response: $put_response"
                 fi
            fi
        else
            echo "      - Skipping Season $season_number: Last episode airs in the future or today ($last_episode_air_date_utc)."
        fi
    done # End season loop
done # End series loop

echo "------------------------------------"
echo "Script finished."
if [[ "$DRY_RUN" == "true" ]]; then
    echo "NOTE: Dry run was enabled. No changes were made in Sonarr."
fi
echo "------------------------------------"

exit 0
