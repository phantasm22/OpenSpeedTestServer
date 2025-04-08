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
- 🔧 Custom NGINX configuration that avoids common conflicts
- 📁 Extracts OpenSpeedTest into `/www2`
- 🔁 Creates startup and kill scripts for boot-time operation
- 🩺 Includes diagnostic and uninstall options
- 🧑‍💻 Interactive CLI prompts
- 🆓 Licensed under GPLv3

---

## 🚀 Installation

1. SSH into your router:

```
ssh root@192.168.8.1
```

2.	Download the script:

```
wget https://raw.githubusercontent.com/phantasm22/openspeedtest-glinet/main/install_openspeedtest.sh
chmod +x install_openspeedtest.sh
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
http://<router-ip>:3000
```

Example:

```
http://192.168.8.1:3000
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
rm -f /etc/rc.d/S81nginx_speedtest
rm -f /etc/rc.d/K81nginx_speedtest
rm -rf /www2/Speed-Test-main
```
---
🧑 Author

phantasm22

Contributions, suggestions, and PRs welcome!

---

📜 License

This project is licensed under the GNU GPL v3.0 License - see the [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html) file for details.
