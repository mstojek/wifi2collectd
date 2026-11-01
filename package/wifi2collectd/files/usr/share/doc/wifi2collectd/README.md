# WiFi Radio Monitoring Plugin for Collectd (`wifi2collectd`)

A Lua-based collectd plugin for monitoring WiFi radio utilization and client statistics on OpenWrt routers.

## Features

- **WiFi Channel Utilization:** Track channel busy time, transmit time, and BSS receive time
- **Per-Client Metrics:** Monitor signal strength, bitrates, bytes transferred, packets, retries and errors
- **Hostname Resolution:** Automatically resolves MAC addresses to hostnames using various methods
- **Low Overhead:** Uses native OpenWrt tools without additional dependencies

## Requirements / Dependencies

This plugin assumes that you have LuCI and `luci-app-statistics` installed.
Required libraries (automatically installed with the package) are `collectd`, `collectd-mod-lua`, `iw`, and `luci-app-statistics`.

## Installation Instructions

### Option 1: Automatic Installation (Recommended)
Pre-built architecture-independent (`noarch`) packages are available in the [Releases](https://github.com/mstojek/wifi2collectd/releases) section.

#### For OpenWrt 24.10 and earlier (.ipk)
1. Download the latest `.ipk` file to your router.
2. Install it using `opkg`:
   ```bash
   opkg update
   opkg install wifi2collectd_*.ipk
   ```

#### For OpenWrt 25.12 and later (.apk)
1. Download the latest `.apk` file to your router.
2. Install it using `apk`:
   ```bash
   apk add --allow-untrusted wifi2collectd_*.apk
   ```

The package will automatically configure LuCI statistics and restart all necessary services upon installation.

---

### Option 2: Compiling from Source (Using OpenWrt Feed)
If you prefer to build the package yourself using the OpenWrt SDK or Buildroot:

1. Add the feed to your `feeds.conf` or `feeds.conf.default`:
   ```text
   src-git wifi2collectd https://github.com/mstojek/wifi2collectd.git
   ```

2. Update and install the feed:
   ```bash
   ./scripts/feeds update wifi2collectd
   ./scripts/feeds install -p wifi2collectd
   ```

3. Select the package in `make menuconfig`:
   `Utilities` -> `wifi2collectd`

4. Compile the package:
   ```bash
   make package/wifi2collectd/compile V=s
   ```

---

### Option 3: Manual Installation
1. Make sure that you have the required dependencies installed:
   ```bash
   opkg update
   opkg install collectd collectd-mod-lua iw luci-app-statistics
   ```

2. Copy the Lua plugin files to your router:
   ```bash
   scp package/wifi2collectd/files/usr/share/collectd-mod-lua/wifi_utilization_to_collectd.lua root@your-router:/usr/share/collectd-mod-lua/
   scp package/wifi2collectd/files/usr/share/collectd-mod-lua/wifi_clients_to_collectd.lua root@your-router:/usr/share/collectd-mod-lua/
   ```

3. Copy the collectd configuration snippets:
   ```bash
   scp package/wifi2collectd/files/etc/collectd/conf.d/wifi_utilization.conf root@your-router:/etc/collectd/conf.d/
   scp package/wifi2collectd/files/etc/collectd/conf.d/wifi_clients.conf root@your-router:/etc/collectd/conf.d/
   ```

4. Copy the LuCI RRD definition:
   ```bash
   scp package/wifi2collectd/files/www/luci-static/resources/statistics/rrdtool/definitions/wifi_radio.js root@your-router:/www/luci-static/resources/statistics/rrdtool/definitions/
   ```

5. Configure LuCI statistics to include the custom config directory and restart services:
   ```bash
   uci set luci_statistics.collectd.Include='/etc/collectd/conf.d'
   uci commit luci_statistics
   rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
   /etc/init.d/luci_statistics restart
   /etc/init.d/collectd restart
   /etc/init.d/rpcd restart
   ```

## Collected Metrics

### WiFi Utilization Metrics
- **percent-busy**: Percentage of time the channel is detected as busy
- **percent-transmit**: Percentage of time the radio is transmitting
- **percent-bss_receive**: Percentage of time the BSS is receiving

### WiFi Client Metrics
- **bitrate-rx**: Receive bitrate of the client in bits/sec
- **bitrate-tx**: Transmit bitrate of the client in bits/sec
- **signal_power**: Signal strength in dBm
- **if_octets**: Bytes received and transmitted
- **if_packets**: Packets received and transmitted
- **if_rx_dropped**: Number of dropped packets on receive
- **if_collisions**: Number of transmission retries
- **if_tx_dropped**: Number of failed transmissions

## MAC to Hostname Resolution

The plugin tries to resolve MAC addresses to hostnames in the following order:
1. DHCP leases file
2. `/etc/ethers` file (supports both IPs and hostnames)
3. ARP table via `ip neigh show` 
4. DNS reverse lookup

## Configuration Options

At the top of each script (`/usr/share/collectd-mod-lua/wifi_*.lua`), you can modify:
- `debug = true/false`: Enable/disable debug logging
- `host = ''`: Set the hostname for collectd values (default: use system hostname)
- `plugin_name = "wifi_radio"`: Change the plugin name

## Troubleshooting

- Run the scripts manually to check for errors:
```bash
lua -e "collectd=nil" /usr/share/collectd-mod-lua/wifi_utilization_to_collectd.lua
lua -e "collectd=nil" /usr/share/collectd-mod-lua/wifi_clients_to_collectd.lua
```

- Check syslog for collectd errors:
```bash
logread | grep collectd
```

## Dashboard Examples

This plugin produces metrics that are ideal for monitoring:
- WiFi channel utilization (busy/transmit percentages)
- Connected client count
- Per-client connection quality
- Traffic patterns and signal strength

## License

GPL-3.0
