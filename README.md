Ths script pulls a list of all shows in the "New" folder, identifies any shows that have completed seasons, and moves them to the primary TV folder.

All of these settings need to be changed:

API_KEY="ADD-YOUR-API-KEY-HERE"
SONARR_URL="http://192.168.1.10:8989"
DOCKER_PATH_TV_NEW="/data/TV-new"  # This is the path inside the docker container
DOCKER_PATH_TV="/data/tv" # This is the path inside the docker container
HOST_PATH_TV_NEW="/mnt/user/media/TV-new"  # This is the path on the host (needed to move shows to other folders)
HOST_PATH_TV="/mnt/user/media/tv"  # This is the path on the host

Be sure to do a dry run first. I'm not responsible for whatevery you do with this script. It may break everything. 

DRY_RUN=true  

