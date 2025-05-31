#!/bin/sh
# OpenSpeedTest Installer for NGINX on GL.iNet Routers
# Author: phantasm22
# License: GPL-3.0
# Version: 2025-04-08
#
# This script installs or uninstalls the OpenSpeedTest server using NGINX on OpenWRT-based routers.
# It supports:
# - Installing NGINX and OpenSpeedTest
# - Creating a custom config and startup script
# - Running diagnostics to check if NGINX is active
# - Uninstalling everything cleanly

SPLASH="
   _____ _          _ _   _      _   
  / ____| |        (_) \\ | |    | |  
 | |  __| |  ______ _|  \\| | ___| |_ 
 | | |_ | | |______| | . \` |/ _ \\ __|
 | |__| | |____    | | |\\  |  __/ |_ 
  \\_____|______|   |_|_| \\_|\\___|\\__|

         OpenSpeedTest for GL-iNet
"

INSTALL_DIR="/www2"
CONFIG_PATH="/etc/nginx/nginx_openspeedtest.conf"
STARTUP_SCRIPT="/etc/init.d/nginx_speedtest"
STARTUP_CONF_DIR="/etc/nginx/conf.d"
REQUIRED_SPACE_MB=64
PORT=8888

clear
echo "$SPLASH"

diagnose_nginx() {
  echo "Running diagnostics..."
  if netstat -tuln | grep ":$PORT " > /dev/null; then
    echo -e "✅ NGINX is running and listening on port $PORT"
  else
    echo -e "❌ NGINX is not running or not bound to port $PORT"
  fi
  exit 0
}

uninstall_all() {
    echo -e "🧹 Uninstalling OpenSpeedTest Server..."

    # Kill only the OpenSpeedTest nginx process
    echo -e "🔍 Stopping OpenSpeedTest nginx instance..."
    nginx_pid=$(ps | grep "nginx.*$CONFIG_PATH" | grep -v grep | awk '{print $1}')
    
    if [ -n "$nginx_pid" ]; then
        kill "$nginx_pid" && echo -e "✅ OpenSpeedTest nginx process stopped." || echo -e "❌ Failed to stop nginx process."
    else
        echo -e "⚠️\x20 No matching nginx process found."
    fi

    # Prompt to delete $INSTALL_DIR completely
    if [ -d "$INSTALL_DIR" ]; then
        printf "🗂\x20 Directory $INSTALL_DIR exists. Do you want to remove it entirely? [y/N] "
        read -r remove_dir
        if [[ "$remove_dir" =~ ^[Yy]$ ]]; then
            rm -rf "$(readlink -f "$INSTALL_DIR")" "$INSTALL_DIR"
            echo -e "✅ $INSTALL_DIR removed."
        fi
    fi

    # Remove nginx config
    if [ -f "$CONFIG_PATH" ]; then
        echo -e "🗑\x20 Removing nginx config: $CONFIG_PATH"
        rm -f "$CONFIG_PATH" && echo -e "✅ Removed nginx config." || echo -e "❌ Failed to remove config."
    else
        echo -e "ℹ️\x20 No nginx config found at $CONFIG_PATH"
    fi

    # Remove startup script
    if [ -f "$STARTUP_SCRIPT" ]; then
        echo -e "🗑\x20 Removing startup script: $STARTUP_SCRIPT"
        "$STARTUP_SCRIPT" disable
        rm -f "$STARTUP_SCRIPT"
    fi
  

    # Restart default GL.iNet nginx if not running
    echo -e "🔁 Checking default NGINX (GL.iNet GUI / LuCI)..."
    if pgrep -f nginx >/dev/null; then
        echo -e "✅ Default NGINX is already running."
    else
        echo -e "⚠️\x20 Default NGINX is not running. Attempting restart..."

        if [ -x /etc/init.d/nginx ]; then
            /etc/init.d/nginx restart && \
                echo -e "✅ Default NGINX restarted via /etc/init.d." || \
                echo -e "❌ Failed to restart default NGINX using init.d script."
        elif [ -f /etc/nginx/nginx.conf ]; then
            nginx -c /etc/nginx/nginx.conf && \
                echo -e "✅ Default NGINX restarted via config." || \
                echo -e "❌ Failed to restart default NGINX. Check logs or manually restart."
        else
            echo -e "❌ Cannot locate init script or nginx.conf to restart default NGINX."
        fi
    fi

    echo -e "✅ OpenSpeedTest uninstall complete." 
}

show_menu() {
  echo "Choose an option:"
  echo "1. Install OpenSpeedTest"
  echo "2. Run diagnostics"
  echo "3. Uninstall everything"
  echo "4. Exit"
  read -r opt

  case $opt in
    1) install_openspeedtest ;;
    2) diagnose_nginx ;;
    3) uninstall_all ;;
    4) exit 0 ;;
    *) echo "Invalid option" && show_menu ;;
  esac
}

install_openspeedtest() {
  # Decide where to check space
  if [ -e "$INSTALL_DIR" ]; then
      SPACE_CHECK_PATH="$INSTALL_DIR"
  else
      SPACE_CHECK_PATH="/"
  fi

  # Check available space (in MB)
  AVAILABLE_SPACE_MB=$(df -m "$SPACE_CHECK_PATH" 2>/dev/null | awk 'NR==2 {print $4}')

  if [ -z "$AVAILABLE_SPACE_MB" ] || [ "$AVAILABLE_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
    echo -e "❌ Not enough free space at $SPACE_CHECK_PATH. Required: ${REQUIRED_SPACE_MB}MB, Available: ${AVAILABLE_SPACE_MB:-0}MB"
    
    echo "🔍 Searching mounted external drives for sufficient space..."

    for mountpoint in $(awk '$2 ~ /^\/mnt\// {print $2}' /proc/mounts); do
      ext_space=$(df -m "$mountpoint" | awk 'NR==2 {print $4}')
      if [ "$ext_space" -ge "$REQUIRED_SPACE_MB" ]; then
        echo "💾 Found external drive with enough space: $mountpoint (${ext_space}MB available)"
        printf "Would you like to use it for installation by creating a symlink at $INSTALL_DIR? [y/N] "
        read -r use_external
        if [[ "$use_external" =~ ^[Yy]$ ]]; then
          INSTALL_DIR="$mountpoint/openspeedtest"
          mkdir -p "$INSTALL_DIR"
          ln -sf "$INSTALL_DIR" /www2
          echo "✅ Symlink created: /www2 -> $INSTALL_DIR"
          break
        fi
      fi
    done

    # Recheck if INSTALL_DIR now has enough space
    NEW_SPACE_MB=$(df -m "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$NEW_SPACE_MB" ] || [ "$NEW_SPACE_MB" -lt "$REQUIRED_SPACE_MB" ]; then
      echo -e "❌ Still not enough space to install. Aborting."
      exit 1
    else
      echo -e "✅ Sufficient space found at new location: ${NEW_SPACE_MB}MB available."
    fi
  else
    echo -e "✅ Sufficient space for installation: ${AVAILABLE_SPACE_MB}MB available."
  fi
  
  echo "Checking if NGINX is installed..."
  if ! command -v nginx >/dev/null; then
    echo "NGINX not found. Installing..."
    opkg update
    opkg install nginx
  fi

  echo "Creating OpenSpeedTest NGINX config..."
  cat <<EOF > "$CONFIG_PATH"
worker_processes  auto;
worker_rlimit_nofile 100000;
user nobody nogroup;

events {
    worker_connections 2048;
    multi_accept on;
}

error_log  /var/log/nginx/error.log notice;
pid        /tmp/nginx.pid;

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        server_name _ localhost;
        listen $PORT;
        listen [::]:$PORT;
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

  echo "Setting up OpenSpeedTest files..."
  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR" || exit 1

  if [ -d Speed-Test-main ]; then
    printf "Directory already exists. Overwrite? [y/N] "
    read -r dir_exists
        if [[ "$dir_exists" =~ ^[Yy]$ ]]; then
            rm -rf Speed-Test-main
        fi
    rm -rf Speed-Test-main
  fi

  echo "Downloading OpenSpeedTest..."
  wget -qO main.zip https://github.com/openspeedtest/Speed-Test/archive/refs/heads/main.zip
  unzip -o main.zip >/dev/null
  rm main.zip

  echo "Creating startup scripts..."
  cat <<EOF > "$STARTUP_SCRIPT"
#!/bin/sh /etc/rc.common
START=81
STOP=15
start() {
  echo "Starting OpenSpeedTest NGINX Server..."
  /usr/sbin/nginx -c $CONFIG_PATH
}
stop() {
  echo "Stopping OpenSpeedTest NGINX Server..."
  killall nginx
}
EOF


  chmod +x "$STARTUP_SCRIPT" 
  "$STARTUP_SCRIPT" enable

  echo "Starting NGINX..."
  "$STARTUP_SCRIPT" start

  echo -e "✅ Installation complete. Open http://<router-ip>:$PORT in your browser."
  exit 0
}

show_menu
