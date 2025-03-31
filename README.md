Ths script pulls a list of all shows configured in Sonarr's "New" folder path, identifies any shows that have completed seasons, and moves them to the primary TV folder. The "new" and primary TV folders are configurable. 

Use case - you use Emby/Plex and you want to certain TV shows to only show up in your (main) list of shows after the current season is completed. This is useful for me with serialized shows, where each episode builds on the prior episodes, but it isn't necessarily useful for 30 minute comedies where each episode stands alone just fine. In Sonarr, you assign all currently airing (serialized) shows in a separate ("new") folder. When a season of that show is completed, the script moves it to the main folder and updates Sonarr. Note that when a season ends, you will have to adjust the sonarr settings to move it back to the "new" folder for the next season.  

All of these settings need to be changed:

      API_KEY="ADD-YOUR-API-KEY-HERE"
      SONARR_URL="http://192.168.1.10:8989"
      DOCKER_PATH_TV_NEW="/data/TV-new"  # This is the new-TV path inside the docker container
      DOCKER_PATH_TV="/data/tv" # This is the primary TV path inside the docker container
      HOST_PATH_TV_NEW="/mnt/user/media/TV-new"  # This is the new-TV path on the host (host path is needed to move shows to other folders)
      HOST_PATH_TV="/mnt/user/media/tv"  # This is the primary TV path on the host

Be sure to do a dry run first. I'm not responsible for whatever you do with this script. It may break everything. It may break nothing, and actually work. 

      DRY_RUN=true  

Disclaimer - I'm not a coder and this script was made mostly by Copilot. There are still bugs and quirks with this code. Some of the code may be unecessary as it was made by a monkey (me) with AI.

Credit goes to [plexguide](https://github.com/plexguide/Sonarr-Hunter/) for the base code I used to get this started, which I just fed into Copilot and Claude. I told the AI what to change and it seems to be working. 

Other ideas for possible future additions:
- When a season is completed, the show is not marked as ended, and the last episode has been deleted, move the series folder on the disk and the series in Sonarr to the TV-new folder
- Find a way to unmonitor completed prior seasons, which is tripping up the current code

