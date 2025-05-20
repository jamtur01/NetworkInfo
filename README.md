# NetworkInfo

A macOS menubar app that displays network information including:

- Public IP and location
- Local IP address
- WiFi SSID and DNS configuration
- VPN connections
- DNS service status
- ISP information

## Building

1. Navigate to the project directory:
```sh
cd /Users/james/src/NetworkInfo
```

2. Build the application bundle:
```sh
./build-app.sh
```

3. Run the app:
```sh
open NetworkInfo.app
```

This will create a proper macOS application bundle with all the necessary components.

## Configuration

The app reads DNS configuration from `~/Library/Application Support/NetworkInfo/dns.conf`. The format is:

```
SSID = DNS_Server1 DNS_Server2 ...
```

For example:
```
HomeWiFi = 1.1.1.1 8.8.8.8
WorkWiFi = 192.168.1.1 192.168.1.2
```

When connecting to a WiFi network, the app will automatically apply the corresponding DNS settings if configured.

## Features

- Automatically applies DNS settings based on WiFi SSID
- Shows status of DNS resolver services (unbound and kresd)
- Tests DNS resolution against multiple domains
- Monitors VPN connections
- Shows geolocation information for your public IP
- Copy any displayed information to clipboard with a click

## Running at Login

To make NetworkInfo start automatically when you log in:

1. Go to System Preferences > Users & Groups
2. Select your user account
3. Click on "Login Items"
4. Click the "+" button
5. Navigate to and select NetworkInfo.app
6. Click "Add"
# NetworkInfo
