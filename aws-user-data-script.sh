#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

AWS_REGION="us-east-1"
CS2_DIR="/home/steam/cs2"
SDK64_DIR="$HOME/.steam/sdk64/"
USER="steam"

# Accept the SteamCMD license agreement automatically
echo steam steam/question select "I AGREE" | sudo debconf-set-selections && echo steam steam/license note '' | sudo debconf-set-selections

sudo add-apt-repository -y multiverse
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt update
sudo apt-get install -y unzip
sudo apt-get install -y jq
sudo apt install -y lib32z1 lib32gcc-s1 lib32stdc++6 steamcmd
sudo snap install aws-cli --classic

STEAM_USER_PW_JSON=$(aws secretsmanager get-secret-value --secret-id 'ec2-steam-user-pw' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_USER_PW=$(echo "$STEAM_USER_PW_JSON" | jq -r '."ec2-user-steam-pw"')
STEAM_GAME_SERVER_TOKEN_JSON=$(aws secretsmanager get-secret-value --secret-id 'steam-game-server-token' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_GAME_SERVER_TOKEN=$(echo "$STEAM_GAME_SERVER_TOKEN_JSON" | jq -r '."steam-game-server-token"')

# Check if the user already exists
if id "$USER" &>/dev/null; then
  echo "User $USER already exists."
else
  # Create a user account named steam to run SteamCMD safely, isolating it from the rest of the operating system.
  # As the root user, create the steam user:
  sudo useradd -m "$USER"
  echo "User $USER created."
  echo "steam:$STEAM_USER_PW" | sudo chpasswd
  # Add the 'steam' user to the 'sudo' group to grant sudo privileges
  sudo usermod -aG sudo steam
  # Configure 'steam' to use sudo without a password
  echo "steam ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/steam
fi

sudo -u steam -s
cd /home/steam || return

# Check if the cs2 directory exists
if [ ! -d "$CS2_DIR" ]; then
  # Directory does not exist, so create it
  mkdir -p "$CS2_DIR"
  echo "Directory $CS2_DIR created."
else
  echo "Directory $CS2_DIR already exists."
fi

if [ ! -d "$SDK64_DIR" ]; then
  # Directory does not exist, so create it
  mkdir -p "$SDK64_DIR"
  echo "Directory $SDK64_DIR created."
else
  echo "Directory $SDK64_DIR already exists."
fi

# Run SteamCMD
/usr/games/steamcmd
force_install_dir /home/steam/cs2
login anonymous
app_update 730 validate
quit

# cd /home/steam/cs2 || return

# Download the latest MetaMod build
#wget https://mms.alliedmods.net/mmsdrop/2.0/mmsource-2.0.0-git1313-linux.tar.gz

# Extract MetaMod to the CS2 directory
#tar -xzvf mmsource-2.0.0-git1313-linux.tar.gz -C /home/steam/cs2/game/csgo

# Remove the downloaded MetaMod tar.gz file
#rm mmsource-1.11.0-git1140-linux.tar.gz

# Edit the gameinfo.gi file to add MetaMod to the SearchPaths section
#GAMEINFO_FILE="/home/steam/cs2/game/csgo/gameinfo.gi"
#if grep -q "Game    csgo/addons/metamod" "$GAMEINFO_FILE"; then
#    echo "MetaMod already added to SearchPaths."
#else
#    sed -i '/SearchPaths/r'<(echo '            Game    csgo/addons/metamod') "$GAMEINFO_FILE"
#    echo "MetaMod added to SearchPaths."
# fi

# Download the latest MatchZy build
# wget https://github.com/shobhit-pathak/MatchZy/releases/download/0.7.13/MatchZy-0.7.13-with-cssharp-linux.zip

# Extract MatchZy to the CS2 directory
# unzip MatchZy-0.7.13-with-cssharp-linux.zip -d /home/steam/cs2/game/csgo

# Remove the downloaded MatchZy .zip file
# rm MatchZy-0.7.13-with-cssharp-linux.zip

# Symlink the steamclient.so to expected path
ln -sf /home/steam/.local/share/Steam/steamcmd/linux64/steamclient.so /home/steam/.steam/sdk64/

# Start the CS2 server
/home/steam/cs2/game/bin/linuxsteamrt64/cs2 -dedicated +map de_dust2 +game_mode 1 +game_type 0 +sv_setsteamaccount "$STEAM_GAME_SERVER_TOKEN" -maxplayers 10

EOF
