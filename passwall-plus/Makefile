include $(TOPDIR)/rules.mk

PKG_NAME:=passwall-plus
PKG_VERSION:=20210802
PKG_RELEASE:=1

PKG_LIBC:=musl
ifeq ($(ARCH),arm)
  PKG_LIBC:=musleabi

  ARM_CPU_FEATURES:=$(word 2,$(subst +,$(space),$(call qstrip,$(CONFIG_CPU_TYPE))))
  ifneq ($(filter $(ARM_CPU_FEATURES),vfp vfpv2),)
    PKG_LIBC:=musleabihf
  endif
endif

PKG_BUILD_DEPENDS:=golang/host upx/host
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)

include $(INCLUDE_DIR)/package.mk
include $(TOPDIR)/feeds/packages/lang/golang/golang-package.mk

define Package/$(PKG_NAME)
	SECTION:=net
	CATEGORY:=Network
	TITLE:=Plugin package for luci-app-passwall-plus
	URL:=https://github.com/shadowsocks/shadowsocks-rust
	DEPENDS:=+libev
endef

define Package/$(PKG_NAME)/description
 will compile sslocal, obfs-local, kcptun-plugin, v2ray-plugin
endef

define Build/Prepare
	chmod +x build.sh
	cp -f main.go.patch /tmp
	./build.sh ${PATH} $(ARCH)-unknown-linux-$(PKG_LIBC) $(TARGET_CROSS) $(PKG_BUILD_DIR) $(STAGING_DIR) $(STAGING_DIR_HOSTPKG) $(TARGET_CXX) $(TARGET_CC) $(GO_OS) $(GO_ARCH) $(STAGING_DIR_HOST)
endef

define Build/Compile
	$(STAGING_DIR_HOST)/bin/upx --best --ultra-brute $(PKG_BUILD_DIR)/simple-obfs/src/obfs-local
	$(STAGING_DIR_HOST)/bin/upx --best --ultra-brute $(PKG_BUILD_DIR)/shadowsocks-rust/target/$(ARCH)-unknown-linux-$(PKG_LIBC)/release/sslocal
	$(STAGING_DIR_HOST)/bin/upx --best --ultra-brute $(PKG_BUILD_DIR)/kcptun/kcptun/client/kcptun-plugin
	$(STAGING_DIR_HOST)/bin/upx --best --ultra-brute $(PKG_BUILD_DIR)/v2ray-plugin/v2ray-plugin
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/shadowsocks-rust/target/$(ARCH)-unknown-linux-$(PKG_LIBC)/release/sslocal $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/v2ray-plugin/v2ray-plugin $(1)/usr/bin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/kcptun/kcptun/client/kcptun-plugin $(1)/usr/bin/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
