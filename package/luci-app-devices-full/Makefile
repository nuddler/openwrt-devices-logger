include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-devices-full
PKG_VERSION:=1.0
PKG_LICENSE:=GPL-3.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=Devices viewer and logger
  DEPENDS:=+luci-base +luci +ip
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_BIN) ./luasrc/controller/devices.lua $(1)/usr/lib/lua/luci/controller/
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/devices
	$(INSTALL_DATA) ./luasrc/view/devices/status.htm $(1)/usr/lib/lua/luci/view/devices/
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./root/usr/bin/devices-logger.sh $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/cron.d
	$(INSTALL_DATA) ./files/etc/cron.d/devices-logger $(1)/etc/cron.d/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

