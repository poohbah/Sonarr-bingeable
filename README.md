Ths script pulls a list of all shows configured in Sonarr's "New" folder path, identifies any shows that have completed seasons, and moves them to the primary TV folder. The "new" and primary TV folders are configurable. 

Use case - you use Emby/Plex and you want certain TV shows to only show up in your (main) list of shows after the current season is completed. This is useful for me with serialized shows, where each episode builds on the prior episodes, but it isn't necessarily useful for 30 minute comedies where each episode stands alone just fine. In Sonarr, you assign all currently airing (serialized) shows in a separate ("new") folder. When a season of that show is completed, the script moves it to the main folder and updates Sonarr. Note that when a season ends and you watch everything, you will have to adjust the sonarr settings to move it back to the "new" folder for the next season.  

I added a second script to unmonitor prior seasons. For some reason Sonarr unmonitors the EPISODE when you delete it, but it leaves the SEASON marked as monitored. This tends to trip up the "bingeable" code, so I created a second script to sort through all showsin a given path, check to see if they are empty and the last episode aired in the past, and if so change the season(s) to unmonitored. Someday Maybe I'll succeed on combining them.  

All of these settings need to be changed:

      API_KEY="ADD-YOUR-API-KEY-HERE"
      SONARR_URL="http://192.168.1.10:8989"
      DOCKER_PATH_TV_NEW="/data/TV-new"  # This is the new-TV path inside the docker container
      DOCKER_PATH_TV="/data/tv" # This is the primary TV path inside the docker container
      HOST_PATH_TV_NEW="/mnt/user/media/TV-new"  # This is the new-TV path on the host (host path is needed to move shows to other folders)
      HOST_PATH_TV="/mnt/user/media/tv"  # This is the primary TV path on the host

Be sure to do a dry run first. I'm not responsible for whatever you do with this script. It may break everything. It may break nothing, and actually work. 

      DRY_RUN=true  

Disclaimer - I'm not a coder and this script was made mostly by Copilot. There are still bugs and quirks with this code. Some of the code may be unecessary as it was made by a monkey (me) with AI. If you want to modifiy this code to do somethign different, just feed this script into Claude, Gemini, ChatGPT, or Copilot, and tell it what you want to change. It may take some time feeding back any errors, adjusting the code, and repeating. 

Credit goes to [plexguide](https://github.com/plexguide/Sonarr-Hunter/) for the base code I used to get this started, which I just fed into Copilot, and Claude, and Gemini. I told the AI what to change and it seems to be working. 

Other ideas for possible future additions:
- When a season is completed, the show is not marked as ended, and the last episode has been deleted, move the series folder on the disk and the series in Sonarr from the TV folder to the TV-new folder
- Find a way to combine both scripts. Unmonitor completed prior seasons keeps tripping up the main script.

