Ths script pulls a list of all shows configured in Sonarr's "New" folder path, identifies any shows that have completed seasons, and moves them to the primary TV folder.

All of these settings need to be changed:

      API_KEY="ADD-YOUR-API-KEY-HERE"
      SONARR_URL="http://192.168.1.10:8989"
      DOCKER_PATH_TV_NEW="/data/TV-new"  # This is the path new-TV path inside the docker container
      DOCKER_PATH_TV="/data/tv" # This is the primary TV path inside the docker container
      HOST_PATH_TV_NEW="/mnt/user/media/TV-new"  # This is the path on the host (host path is needed to move shows to other folders)
      HOST_PATH_TV="/mnt/user/media/tv"  # This is the path on the host

Be sure to do a dry run first. I'm not responsible for whatever you do with this script. It may break everything. It may break nothing, and actually work. 

      DRY_RUN=true  

Disclaimer - I'm not a coder and this script was made mostly by Copilot.

Credit to plexguide/Sonarr-Hunter for the base code I used to get this started, which I just fed into Copilot and told it to change things. 
