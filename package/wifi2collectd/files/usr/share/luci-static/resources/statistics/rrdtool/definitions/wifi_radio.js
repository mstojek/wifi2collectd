'use strict';
'require baseclass';

return baseclass.extend({
    title: _('WiFi Radio'),

    rrdargs: function(graph, host, plugin, plugin_instance, dtype) {

        var usage_percent = {
            title: "%H: WiFi Radio Utilization on %pi",
            y_min: "0",
            alt_autoscale_max: true,
            vlabel: "Percent",
            number_format: "%5.1lf%%",
            data: {
                instances: {
                    percent: ["busy", "transmit", "bss_receive"]
                },
                options: {
                    "percent_busy": {
                        title: "Busy",
                        color: "ffb000"
                    },
                    "percent_transmit": {
                        title: "Transmit",
                        color: "0000ff"
                    },
                    "percent_bss_receive": {
                        title: "BSS Receive",
                        color: "00ff00"
                    }
                }
            }
        };

        var clients_bitrate = {
            title: "%H: Client Data Rate %pi",
            detail: true,
            alt_autoscale_max: true,
            vlabel: "Mb/s",
            number_format: "%5.1lf%sbit/s",
            data: {
                types: ["bitrate"],
                options: {
                    bitrate: {
                        title: "%di",
                        overlay: true,
                        noarea: true,
                    }
                }
            }
        };

        var client_signal = {
            title: "%H: RX Wifi Signal Power on %pi",
            detail: true,
            alt_autoscale_max: true,
            vlabel: "dBm",
            number_format: "%5.1lf dBm",
            data: {
                types: ["signal_power"],
                options: {
                    signal_power: {
                        title: "%di",
                        overlay: true,
                        noarea: true,
                    }
                }
            }
        };
        
        var traffic_tx = {
            detail: true,
            title: "%H: TX Transfer on %pi",
            vlabel: "Bytes/s",
            data: {
                sources: {
                    if_octets: ["tx"]
                },
                options: {
                    if_octets__tx: {
                        total: true,
                        title: "%di"
                    }
                }
            }
        };

        var traffic_rx = {
            detail: true,
            title: "%H: RX Transfer on %pi",
            vlabel: "Bytes/s",
            data: {
                sources: {
                    if_octets: ["rx"]
                },
                options: {
                    if_octets__rx: {
                        total: true,
                        title: "%di"
                    }
                }
            }
        };

        var packets_tx = {
            detail: true,
            title: "%H: TX Packets on %pi",
            vlabel: "Packets/s",
            data: {
                types: ["if_packets"],
                sources: {
                    if_packets: ["tx"]
                },
                options: {
                    if_packets__tx: {
                        total: true,
                        title: "%di"
                    }
                }
            }
        };

        var packets_rx = {
            detail: true,
            title: "%H: RX Packets on %pi",
            vlabel: "Packets/s",
            data: {
                types: ["if_packets"],
                sources: {
                    if_packets: ["rx"]
                },
                options: {
                    if_packets__rx: {
                        total: true,
                        title: "%di"
                    }
                }
            }
        };

        var dropped_rx = {
            detail: true,
            title: "%H: RX Dropped Packets on %pi",
            vlabel: "Packets/s",
            data: {
                types: ["if_rx_dropped"],
                options: {
                    if_rx_dropped: {
                        title: "%di",
                        total: true,
                        overlay: true,
                        noarea: true,
                    }
                }
            }
        };

        var retries_tx = {
            detail: true,
            title: "%H: TX Retries on %pi",
            vlabel: "Packets/s",
            data: {
                types: ["if_collisions"],
                options: {
                    if_collisions: {
                        title: "%di",
                        total: true,
                        overlay: true,
                        noarea: true,
                    }
                }
            }
        };
        
        var failed_tx = {
            detail: true,
            title: "%H: TX Failed Packets on %pi",
            vlabel: "Packets/s",
            data: {
                types: ["if_tx_dropped"],
                options: {
                    if_tx_dropped: {
                        title: "%di",
                        total: true,
                        overlay: true,
                        noarea: true,
                    }
                }
            }
        };

        return [usage_percent, clients_bitrate, client_signal, traffic_tx, traffic_rx, packets_tx, packets_rx, dropped_rx, retries_tx, failed_tx];
    }
});
