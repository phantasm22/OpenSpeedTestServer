# OpenSpeedTest Installer for NGINX on GL.iNet Routers

```
   _____ _          _ _   _      _   
  / ____| |        (_) \\ | |    | |  
 | |  __| |  ______ _|  \\| | ___| |_ 
 | | |_ | | |______| | . \` |/ _ \\ __|
 | |__| | |____    | | |\\  |  __/ |_ 
 \\_____|______|   |_|_| \\_|\\___|\\__|

         OpenSpeedTest for GL-iNet

```
> 📡 Easily deploy OpenSpeedTest with NGINX on OpenWRT-based routers (GL.iNet, etc.)

---

## Features

- 📦 Installs and configures [NGINX](https://nginx.org/) to run [OpenSpeedTest](https://openspeedtest.com/)
- 🔧 Custom NGINX configuration that avoids conflicts with the GL.iNet web UI
- 📁 Installs to `/www2`, with automatic detection of available storage space
- 🔗 Supports symlinking to external drives (e.g. SD cards or USB) if internal space is insufficient
- 🔁 Creates startup and kill scripts for boot-time operation
- 🧹 Clean uninstall that removes configs, startup scripts, and any symlinked storage
- 🩺 Includes diagnostics to verify NGINX is running and reachable
- 🧑‍💻 Interactive CLI with confirmations and safe prompts
- 🆓 Licensed under GPLv3
- 🧪 Tested on GL-BE3600, GL-MT3000, and GL-MT1300 (with SD card) routers

---

## 🚀 Installation

1. SSH into your router:

```
ssh root@192.168.8.1
```

2.	Download the script:

```
wget -O install_openspeedtest.sh https://raw.githubusercontent.com/phantasm22/OpenSpeedTestServer/main/install_openspeedtest.sh && chmod +x install_openspeedtest.sh
```

3. Run the script:

```
./install_openspeedtest.sh
```

4.	Follow the interactive menu to install, diagnose, or uninstall.
---
🌐 Access the Speed Test

After installation, open:
```
http://<router-ip>:8888
```

Example:

```
http://192.168.8.1:8888
```
---

🔍 Script Options

When running the script, choose from:
1. Install OpenSpeedTest – Installs NGINX, configures it, downloads OpenSpeedTest
2. Run diagnostics – Checks if NGINX is running and listening on the correct port
3. Uninstall everything – Removes all config, scripts, and files
4. Exit – Ends the script
---
🧹 Uninstallation

Re-run the script and choose option 3: Uninstall everything.

Or manually:

```
killall nginx
rm -f /etc/nginx/nginx_openspeedtest.conf
/etc/init.d/nginx_speedtest disable
rm -f /etc/init.d/nginx_speedtest
rm -rf /www2/Speed-Test-main
```
---
🧑 Author

phantasm22

Contributions, suggestions, and PRs welcome!

---

📜 License

This project is licensed under the GNU GPL v3.0 License - see the [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html) file for details.
