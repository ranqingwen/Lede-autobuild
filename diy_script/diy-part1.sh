#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# 添加源仓库
# sed -i '/helloworld/d' feeds.conf.default
# sed -i '/small/d' feeds.conf.default
# sed -i '/passwall/d' feeds.conf.default
# sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default
# 添加linkease源
# sed -i '$a src-git istore https://github.com/linkease/istore;main' feeds.conf.default
# sed -i '$a src-git nas https://github.com/linkease/nas-packages-luci.git;main' feeds.conf.default
# PassWall2核心依赖包
# sed -i '$a src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' feeds.conf.default
# PassWall2 界面
# sed -i '$a src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main' feeds.conf.default


# 清除旧的重复项（防止脚本多次运行导致内容重复）
sed -i '/helloworld/d' feeds.conf.default
sed -i '/small/d' feeds.conf.default
sed -i '/passwall/d' feeds.conf.default
sed -i '/istore/d' feeds.conf.default
# 插入或追加新源
sed -i '2i src-git small https://github.com/kenzok8/small' feeds.conf.default
# 在末尾追加其他源
cat <<EOF >> feeds.conf.default
src-git istore https://github.com/linkease/istore;main
src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main
src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main
EOF


# 添加 adguardHome
#git clone --depth=1 --single-branch https://github.com/sirpdboy/luci-app-#adguardhome.git

# 添加 argon 主题
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-argon-config
git clone https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# 添加 Lucky
git clone https://github.com/gdy666/luci-app-lucky.git package/lucky

# 添加 netdata
git clone https://github.com/sirpdboy/luci-app-netdata package/luci-app-netdata

# 添加 oaf
git clone https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter

# 添加 poweroffdevice
git clone https://github.com/sirpdboy/luci-app-poweroffdevice.git package/luci-app-poweroffdevice

# 添加 luci-app-partexp (分区扩容插件)
git clone https://github.com/sirpdboy/luci-app-partexp.git package/luci-app-partexp

# 添加 openclaw
#git clone https://github.com/10000ge10000/luci-app-openclaw.git package/luci-app-openclaw

# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}


