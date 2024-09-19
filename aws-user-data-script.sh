#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

USER="steam"
AWS_REGION="ap-south-1"
CS2_DIR="/home/steam/cs2"
CSGO_GAME_DIR="$CS2_DIR/game/csgo"
SDK64_DIR="/home/steam/.steam/sdk64/"
GITHUB_MATCHZY_SERVER_CONFIG_URL="https://raw.githubusercontent.com/xe1os/cs2_server_setup/main/matchzy-config.cfg"
SERVER_UPDATE_SCRIPT_FILENAME="cs2-server-update-script.sh"
GITHUB_CS2_SERVER_UPDATE_URL="https://raw.githubusercontent.com/xe1os/cs2_server_setup/main/$SERVER_UPDATE_SCRIPT_FILENAME"
MATCHZY_DIR="$CSGO_GAME_DIR/cfg/MatchZy"
MATCHZY_ADMINS_FILE_PATH="$MATCHZY_DIR/admins.json"
MATCHZY_WHITELIST_FILE_PATH="$MATCHZY_DIR/whitelist.cfg"
MATCHZY_CONFIG_FILE_PATH="$MATCHZY_DIR/config.cfg"
MATCHZY_KNIFE_CONFIG_FILE_PATH="$MATCHZY_DIR/knife.cfg"
MATCH_TEMP_SERVER_FILE_PATH="/tmp/matchzy-server.cfg"
XE1OS_STEAM_ID="76561198043162355"
GAMEINFO_FILE_PATH="$CSGO_GAME_DIR/gameinfo.gi"
MATCHZY_VERSION="0.8.6"
METAMOD_FILE_NAME="mmsource-2.0.0-git1313-linux.tar.gz"
METAMOD_URL_PATH_VERSION="2.0"

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
sudo snap start amazon-ssm-agent

STEAM_USER_PW_JSON=$(aws secretsmanager get-secret-value --secret-id 'ec2-steam-user-pw' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_USER_PW=$(echo "$STEAM_USER_PW_JSON" | jq -r '."ec2-user-steam-pw"')
STEAM_GAME_SERVER_TOKEN_JSON=$(aws secretsmanager get-secret-value --secret-id 'steam-game-server-token' --region $AWS_REGION --query 'SecretString' --output text)
STEAM_GAME_SERVER_TOKEN=$(echo "$STEAM_GAME_SERVER_TOKEN_JSON" | jq -r '."steam-game-server-token"')
RCON_PASSWORD_JSON=$(aws secretsmanager get-secret-value --secret-id 'rcon-password' --region $AWS_REGION --query 'SecretString' --output text)
RCON_PASSWORD=$(echo "$RCON_PASSWORD_JSON" | jq -r '."rcon-password"')

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

sudo -i -u steam bash <<EOF
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
  /usr/games/steamcmd +force_install_dir /home/steam/cs2 +login anonymous +app_update 730 validate +quit

  cd /home/steam

  wget -O "$SERVER_UPDATE_SCRIPT_FILENAME" "$GITHUB_CS2_SERVER_UPDATE_URL"
  chmod +x "$SERVER_UPDATE_SCRIPT_FILENAME"

  cd "$CS2_DIR"

  # Download the latest MetaMod build
  wget "https://mms.alliedmods.net/mmsdrop/$METAMOD_URL_PATH_VERSION/$METAMOD_FILE_NAME"

  # Extract MetaMod to the CS2 directory
  tar -xzvf "$METAMOD_FILE_NAME" -C "$CSGO_GAME_DIR" 

  # Remove the downloaded MetaMod tar.gz file
  rm "$METAMOD_FILE_NAME"

  # Edit the gameinfo.gi file to add MetaMod to the SearchPaths section
  if grep -q "csgo/addons/metamod" "$GAMEINFO_FILE_PATH"; then
    echo "MetaMod already added to SearchPaths."
  else
    line_number=$(grep -n "csgo_lv" "$GAMEINFO_FILE_PATH" | cut -d: -f1)
    sed -i "${line_number}a\\\t\t\tGame\tcsgo/addons/metamod" "$GAMEINFO_FILE_PATH"
    echo "MetaMod added to SearchPaths."
  fi

  # Download the latest MatchZy build
  wget "https://github.com/shobhit-pathak/MatchZy/releases/download/$MATCHZY_VERSION/MatchZy-$MATCHZY_VERSION-with-cssharp-linux.zip"

  # Extract MatchZy to the CS2 directory
  unzip -o "MatchZy-$MATCHZY_VERSION-with-cssharp-linux.zip" -d "$CSGO_GAME_DIR"

  # Remove the downloaded MatchZy .zip file
  rm "MatchZy-$MATCHZY_VERSION-with-cssharp-linux.zip"

  # Symlink the steamclient.so to expected path
  ln -sf /home/steam/.local/share/Steam/steamcmd/linux64/steamclient.so "$SDK64_DIR"

  # Replace MatchZy admins entry with proper admin
  sed -i "s/\"76561198154367261\": \".*\"/\"$XE1OS_STEAM_ID\": \"\"/" "$MATCHZY_ADMINS_FILE_PATH"

  # Cange the knife round time to 69 seconds (nice)
  sed -i "s/^mp_roundtime .*/mp_roundtime 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
  sed -i "s/^mp_roundtime .*/mp_roundtime_defuse 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"
  sed -i "s/^mp_roundtime .*/mp_roundtime_hostage 1.15/" "$MATCHZY_KNIFE_CONFIG_FILE_PATH"

  # Only whitelist admin for now until a match would Start
  echo "$XE1OS_STEAM_ID" > "$MATCHZY_WHITELIST_FILE_PATH"

  # Replace MatchZy server config with custom config from GamingHerd GitHub
  wget -O "$MATCH_TEMP_SERVER_FILE_PATH" "$GITHUB_MATCHZY_SERVER_CONFIG_URL"
  mv "$MATCH_TEMP_SERVER_FILE_PATH" "$MATCHZY_CONFIG_FILE_PATH"

  echo "rcon_password $RCON_PASSWORD" >> "$CSGO_GAME_DIR/cfg/server.cfg"
  echo "tv_enable 1" >> "$CSGO_GAME_DIR/cfg/server.cfg"
  echo "tv_advertise_watchable 1" >> "$CSGO_GAME_DIR/cfg/server.cfg"

  # Start the CS2 server
  /home/steam/cs2/game/bin/linuxsteamrt64/cs2 -dedicated -console -usercon -nobots +map de_dust2 +game_mode 1 +game_type 0 +sv_setsteamaccount "$STEAM_GAME_SERVER_TOKEN" -maxplayers 11
EOF
