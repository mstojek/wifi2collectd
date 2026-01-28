#
# OpenWrt package makefile for wifi2collectd
#
# NOTE:
# - Before building the package, copy the two Lua scripts into:
#     package/wifi2collectd/files/usr/share/collectd-mod-lua/wifi_utilization_to_collectd.lua
#     package/wifi2collectd/files/usr/share/collectd-mod-lua/wifi_clients_to_collectd.lua
#   (These are the scripts that will be installed to /usr/share/collectd-mod-lua/)
#

include $(TOPDIR)/rules.mk

PKG_NAME:=wifi2collectd
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=Marcin Stojek <mstojek@gmail.com>
PKG_LICENSE:=GPL-3.0
PKG_LICENSE_FILES:=files/usr/share/doc/wifi2collectd/COPYING

PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/wifi2collectd
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=WiFi -> collectd plugin (wifi_radio)
  URL:=https://github.com/mstojek/wifi2collectd
  MAINTAINER:=$(PKG_MAINTAINER)
  # Minimal runtime deps: collectd (core) and iw. Optional components:
  # - collectd-mod-lua: needed if you want collectd's Lua module packaged separately in your build
  # - LuCI packages: only required if you want the LuCI RRD definition to be usable at runtime
  # Some OpenWrt trees expose different package names; keep only guaranteed deps to avoid false warnings.
  # DEPENDS:=+collectd +collectd-mod-lua +iw +luci-lib-ipkg
  DEPENDS:=+collectd +collectd-mod-lua +iw 
endef

define Package/wifi2collectd/description
Collectd Lua plugin that collects WiFi radio utilization and per-client metrics on OpenWrt.
Installs collectd Lua scripts, LuCI RRD definition and collectd conf snippets.
endef

define Build/Compile
	true
endef

define Package/wifi2collectd/install
	$(INSTALL_DIR) $(1)/usr/share/collectd-mod-lua
	$(INSTALL_DATA) ./files/usr/share/collectd-mod-lua/wifi_utilization_to_collectd.lua $(1)/usr/share/collectd-mod-lua/
	$(INSTALL_DATA) ./files/usr/share/collectd-mod-lua/wifi_clients_to_collectd.lua $(1)/usr/share/collectd-mod-lua/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/statistics/rrdtool/definitions
	$(INSTALL_DATA) ./files/www/luci-static/resources/statistics/rrdtool/definitions/wifi_radio.js $(1)/www/luci-static/resources/statistics/rrdtool/definitions/

	$(INSTALL_DIR) $(1)/etc/collectd/conf.d
	$(INSTALL_DATA) ./files/etc/collectd/conf.d/wifi_utilization.conf $(1)/etc/collectd/conf.d/
	$(INSTALL_DATA) ./files/etc/collectd/conf.d/wifi_clients.conf $(1)/etc/collectd/conf.d/

	$(INSTALL_DIR) $(1)/usr/share/doc/wifi2collectd
	$(INSTALL_DATA) ./files/usr/share/doc/wifi2collectd/README.md $(1)/usr/share/doc/wifi2collectd/
	$(INSTALL_DATA) ./files/usr/share/doc/wifi2collectd/COPYING $(1)/usr/share/doc/wifi2collectd/
endef

define Package/wifi2collectd/postinst
	#!/bin/sh
	# check if we are on real system
	if [ -z "$${IPKG_INSTROOT}" ]; then
		## luci_statistics/collectd configuration
		uci set luci_statistics.collectd.Include='/etc/collectd/conf.d'
		uci commit
		/etc/init.d/luci_statistics restart
		rm -rf /tmp/luci-modulecache/
	fi
	exit 0
endef

$(eval $(call BuildPackage,wifi2collectd))
