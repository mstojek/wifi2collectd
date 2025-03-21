-- collectd lua plugin script for monitoring WiFi channel usage on OpenWrt
-- Outputs values in collectd plugin format
-- Simplified version - line-by-line analysis, reaction to "[in use]"
-- Code with extracted function dispatch_wifi_metrics_for_in_use_block for readability

-- Configuration --
local debug = false -- Set to true to enable debug logging
local host = '' -- You can change to "${COLLECTD_HOSTNAME:-$(cat /proc/sys/kernel/hostname)}"
-- local interval = read_config("Interval") or 30 -- Set Interval globally in collectd.conf or by default in the script
local plugin_name = "wifi_radio"

-- Global variables to store previous values
local prev_values = {}

-- Function to get safe interface name
local function get_safe_iface_name(iface)
    return string.gsub(iface, "[^a-zA-Z0-9_]", "_")
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



-- Function for dispatching metrics for "in use" block
local function dispatch_wifi_metrics_for_in_use_block(iface_safe, iface, active, busy, transmit, bss_receive)
    local prev_active_val = prev_values["prev_active_" .. iface_safe] or 0
    local prev_busy_val = prev_values["prev_busy_" .. iface_safe] or 0
    local prev_transmit_val = prev_values["prev_transmit_" .. iface_safe] or 0
    local prev_bss_receive_val = prev_values["prev_bss_receive_" .. iface_safe] or 0
    if debug then
        collectd.log_error("Dispatching metrics for " .. iface .. " (safe: " .. iface_safe .. ")")
        collectd.log_error("Active: " .. active .. " (prev: " .. prev_active_val .. ")")
        collectd.log_error("Busy: " .. busy .. " (prev: " .. prev_busy_val .. ")")
        collectd.log_error("Transmit: " .. transmit .. "(prev: " .. prev_transmit_val .. ")")
        collectd.log_error("BSS receive: " .. bss_receive .. " (prev: " .. prev_bss_receive_val .. ")")
    end
    
    
    -- Check if we have valid previous values and if the current values are greater than the previous ones
    if active > 0 and prev_active_val > 0 and active >= prev_active_val then
        local delta_active = active - prev_active_val
        if debug then
            collectd.log_error("Delta active: " .. delta_active)
        end
        
        if delta_active > 0 then

            local delta_busy
            if busy > 0 and prev_busy_val > 0 and busy >= prev_busy_val then
                delta_busy = busy - prev_busy_val
                if debug then
                    collectd.log_error("Delta busy: " .. delta_busy)
                end
            else
                delta_busy = nil
                if debug then
                    collectd.log_error("Invalid busy value: " .. tostring(busy))
                end
            end

            local delta_transmit
            if transmit > 0 and prev_transmit_val > 0 and transmit >= prev_transmit_val then
                delta_transmit = transmit - prev_transmit_val
                if debug then
                    collectd.log_error("Delta transmit: " .. delta_transmit)
                end
            else
                delta_transmit = nil
                if debug then
                    collectd.log_error("Invalid transmit value : " .. tostring(transmit))
                end
            end

            local delta_bss_receive
            if bss_receive > 0 and prev_bss_receive_val > 0 and bss_receive >= prev_bss_receive_val then
                delta_bss_receive = bss_receive - prev_bss_receive_val
                if debug then
                    collectd.log_error("Delta bss_receive: " .. delta_bss_receive)
                end
            else
                delta_bss_receive = nil
                if debug then
                    collectd.log_error("Invalid bss_receive value: " .. tostring(bss_receive))
                end
            end
       
            local busy_percentage
            if delta_busy  and delta_busy >= 0 then
                busy_percentage = delta_busy * 100.0 / delta_active
                if debug then
                    collectd.log_error("Busy percentage: " .. busy_percentage)
                end
            else
                busy_percentage = nil
                if debug then
                    collectd.log_error("Invalid delta_busy value: " .. tostring(delta_busy))
                end
            end
 
            local transmit_percentage
            if delta_transmit and delta_transmit >= 0 then
                transmit_percentage = delta_transmit * 100.0 / delta_active
                if debug then
                    collectd.log_error("Transmit percentage: " .. transmit_percentage)
                end
            else
                transmit_percentage = nil
                if debug then
                    collectd.log_error("Invalid delta_transmit value: " .. tostring(delta_transmit))
                end
            end
            
            local bss_receive_percentage
            if delta_bss_receive and delta_bss_receive >= 0 then
                bss_receive_percentage = delta_bss_receive * 100.0 / delta_active
                if debug then
                    collectd.log_error("BSS receive percentage: " .. bss_receive_percentage)
                end
            else
                bss_receive_percentage = nil
                if debug then
                    collectd.log_error("Invalid delta_bss_receive value: " .. tostring(delta_bss_receive))
                end
            end
            
            -- local busy_val 
            if busy_percentage then
                local busy_val = {   
                    host = host,
                    plugin = plugin_name,
                    plugin_instance = iface,
                    type = "percent",
                    type_instance = "busy",
                    --interval = interval,
                    values = {busy_percentage}
                }
                -- busy_val:dispatch()
                collectd.dispatch_values(busy_val)
                if debug then
                    collectd.log_error("COLLECTD DISPATCH rx_val: host: " ..  busy_val.host .. 
                        " plugin: " .. busy_val.plugin .. 
                        " plugin_instance: " .. busy_val.plugin_instance .. 
                        " type: " .. busy_val.type .. 
                        " type_instance: " .. busy_val.type_instance .. 
                        " values: " .. busy_val.values[1])
                end
            else
                if debug then
                    collectd.log_error("Invalid busy_percentage value: " .. tostring(busy_percentage))
                end            
            end

            -- local transmit_val 
            if transmit_percentage then
                local transmit_val = {
                    host = host,
                    plugin = plugin_name,
                    plugin_instance = iface,
                    type = "percent",
                    type_instance = "transmit",
                    -- interval = interval,
                    values = {transmit_percentage}
                }
                -- transmit_val:dispatch()
                collectd.dispatch_values(transmit_val)
                if debug then
                    collectd.log_error("COLLECTD DISPATCH rx_val: host: " ..  transmit_val.host .. 
                        " plugin: " .. transmit_val.plugin .. 
                        " plugin_instance: " .. transmit_val.plugin_instance .. 
                        " type: " .. transmit_val.type .. 
                        " type_instance: " .. transmit_val.type_instance .. 
                        " values: " .. transmit_val.values[1])
                end
            else
                if debug then
                    collectd.log_error("Invalid transmit_percentage value: " .. tostring(transmit_percentage))
                end
            end

            -- local bss_receive_val
            if bss_receive_percentage then
                local bss_receive_val = {
                    host = host,
                    plugin = plugin_name,
                    plugin_instance = iface,
                    type = "percent",
                    type_instance = "bss_receive",
                    -- interval = interval,
                    values = {bss_receive_percentage}
                }
                -- bss_receive_val:dispatch()
                collectd.dispatch_values(bss_receive_val)
                if debug then
                    collectd.log_error("COLLECTD DISPATCH rx_val: host: " ..  bss_receive_val.host .. 
                        " plugin: " .. bss_receive_val.plugin .. 
                        " plugin_instance: " .. bss_receive_val.plugin_instance .. 
                        " type: " .. bss_receive_val.type .. 
                        " type_instance: " .. bss_receive_val.type_instance .. 
                        " values: " .. bss_receive_val.values[1])
                end
            else
                if debug then
                    collectd.log_error("Invalid bss_receive value: " .. tostring(bss_receive))
                end
            end
        else
            if debug then
                collectd.log_error("Invalid delta_active value: " .. tostring(delta_active))
            end
        end
    else
        if debug then
            collectd.log_error("Invalid active value: " .. tostring(active) .. " or previous active value equals zero or is less than active, prev_active_val is: " .. tostring(prev_active_val))
        end
    end

    -- Save current values (only for the "in use" block)
    prev_values["prev_active_" .. iface_safe] = active
    prev_values["prev_busy_" .. iface_safe] = busy
    prev_values["prev_transmit_" .. iface_safe] = transmit
    prev_values["prev_bss_receive_" .. iface_safe] = bss_receive
end


local function read()
    local ifaces_output = exec("/usr/sbin/iw dev | awk '/Interface/ {print $2}'")
    if not ifaces_output or string.len(ifaces_output) == 0 then
        collectd.log_error("Failed to get wireless interfaces list using 'iw dev'")
        return -1
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
        local iface_safe = get_safe_iface_name(iface)
        local output = exec("/usr/sbin/iw dev " .. iface .. " survey dump 2>/dev/null")
        if not output or string.len(output) == 0 then
            collectd.log_error("Command 'iw dev " .. iface .. " survey dump' failed or returned no output for interface " .. iface)
        else
            local in_use_block = false -- Flaga, czy jesteśmy w bloku "in use"
            local active = 0
            local busy = 0
            local transmit = 0
            local bss_receive = 0

            for line in string.gmatch(output, "[^\r\n]+") do -- Process output lines
                if string.match(line, "frequency:.*%[in use%]") then
                    in_use_block = true -- Found "in use" block - set flag
                    active = 0          -- Reset values for new "in use" block
                    busy = 0
                    transmit = 0
                    bss_receive = 0
                elseif in_use_block then -- Only if "in_use_block" flag is set
                    if string.match(line, "channel active time:") then
                        local value_str = string.match(line, "channel active time:%s+(%d+)")
                        if value_str then
                            active = tonumber(value_str)
                        end
                    elseif string.match(line, "channel busy time:") then
                        local value_str = string.match(line, "channel busy time:%s+(%d+)")
                        if value_str then
                            busy = tonumber(value_str)
                        end
                    elseif string.match(line, "channel transmit time:") then
                        local value_str = string.match(line, "channel transmit time:%s+(%d+)")
                        if value_str then
                            transmit = tonumber(value_str)
                        end
                    elseif string.match(line, "channel BSS receive time:") then
                        local value_str = string.match(line, "channel BSS receive time:%s+(%d+)")
                        if value_str then
                            bss_receive = tonumber(value_str)
                        end
                    elseif string.match(line, "^Survey data from ") then
                        dispatch_wifi_metrics_for_in_use_block(iface_safe, iface, active, busy, transmit, bss_receive)
                        in_use_block = false -- Nowy blok "Survey data" - resetuj flagę "in use"
                    end
                end
            end


            -- Dispatch for the *last* block after the loop finishes**
            if in_use_block then
                dispatch_wifi_metrics_for_in_use_block(iface_safe, iface, active, busy, transmit, bss_receive)
            end
        end
    end
    return 0
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



