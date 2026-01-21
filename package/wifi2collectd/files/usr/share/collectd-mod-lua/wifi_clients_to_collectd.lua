-- collectd lua plugin script for monitoring WiFi client speeds (TX and RX) on OpenWrt
-- Outputs values in collectd plugin format (values in b/s)
-- VERSION USING CUSTOM `exec` FUNCTION (io.popen) - WORKAROUND for missing collectd.utils.exec

-- Configuration --
local debug = false -- Set to true to enable debug logging
local host = ''
local plugin_name = "wifi_radio"
--local interval = read_config("Interval") or 30 -- Default interval 30 seconds (can be overridden in collectd.conf)

-- Global variables (if needed, although not strictly necessary here)
-- No global variables needed for this script, state is managed within read function

-- Function to get safe interface name (not really used in this version but kept for consistency if needed later)
local function get_safe_iface_name(iface)
    return string.gsub(iface, "[^a-zA-Z0-9_]", "_")
end

local function isempty(s)
  return s == nil or s == ''
end

-- Custom `exec` function using io.popen (WORKAROUND)
local function exec(command)
    local pp = io.popen(command)
    if not pp then -- Check if io.popen was successful
        collectd.log_error("exec: io.popen failed for command: " .. command)
        return nil -- Return nil to signal command execution error
    end
    local data = pp:read("*a")
    pp:close()
    if not data then -- Check if data reading was successful (or if anything was read)
        -- This is not an error if the command simply has no output, but worth logging a warning
        -- collectd.log_error("exec: No output from command: " .. command) -- You can enable this warning if you want
        return "" -- Return empty string if no output (or read error) - you can also return nil if you prefer
    end
    return data -- Return the read data if everything went OK
end

-- Custom `exec_lines` function using custom `exec` and splitting into lines (WORKAROUND)
local function exec_lines(command)
    local output = exec(command)
    if output then
        local lines = {}
        for line in string.gmatch(output, "[^\r\n]+") do
            if table.insert then
                table.insert(lines, line)
            else
                lines[#lines+1] = line
            end
        end
        return lines
    else
        return nil
    end
end

-- Function to multiply by million (Lua is already floating point, so direct multiplication is sufficient)
local function multiply_by_million(number_str)
    local number = tonumber(number_str)
    if number then
        return number * 1000000
    else
        return nil -- Handle case where input is not a valid number
    end
end

-- Function to lookup hostname based on IP
local function lookup_hostname_for_ip(ip)
    if not ip then return nil end
    
    local nslookup_command = "nslookup " .. ip
    local nslookup_output_lines = exec_lines(nslookup_command)
    
    if nslookup_output_lines then
        for _, line in ipairs(nslookup_output_lines) do
            local name_match = line:match('name =%s+([a-zA-Z0-9.-]+)')
            if name_match then
                -- Extract only the hostname without domain
                local hostname = name_match:match("^([^.]+)")
                return hostname or name_match
            end
        end
    end
    
    return nil
end

-- Function to find hostname or IP based on MAC address
local function find_hostname_or_ip_for_mac(mac)
    -- 1. Check DHCP leases
    local lease_file_cmd = "uci get dhcp.@dnsmasq[0].leasefile"
    local lease_file_raw = exec(lease_file_cmd)
    if lease_file_raw then
        local lease_file = lease_file_raw:gsub('[%c]', '')
        local command = "cat " .. lease_file
        local leases_data = exec(command)
        
        if leases_data then
            for line in leases_data:gmatch("[^\r\n]+") do
                local mac_in_line = line:match("%S+%s+(%S+)")
                if mac_in_line and mac_in_line:lower() == mac:lower() then
                    local _, _, lease_ip, lease_hostname = line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
                    if lease_hostname and lease_hostname ~= "*" then
                        return lease_hostname -- Found hostname
                    elseif lease_ip then
                        return lease_ip -- Found IP
                    end
                end
            end
        end
    end
    
    -- 2. Check /etc/ethers
    local ethers_file = io.open("/etc/ethers", "r")
    if ethers_file then
        for line in ethers_file:lines() do
            if not line:match("^%s*#") and line:match("%S") then
                local eth_mac, eth_value = line:match("(%S+)%s+(%S+)")
                if eth_mac and eth_mac:lower() == mac:lower() then
                    ethers_file:close()
                    -- Check if it's an IP address or hostname
                    if eth_value:match("^%d+%.%d+%.%d+%.%d+$") then
                        -- It's an IP - try to find hostname
                        local hostname = lookup_hostname_for_ip(eth_value)
                        return hostname or eth_value
                    else
                        -- It's a hostname - extract only hostname without domain
                        local hostname_only = string.match(eth_value, "^([^.]+)")
                        if hostname_only then
                            return hostname_only -- Return only hostname without domain
                        else
                            return eth_value -- If extraction failed, return the full value
                        end
                    end
                end
            end
        end
        ethers_file:close()
    end
    
    -- 3. Use ip neigh show
    local cmd_output = exec_lines("/sbin/ip neigh show")
    if cmd_output then
        for _, line in ipairs(cmd_output) do
            if line:lower():match(mac:lower()) then
                local ip = line:match("^(%d+%.%d+%.%d+%.%d+)")
                if ip then
                    -- We have IP, try to find hostname
                    local hostname = lookup_hostname_for_ip(ip)
                    return hostname or ip
                end
            end
        end
    end
    
    return nil -- Neither hostname nor IP found
end

-- Function to dispatch WiFi client metrics
local function dispatch_client_metrics(host, plugin_name, iface, host_resolved, client_metrics, debug)
    -- Send bitrate metric (receiving)
    if client_metrics.rx_rate then
        local rx_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "bitrate",
            type_instance = "rx_" .. host_resolved,
            values = {client_metrics.rx_rate}
        }
        collectd.dispatch_values(rx_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH rx_val: host: " ..  rx_val.host .. 
                " plugin: " .. rx_val.plugin .. 
                " plugin_instance: " .. rx_val.plugin_instance .. 
                " type: " .. rx_val.type .. 
                " type_instance: " .. rx_val.type_instance .. 
                " values: " .. rx_val.values[1])
        end
    end

    -- Send bitrate metric (transmitting)
    if client_metrics.tx_rate then
        local tx_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "bitrate",
            type_instance = "tx_" .. host_resolved,
            values = {client_metrics.tx_rate}
        }
        collectd.dispatch_values(tx_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH tx_val: host: " ..  tx_val.host .. 
                " plugin: " .. tx_val.plugin .. 
                " plugin_instance: " .. tx_val.plugin_instance .. 
                " type: " .. tx_val.type .. 
                " type_instance: " .. tx_val.type_instance .. 
                " values: " .. tx_val.values[1])
        end
    end

    -- Send signal strength metric
    if client_metrics.signal_avg then
        local signal_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "signal_power",
            type_instance = host_resolved,
            values = {client_metrics.signal_avg}
        }
        collectd.dispatch_values(signal_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH signal_val: host: " ..  signal_val.host .. 
                " plugin: " .. signal_val.plugin .. 
                " plugin_instance: " .. signal_val.plugin_instance .. 
                " type: " .. signal_val.type .. 
                " type_instance: " .. signal_val.type_instance .. 
                " values: " .. signal_val.values[1])
        end
    end

    -- Send bytes metric
    if client_metrics.rx_bytes and client_metrics.tx_bytes then
        local if_octets_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "if_octets",
            type_instance = host_resolved,
            values = {client_metrics.rx_bytes, client_metrics.tx_bytes}
        }
        collectd.dispatch_values(if_octets_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH if_octets_val: host: " ..  if_octets_val.host .. 
                " plugin: " .. if_octets_val.plugin .. 
                " plugin_instance: " .. if_octets_val.plugin_instance .. 
                " type: " .. if_octets_val.type .. 
                " type_instance: " .. if_octets_val.type_instance .. 
                " values: rx " .. if_octets_val.values[1] .. 
                " values: tx " .. if_octets_val.values[2])
        end
    end

    -- Send packets metric
    if client_metrics.rx_packets and client_metrics.tx_packets then
        local if_packets_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "if_packets",
            type_instance = host_resolved,
            values = {client_metrics.rx_packets, client_metrics.tx_packets}
        }
        collectd.dispatch_values(if_packets_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH if_packets_val: host: " ..  if_packets_val.host .. 
                " plugin: " .. if_packets_val.plugin .. 
                " plugin_instance: " .. if_packets_val.plugin_instance .. 
                " type: " .. if_packets_val.type .. 
                " type_instance: " .. if_packets_val.type_instance .. 
                " values: rx " .. if_packets_val.values[1] .. 
                " values: tx " .. if_packets_val.values[2])
        end
    end

    -- Send dropped packets metric
    if client_metrics.rx_drop_misc then
        local rx_drop_misc_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "if_rx_dropped",
            type_instance = host_resolved,
            values = {client_metrics.rx_drop_misc}
        }
        collectd.dispatch_values(rx_drop_misc_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH rx_drop_misc_val: host: " ..  rx_drop_misc_val.host .. 
                " plugin: " .. rx_drop_misc_val.plugin .. 
                " plugin_instance: " .. rx_drop_misc_val.plugin_instance .. 
                " type: " .. rx_drop_misc_val.type .. 
                " type_instance: " .. rx_drop_misc_val.type_instance .. 
                " values: " .. rx_drop_misc_val.values[1])
        end
    end

    -- Send transmission retries metric - tx_retries
    if client_metrics.tx_retries then
        local tx_retries_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "if_collisions",
            type_instance = host_resolved,
            values = {client_metrics.tx_retries}
        }
        collectd.dispatch_values(tx_retries_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH tx_retries_val: host: " ..  tx_retries_val.host .. 
                " plugin: " .. tx_retries_val.plugin .. 
                " plugin_instance: " .. tx_retries_val.plugin_instance .. 
                " type: " .. tx_retries_val.type .. 
                " type_instance: " .. tx_retries_val.type_instance .. 
                " values: " .. tx_retries_val.values[1])
        end
    end

    -- Send tx failed transmissions metric - tx_failed
    if client_metrics.tx_failed then
        local tx_failed_val = {
            host = host,
            plugin = plugin_name,
            plugin_instance = iface,
            type = "if_tx_dropped",
            type_instance = host_resolved,
            values = {client_metrics.tx_failed}
        }
        collectd.dispatch_values(tx_failed_val)
        if debug then
            collectd.log_error("COLLECTD DISPATCH tx_failed_val: host: " ..  tx_failed_val.host .. 
                " plugin: " .. tx_failed_val.plugin .. 
                " plugin_instance: " .. tx_failed_val.plugin_instance .. 
                " type: " .. tx_failed_val.type .. 
                " type_instance: " .. tx_failed_val.type_instance .. 
                " values: " .. tx_failed_val.values[1])
        end
    end
end

-- Function to parse a single line of WiFi station data
local function parse_station_data_line(line, client_data)
    -- Check different types of data in the line
    local patterns = {
        { pattern = "^%s*rx bitrate:%s*(%S+)", field = "rx_bitrate_str" },
        { pattern = "^%s*tx bitrate:%s*(%S+)", field = "tx_bitrate_str" },
        { pattern = "^%s*signal avg:%s*(%S+)", field = "signal_avg_str" },
        { pattern = "^%s*rx bytes:%s*(%S+)", field = "rx_bytes" },
        { pattern = "^%s*rx packets:%s*(%S+)", field = "rx_packets" },
        { pattern = "^%s*tx bytes:%s*(%S+)", field = "tx_bytes" },
        { pattern = "^%s*tx packets:%s*(%S+)", field = "tx_packets" },
        { pattern = "^%s*tx retries:%s*(%S+)", field = "tx_retries" },
        { pattern = "^%s*tx failed:%s*(%S+)", field = "tx_failed" },
        { pattern = "^%s*rx drop misc:%s*(%S+)", field = "rx_drop_misc" }
    }
    
    for _, p in ipairs(patterns) do
        local value = string.match(line, p.pattern)
        if value then
            client_data[p.field] = value
            return
        end
    end
end

local function read()
    local ifaces_output = exec("/usr/sbin/iw dev | awk '/Interface/ {print $2}'") -- Use custom exec
    if not ifaces_output then
        collectd.log_error("Failed to get wireless interfaces list using 'iw dev'")
        return -1 -- Return 0 for read failure (as per previous correction - should be numeric status)
    end
    local ifaces = {}
    for iface in string.gmatch(ifaces_output, "[^\r\n]+") do
        if table.insert then
            table.insert(ifaces, iface)
        else
            ifaces[#ifaces+1] = iface
        end
    end

    for _, iface in ipairs(ifaces) do
        local clients_output = exec("/usr/sbin/iw dev \"" .. iface .. "\" station dump")
        if clients_output and string.len(clients_output) > 0 then
            local client_blocks = {} -- To store data for each client

            local current_mac = nil -- Initialize current MAC address
            -- Initialize current client data
            local current_client_data = {}

        
            for line in string.gmatch(clients_output, "[^\r\n]+") do -- Iterate through each line
                local mac_match = string.match(line, "^Station%s+(%S+)") -- Check if line starts with "Station MAC"
                if mac_match then
                    if current_mac then -- Save previous client's data if we've already started a block
                        client_blocks[current_mac] = current_client_data
                    end
                    current_mac = mac_match -- Start new client block
                    current_client_data = {} -- Reset data for new client
                else
                    if current_mac then -- If we are inside a client block
                        parse_station_data_line(line, current_client_data)
                    end
                end
            end
            
            if current_mac then -- Save data for the last client
                client_blocks[current_mac] = current_client_data
            end
            
            -- Now you have client data in 'client_blocks' table, keyed by MAC address.
            for mac, client_data in pairs(client_blocks) do
                local host_resolved = find_hostname_or_ip_for_mac(mac)
                
                if host_resolved then
                    -- Prepare structure with client metrics - conversion directly during creation
                    local client_metrics = {
                        rx_rate = multiply_by_million(client_data.rx_bitrate_str),
                        tx_rate = multiply_by_million(client_data.tx_bitrate_str),
                        signal_avg = tonumber(client_data.signal_avg_str),
                        rx_bytes = tonumber(client_data.rx_bytes),
                        tx_bytes = tonumber(client_data.tx_bytes),
                        rx_packets = tonumber(client_data.rx_packets),
                        tx_packets = tonumber(client_data.tx_packets),
                        rx_drop_misc = tonumber(client_data.rx_drop_misc),
                        tx_retries = tonumber(client_data.tx_retries),
                        tx_failed = tonumber(client_data.tx_failed)
                    }
                    
                    -- Call function to send metrics
                    dispatch_client_metrics(host, plugin_name, iface, host_resolved, client_metrics, debug)
                else
                    collectd.log_error("Skipping client with MAC: " .. mac .. " on interface: " .. iface .. " due to missing mapping MAC->IP)")
                end
            end
            
        end
    end

    return 0 -- Return 0 for success
end

if not collectd then
    -- Dummy collectd functions for standalone execution
    collectd = {}
    collectd.log_error = function(msg) print("ERROR: " .. msg) end
    collectd.log_warn = function(msg) print("WARNING: " .. msg) end
    
    -- Helper function to format values array nicely
    local function format_values(values)
        if #values == 1 then
            return tostring(values[1])
        else
            local parts = {}
            for i, v in ipairs(values) do
                parts[i] = tostring(v)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
    end
    
    -- Clean implementation with single responsibility
    collectd.dispatch_values = function(val)
        local formatted_values = format_values(val.values)
        print("COLLECTD DISPATCH: " .. 
              "host: " .. val.host .. 
              " plugin: " .. val.plugin .. 
              " plugin_instance: " .. val.plugin_instance .. 
              " type: " .. val.type .. 
              " type_instance: " .. val.type_instance .. 
              " values: " .. formatted_values)
    end
    
    collectd.register_read = function(func)
        print("Running read function for standalone execution:")
        func()
    end

    -- Set a dummy host name for standalone execution
    host = "localhost"

    -- Call the read function directly
    collectd.register_read(read)
else
    collectd.register_read(read)
end
