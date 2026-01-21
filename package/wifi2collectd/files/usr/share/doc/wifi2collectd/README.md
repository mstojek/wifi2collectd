# WiFi Radio Monitoring Plugin for Collectd

A Lua-based collectd plugin for monitoring WiFi radio utilization and client statistics on OpenWrt/LEDE routers.

## Features

- **WiFi Channel Utilization:** Track channel busy time, transmit time, and BSS receive time
- **Per-Client Metrics:** Monitor signal strength, bitrates, bytes transferred, packets, retries and errors
- **Hostname Resolution:** Automatically resolves MAC addresses to hostnames using various methods
- **Low Overhead:** Uses native OpenWrt tools without additional dependencies

## Requirements

- OpenWrt/LEDE with collectd installed
- collectd with Lua plugin enabled
- `iw` utility installed (standard on OpenWrt)

## Installation

1. Install collectd with Lua plugin:
```bash
opkg update
opkg install collectd collectd-mod-lua
```

2. Copy the plugin files to your router:
```bash
scp wifi_utilization_to_collectd.lua wifi_clients_to_collectd.lua root@your-router:/etc/collectd/
```

3. Add the following to your `/etc/collectd.conf`:
```
LoadPlugin lua
<Plugin lua>
    BasePath "/etc/collectd/"
    Script "wifi_utilization_to_collectd.lua"
    Script "wifi_clients_to_collectd.lua"
</Plugin>
```

4. Restart collectd:
```bash
/etc/init.d/collectd restart
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

At the top of each script, you can modify:
- `debug = true/false`: Enable/disable debug logging
- `host = ''`: Set the hostname for collectd values (default: use system hostname)
- `plugin_name = "wifi_radio"`: Change the plugin name

## Troubleshooting

- Run the scripts manually to check for errors:
```bash
lua -e "collectd=nil" /etc/collectd/wifi_utilization_to_collectd.lua
lua -e "collectd=nil" /etc/collectd/wifi_clients_to_collectd.lua
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

Use with Grafana or other visualization tools for a complete WiFi monitoring solution. Details TBD

## License

GPL-3.0