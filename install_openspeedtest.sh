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
STARTUP_SCRIPT="/etc/rc.d/S81nginx_speedtest"
KILL_SCRIPT="/etc/rc.d/K81nginx_speedtest"
STARTUP_CONF_DIR="/etc/nginx/conf.d"

echo "$SPLASH"

ask_confirmation() {
  echo "$1 (y/n)"
  read -r ans
  [ "$ans" = "y" ] || exit 0
}

diagnose_nginx() {
  echo "Running diagnostics..."
  if netstat -tuln | grep ":3000 " > /dev/null; then
    echo -e "✅ NGINX is running and listening on port 3000"
  else
    echo -e "❌ NGINX is not running or not bound to port 3000"
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
        echo -e "⚠️\x20\x20No matching nginx process found."
    fi

    # Prompt to delete $INSTALL_DIR completely
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "🗂\x20\x20Directory $INSTALL_DIR exists. Do you want to remove it entirely? [y/N]"
        read -r remove_dir
        if [[ "$remove_dir" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            echo -e "✅ $INSTALL_DIR removed."
        fi
    fi

    # Remove nginx config
    if [ -f "$CONFIG_PATH" ]; then
        echo -e "🗑\x20\x20Removing nginx config: $CONFIG_PATH"
        rm -f "$CONFIG_PATH" && echo -e "✅ Removed nginx config." || echo -e "❌ Failed to remove config."
    else
        echo -e "ℹ️\x20\x20No nginx config found at $CONFIG_PATH"
    fi

    # Remove startup/kill scripts
    if [ -f "$STARTUP_SCRIPT" ]; then
        echo -e "🗑\x20\x20Removing startup script: $STARTUP_SCRIPT"
        rm -f "$STARTUP_SCRIPT"
    fi
    if [ -f "$KILL_SCRIPT" ]; then
        echo -e "🗑\x20\x20Removing kill script: $KILL_SCRIPT"
        rm -f "$KILL_SCRIPT"
    fi

    # Restart default GL.iNet nginx if not running
    echo -e "🔁\x20\x20Checking default NGINX (GL.iNet GUI / LuCI)..."
    if pgrep -x nginx >/dev/null; then
        echo -e "✅ Default NGINX is already running."
    else
        echo -e "⚠️\x20\x20Default NGINX is not running. Attempting restart..."

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
        listen 3000;
        listen [::]:3000;
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
    ask_confirmation "Directory already exists. Overwrite?"
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

  cat <<EOF > "$KILL_SCRIPT"
#!/bin/sh
echo "Killing OpenSpeedTest NGINX Server..."
killall nginx
EOF

  chmod +x "$STARTUP_SCRIPT" "$KILL_SCRIPT"

  echo "Starting NGINX..."
  /usr/sbin/nginx -c "$CONFIG_PATH"

  echo -e "✅ Installation complete. Open http://<router-ip>:3000 in your browser."
  exit 0
}

show_menu
