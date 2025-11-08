#!/bin/sh
# OpenSpeedTest Installer for NGINX on GL.iNet Routers
# Author: phantasm22
# License: GPL-3.0
# Version: 2025-11-08
#
# This script installs or uninstalls the OpenSpeedTest server using NGINX on OpenWRT-based routers.
# It supports:
# - Installing NGINX and OpenSpeedTest
# - Creating a custom config and startup script
# - Running diagnostics to check if NGINX is active
# - Uninstalling everything cleanly
# - Automatically checks and updates itself




# -----------------------------
# Color & Emoji
# -----------------------------
RESET="\033[0m"
CYAN="\033[36m"
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"

SPLASH="
   _____ _          _ _   _      _   
  / ____| |        (_) \\ | |    | |  
 | |  __| |  ______ _|  \\| | ___| |_ 
 | | |_ | | |______| | . \` |/ _ \\ __|
 | |__| | |____    | | |\\  |  __/ |_ 
  \\_____|______|   |_|_| \\_|\\___|\\__|

         OpenSpeedTest for GL-iNet
"

# -----------------------------
# Global Variables
# -----------------------------
INSTALL_DIR="/www2"
CONFIG_PATH="/etc/nginx/nginx_openspeedtest.conf"
STARTUP_SCRIPT="/etc/init.d/nginx_speedtest"
REQUIRED_SPACE_MB=64
PORT=8888
PID_FILE="/var/run/nginx_OpenSpeedTest.pid"
BLA_BOX="┤ ┴ ├ ┬"  # spinner frames
opkg_updated=0
SCRIPT_URL="https://raw.githubusercontent.com/phantasm22/OpenSpeedTestServer/refs/heads/main/install_openspeedtest.sh"
TMP_NEW_SCRIPT="/tmp/install_openspeedtest_new.sh"
SCRIPT_PATH="$0"
[ "${SCRIPT_PATH#*/}" != "$SCRIPT_PATH" ] || SCRIPT_PATH="$(pwd)/$SCRIPT_PATH"

# -----------------------------                                                                                         
# Cleanup any previous updates                                                                                                      
# ----------------------------- 
case "$0" in
    *.new)
        ORIGINAL="${0%.new}"
        printf "🧹 Applying update...\n"
        mv -f "$0" "$ORIGINAL" && chmod +x "$ORIGINAL"
        printf "✅ Update applied. Restarting main script...\n"
        exec "$ORIGINAL" "$@"
        ;;
esac

# -----------------------------
# Utility Functions
# -----------------------------
spinner() {
    pid=$1
    i=0
    task=$2
    while kill -0 "$pid" 2>/dev/null; do
        frame=$(printf "%s" "$BLA_BOX" | cut -d' ' -f$((i % 4 + 1)))
        printf "\r⏳  %s... %-20s" "$task" "$frame"
        if command -v usleep >/dev/null 2>&1; then
            usleep 200000
        else
            sleep 1
        fi
        i=$((i+1))
    done
    printf "\r✅  %s... Done!%-20s\n" "$task" " "
}

press_any_key() {
    printf "Press any key to continue..."
    read -r _ </dev/tty
}

# -----------------------------
# Disk Space Check & External Drive
# -----------------------------
check_space() {
    SPACE_CHECK_PATH="$INSTALL_DIR"
    [ ! -e "$INSTALL_DIR" ] && SPACE_CHECK_PATH="/"

    AVAILABLE_SPACE_MB=$(df -m "$SPACE_CHECK_PATH" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$AVAILABLE_SPACE_MB" ] || [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
        printf "❌ Not enough free space at ${CYAN}%s${RESET}. Required: ${CYAN}%dMB${RESET}, Available: ${CYAN}%sMB${RESET}  \n" "$SPACE_CHECK_PATH" "$REQUIRED_SPACE_MB" "${AVAILABLE_SPACE_MB:-0}"
        printf "\n🔍 Searching mounted external drives for sufficient space...\n"

        for mountpoint in $(awk '$2 ~ /^\/mnt\// {print $2}' /proc/mounts); do
            ext_space=$(df -m "$mountpoint" | awk 'NR==2 {print $4}')
            if [ "$ext_space" -ge "$REQUIRED_SPACE_MB" ]; then
                printf "💾 Found external drive with enough space: ${CYAN}%s${RESET} (${CYAN}%dMB${RESET} available)\n" "$mountpoint" "$ext_space"
                printf "Use it for installation by creating a symlink at ${CYAN}%s${RESET}? [y/N]: " "$INSTALL_DIR"
                read -r use_external
                if [ "$use_external" = "y" ] || [ "$use_external" = "Y" ]; then
                    INSTALL_DIR="$mountpoint/openspeedtest"
                    mkdir -p "$INSTALL_DIR"
                    ln -sf "$INSTALL_DIR" /www2
                    printf "✅ Symlink created: /www2 -> ${CYAN}%s${RESET}\n" "$INSTALL_DIR"
                    break
                fi
            fi
        done

        NEW_SPACE_MB=$(df -m "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
        if [ -z "$NEW_SPACE_MB" ] || [ "$NEW_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
            printf "❌ Still not enough space to install. Aborting.\n"
            exit 1
        else
            printf "✅ Sufficient space found at new location: ${CYAN}%dMB${RESET} available  \n" "$NEW_SPACE_MB"
        fi
    else
        printf "✅ Sufficient space for installation: ${CYAN}%dMB${RESET} available  \n" "$AVAILABLE_SPACE_MB"
    fi
}

# -----------------------------                                                                                         
# Self-update function                                                                                     
# -----------------------------       
check_self_update() {
    printf "\n🔍 Checking for script updates...\n"

    LOCAL_VERSION="$(grep -m1 '^# Version:' "$SCRIPT_PATH" | awk '{print $3}' | tr -d '\r')"
    [ -z "$LOCAL_VERSION" ] && LOCAL_VERSION="0000-00-00"

    if ! wget -q -O "$TMP_NEW_SCRIPT" "$SCRIPT_URL"; then
        printf "⚠️  Unable to check for updates (network or GitHub issue).\n"
        return 1
    fi

    REMOTE_VERSION="$(grep -m1 '^# Version:' "$TMP_NEW_SCRIPT" | awk '{print $3}' | tr -d '\r')"
    [ -z "$REMOTE_VERSION" ] && REMOTE_VERSION="0000-00-00"

    printf "📦 Current version: %s\n" "$LOCAL_VERSION"
    printf "🌐 Latest version:  %s\n" "$REMOTE_VERSION"

    if [ "$REMOTE_VERSION" \> "$LOCAL_VERSION" ]; then
        printf "\nA new version is available. Update now? [y/N]: "
        read -r ans
        case "$ans" in
            y|Y)
                printf "⬆️  Updating...\n"
                cp "$TMP_NEW_SCRIPT" "$SCRIPT_PATH.new" && chmod +x "$SCRIPT_PATH.new"
		printf "✅ Upgrade complete. Restarting script...\n"
		exec "$SCRIPT_PATH.new" "$@"
                ;;
            *)
                printf "⏭️  Skipping update. Continuing with current version.\n"
                ;;
        esac
    else
        printf "✅ You are already running the latest version.\n"
    fi

    rm -f "$TMP_NEW_SCRIPT" >/dev/null 2>&1
    printf "\n"
}

# -----------------------------
# Persist Prompt
# -----------------------------
prompt_persist() {
    if [ -n "$AVAILABLE_SPACE_MB" ] && [ "$AVAILABLE_SPACE_MB" -ge "$REQUIRED_SPACE_MB" ] && [ ! -L "$INSTALL_DIR" ]; then
        printf "\n💾 Do you want OpenSpeedTest to persist through firmware updates? [y/N]: "
        read -r persist
        if [ "$persist" = "y" ] || [ "$persist" = "Y" ]; then
            # Core paths
            grep -Fxq "$INSTALL_DIR" /etc/sysupgrade.conf 2>/dev/null || echo "$INSTALL_DIR" >> /etc/sysupgrade.conf
            grep -Fxq "$STARTUP_SCRIPT" /etc/sysupgrade.conf 2>/dev/null || echo "$STARTUP_SCRIPT" >> /etc/sysupgrade.conf
            grep -Fxq "$CONFIG_PATH" /etc/sysupgrade.conf 2>/dev/null || echo "$CONFIG_PATH" >> /etc/sysupgrade.conf

            # Also persist any rc.d symlinks for startup/shutdown (S* and K*)
            if [ -n "$STARTUP_SCRIPT" ]; then
                SERVICE_NAME=$(basename "$STARTUP_SCRIPT")
                for LINK in $(find /etc/rc.d/ -type l -name "[SK]*${SERVICE_NAME}" 2>/dev/null); do
                    grep -Fxq "$LINK" /etc/sysupgrade.conf 2>/dev/null || echo "$LINK" >> /etc/sysupgrade.conf
                done
            fi

            printf "✅ Persistence enabled.\n"
            return
        fi
    fi
    remove_persistence
    printf "✅ Persistence disabled.\n"
}

# -----------------------------
# Remove Persistence
# -----------------------------
remove_persistence() {
    sed -i "\|$INSTALL_DIR|d" /etc/sysupgrade.conf 2>/dev/null
    sed -i "\|$STARTUP_SCRIPT|d" /etc/sysupgrade.conf 2>/dev/null
    sed -i "\|$CONFIG_PATH|d" /etc/sysupgrade.conf 2>/dev/null

    if [ -n "$STARTUP_SCRIPT" ]; then
        SERVICE_NAME=$(basename "$STARTUP_SCRIPT")
        sed -i "\|/etc/rc.d/[SK].*${SERVICE_NAME}|d" /etc/sysupgrade.conf 2>/dev/null
    fi
}

# -----------------------------
# Download Source
# -----------------------------
choose_download_source() {
    printf "\n🌐 Choose download source:\n"
    printf "1️⃣  Official repository\n"
    printf "2️⃣  GL.iNet mirror\n"
    printf "Choose [1-2]: "
    read -r src
    printf "\n"
    case $src in
        1) DOWNLOAD_URL="https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip" ;;
        2) DOWNLOAD_URL="https://fw.gl-inet.com/tools/script/Speed-Test-main.zip" ;;
        *) printf "❌ Invalid option. Defaulting to official repository.\n"; DOWNLOAD_URL="https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip" ;;
    esac
}

# -----------------------------
# Detect Internal IP
# -----------------------------
detect_internal_ip() {
    INTERNAL_IP="$(uci get network.lan.ipaddr 2>/dev/null | tr -d '\r\n')"
    [ -z "$INTERNAL_IP" ] && INTERNAL_IP="<router_ip>"
}

# -----------------------------
# Install Dependencies
# -----------------------------
install_dependencies() {
    DEPENDENCIES="curl:curl nginx:nginx-ssl timeout:coreutils-timeout unzip:unzip wget:wget"

    for item in $DEPENDENCIES; do
        CMD=${item%%:*}   # command name
        PKG=${item##*:}   # package name

        # Uppercase using BusyBox-compatible tr
        CMD_UP=$(printf "%s" "$CMD" | tr 'a-z' 'A-Z')
        PKG_UP=$(printf "%s" "$PKG" | tr 'a-z' 'A-Z')

        if ! command -v "$CMD" >/dev/null 2>&1; then
            printf "${CYAN}📦 %s${RESET} not found. Installing ${CYAN}%s${RESET}...\n" "$CMD_UP" "$PKG_UP"
            if [ $opkg_updated -eq 0 ]; then
                opkg update >/dev/null 2>&1
                opkg_updated=1
            fi

            if opkg install "$PKG" >/dev/null 2>&1; then
                printf "${CYAN}✅ %s${RESET} installed successfully.\n" "$PKG_UP"
            else
                printf "${RED}❌ Failed to install %s. Check your internet or opkg configuration.${RESET}\n" "$PKG_UP"
                exit 1
            fi
        else
            printf "${CYAN}✅ %s${RESET} already installed.\n" "$CMD_UP"
        fi
    done
}

# -----------------------------
# Install OpenSpeedTest
# -----------------------------
install_openspeedtest() {
    install_dependencies
    check_space
    choose_download_source

    # Stop running OpenSpeedTest if PID exists
    if [ -s "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            printf "⚠️  Existing OpenSpeedTest detected. Stopping...\n"
            kill "$OLD_PID" && printf "✅ Stopped.\n" || printf "❌ Failed to stop.\n"
            rm -f "$PID_FILE"
        fi
    fi

    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR" || exit 1
    [ -d Speed-Test-main ] && rm -rf Speed-Test-main

    # Download with spinner
    wget -O main.zip "$DOWNLOAD_URL" >/dev/null 2>&1 &
    wget_pid=$!
    spinner "$wget_pid" "Downloading OpenSpeedTest"
    wait "$wget_pid"

    # Unzip with spinner
    unzip -o main.zip >/dev/null &
    unzip_pid=$!
    spinner "$unzip_pid" "Unzipping"
    wait "$unzip_pid"
    rm main.zip

    # Create NGINX config
    cat <<EOF > "$CONFIG_PATH"
worker_processes  auto;
worker_rlimit_nofile 100000;
user nobody nogroup;

events {
    worker_connections 2048;
    multi_accept on;
}

error_log  /var/log/nginx/error.log notice;
pid        $PID_FILE;

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        server_name _ localhost;
        listen $PORT;
        root $INSTALL_DIR/Speed-Test-main;
        index index.html;

        client_max_body_size 10000M;
        error_page 405 =200 \$uri;
        access_log off;
        log_not_found off;
        error_log /dev/null;
        server_tokens off;
        tcp_nodelay on;
        tcp_nopush on;
        sendfile on;
        resolver 127.0.0.1;

        location / {
            add_header 'Access-Control-Allow-Origin' "*" always;
            add_header 'Access-Control-Allow-Headers' 'Accept,Authorization,Cache-Control,Content-Type,DNT,If-Modified-Since,Keep-Alive,Origin,User-Agent,X-Mx-ReqToken,X-Requested-With' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
            add_header Cache-Control 'no-store, no-cache, max-age=0, no-transform';
            if (\$request_method = OPTIONS) {
                add_header Access-Control-Allow-Credentials "true";
                return 204;
            }
        }

        location ~* ^.+\\.(?:css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff|woff2|svg)\$ {
            access_log off;
            expires 365d;
            add_header Cache-Control public;
            add_header Vary Accept-Encoding;
        }
    }
}
EOF

    # Create startup script
    cat <<EOF > "$STARTUP_SCRIPT"
#!/bin/sh /etc/rc.common
START=81
STOP=15
start() {
    if netstat -tuln | grep -q ":$PORT"; then
        printf "⚠️  Port $PORT already in use. Cannot start OpenSpeedTest NGINX.\n"
        return 1
    fi
    printf "Starting OpenSpeedTest NGINX Server..."
    /usr/sbin/nginx -c $CONFIG_PATH
    printf " ✅\n"
}
stop() {
    if [ -s $PID_FILE ]; then
        kill \$(cat $PID_FILE) 2>/dev/null
        rm -f $PID_FILE
    fi
}
EOF
    chmod +x "$STARTUP_SCRIPT"
    "$STARTUP_SCRIPT" enable

    # Start NGINX
    "$STARTUP_SCRIPT" start

    # Detect internal IP
    detect_internal_ip
    printf "\n✅ Installation complete. Open ${CYAN}http://%s:%d  \n${RESET}" "$INTERNAL_IP" "$PORT"
    prompt_persist
    press_any_key
}

# -----------------------------
# Diagnostics
# -----------------------------
diagnose_nginx() {
    printf "\n🔍 Running OpenSpeedTest diagnostics...\n\n"

    # Detect internal IP
    detect_internal_ip
    
    # Check if NGINX process is running
    if [ -s "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        printf "✅ OpenSpeedTest NGINX process is running (PID: %s)\n" "$(cat "$PID_FILE")"
    else
        printf "❌ OpenSpeedTest NGINX process is NOT running\n"
    fi

    # Check if port is listening
    if netstat -tuln | grep ":$PORT " >/dev/null; then
        printf "✅ Port %d is open and listening on %s\n" "$PORT" "$INTERNAL_IP"
        printf "🌐 You can access OpenSpeedTest at: ${CYAN}http://%s:%d\n${RESET}" "$INTERNAL_IP" "$PORT"
    else
        printf "❌ Port %d is not listening on %s\n" "$PORT" "$INTERNAL_IP"
    fi

    press_any_key
}

# -----------------------------
# Uninstall OpenSpeedTest
# -----------------------------
uninstall_all() {
    printf "\n🧹 This will remove OpenSpeedTest, the startup script, and /www2 contents.\n"
    printf "Are you sure? [y/N]: "
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        printf "❌ Uninstall cancelled.\n"
        press_any_key
        return
    fi

    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2>/dev/null
        rm -f "$PID_FILE"
    fi

    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
    fi

    [ -L "/www2" ] && rm -f "/www2"

    [ -f "$CONFIG_PATH" ] && rm -f "$CONFIG_PATH"

    if [ -f "$STARTUP_SCRIPT" ]; then
        "$STARTUP_SCRIPT" disable 2>/dev/null
        rm -f "$STARTUP_SCRIPT"
    fi

    remove_persistence
    printf "✅ OpenSpeedTest uninstall complete.\n"
    press_any_key
}

# -----------------------------                                                                                         
# Check for updates                                                                                                             
# -----------------------------  
command -v clear >/dev/null 2>&1 && clear                                                                                                               
printf "%b\n" "$SPLASH"
check_self_update "$@"  

# -----------------------------
# Main Menu
# -----------------------------
show_menu() {
    clear
    printf "%b\n" "$SPLASH"
    printf "%b\n" "${CYAN}Please select an option:${RESET}\n"
    printf "1️⃣  Install OpenSpeedTest\n"
    printf "2️⃣  Run diagnostics\n"
    printf "3️⃣  Uninstall everything\n"
    printf "4️⃣  Check for update\n"
    printf "5️⃣  Exit\n"
    printf "Choose [1-5]: "
    read opt
    printf "\n"
    case $opt in
        1) install_openspeedtest ;;
        2) diagnose_nginx ;;
        3) uninstall_all ;;
        4) check_self_update "$@" && press_any_key;;
	5) exit 0 ;;
        *) printf "%b\n" "${RED}❌ Invalid option.  ${RESET}"; sleep 1; show_menu ;;
    esac
    show_menu
}

# -----------------------------
# Start
# -----------------------------
show_menu
