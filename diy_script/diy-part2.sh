#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

echo "开始 DIY2 配置……"
echo "========================="
build_date=$(TZ=Asia/Shanghai date "+%Y.%m.%d")
build_name="24.10"


# 修改主机名字，修改你喜欢的就行（不能纯数字或者使用中文）
sed -i "/uci commit system/i\uci set system.@system[0].hostname='OpenWrt'" package/lean/default-settings/files/zzz-default-settings
sed -i "s/hostname='.*'/hostname='OpenWrt'/g" ./package/base-files/files/bin/config_generate

# 默认地址
sed -i 's/192.168.1.1/192.168.23.254/g' package/base-files/files/bin/config_generate

# 最大连接数修改为65535
sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

# 设置密码为空（安装固件时无需密码登陆，然后自己修改想要的密码）
sed -i '/$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF./d' package/lean/default-settings/files/zzz-default-settings

# 调整 x86 型号只显示 CPU 型号
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# 设置ttyd免帐号登录
sed -i 's/\/bin\/login/\/bin\/login -f root/' feeds/packages/utils/ttyd/files/ttyd.config

# 默认 shell 为 bash
sed -i 's/\/bin\/ash/\/bin\/bash/g' package/base-files/files/etc/passwd

# 设置argon为默认主题
sed -i '/set luci.main.mediaurlbase=\/luci-static\/bootstrap/d' feeds/luci/themes/luci-theme-bootstrap/root/etc/uci-defaults/30_luci-theme-bootstrap
sed -i 's/Bootstrap theme/Argon theme/g' feeds/luci/collections/*/Makefile
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/*/Makefile

# 更改argon主题背景
cp -f $GITHUB_WORKSPACE/personal/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# 获取发行版 ID (如 OpenWrt)
op_dist=$(grep "DISTRIB_ID=" package/base-files/files/etc/openwrt_release | cut -d"'" -f2)
[ -z "$op_dist" ] && op_dist="OpenWrt"

# 精准获取 Lean 的 Rxx.xx.xx 版本号
lean_r_ver=$(grep -oE "R[0-9]{2}\.[0-9]{2}\.[0-9]{2}" package/lean/default-settings/files/zzz-default-settings | head -n1)
[ -z "$lean_r_ver" ] && lean_r_ver="R26.02.20"

# --- 2. 修改系统首页版本信息 ---
# 这一步先把整行重写为你要求的格式
sed -i "s|DISTRIB_DESCRIPTION='.*'|DISTRIB_DESCRIPTION='Lede by ranqw $build_date @$op_dist $lean_r_ver / Lede - $build_name'|g" package/lean/default-settings/files/zzz-default-settings

# --- 3. 额外清理：强力去除残留的 LEDE 标识 (这就是你问的那行) ---
# 防止某些地方依然引用了旧的变量导致多出 "LEDE" 字样
sed -i "s|%D LEDE||g" package/lean/default-settings/files/zzz-default-settings

# --- 4. 修改 LuCI 界面版本后缀 (去右上角 Git 乱码) ---
sed -i "s|/ LuCI .*'|/ Lede - $build_name'|g" package/base-files/files/bin/config_generate

# --- 5. 替换 Argon 主题页脚 (右下角显示) ---
ARGON_PATH="package/luci-theme-argon/ucode/template/themes/argon"
if [ -d "$ARGON_PATH" ]; then
    cp -f $GITHUB_WORKSPACE/footer.ut $ARGON_PATH/footer.ut
    cp -f $GITHUB_WORKSPACE/footer_login.ut $ARGON_PATH/footer_login.ut
    
    # 批量替换模板中的占位符
    sed -i "s|\${build_date}|$build_date|g" $ARGON_PATH/footer*.ut
    sed -i "s|@OpenWrt|@$op_dist|g" $ARGON_PATH/footer*.ut
    sed -i "s|%R|$lean_r_ver|g" $ARGON_PATH/footer*.ut
fi

# 修改欢迎banner
cp -f $GITHUB_WORKSPACE/personal/banner package/base-files/files/etc/banner

# 修复 netdata 不会自动启动的问题
echo ">>> Fix netdata init.d & enable service"
if [ -f /etc/init.d/netdata ]; then
  echo "netdata init script exists"
else
  if [ -f package/luci-app-netdata/root/etc/init.d/netdata ]; then
    chmod +x package/luci-app-netdata/root/etc/init.d/netdata
  fi
fi
mkdir -p package/base-files/files/etc/rc.d
ln -sf ../init.d/netdata package/base-files/files/etc/rc.d/S99netdata
mkdir -p package/base-files/files/etc/netdata
cat << 'EOF' > package/base-files/files/etc/netdata/netdata.conf
[global]
    run as user = root
    memory mode = ram
[cloud]
    enabled = no
EOF
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-netdata
#!/bin/sh
if [ -x /etc/init.d/netdata ]; then
  /etc/init.d/netdata enable
  /etc/init.d/netdata restart
fi
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-netdata

# 修复上游仓库不稳定造成ustream-ssl报错问题
find . -type f \( -name "Makefile" -o -name "*.mk" \) -exec sed -i 's#https://git.openwrt.org/#https://github.com/openwrt/#g' {} \;
if [ -f "$USTREAM_MK" ]; then
  sed -i 's/^PKG_SOURCE_PROTO.*/PKG_SOURCE_PROTO:=git/' $USTREAM_MK
  sed -i 's#https://github.com/openwrt/project/ustream-ssl.git#https://github.com/openwrt/ustream-ssl.git#g' $USTREAM_MK
  sed -i 's#https://git.openwrt.org/project/ustream-ssl.git#https://github.com/openwrt/ustream-ssl.git#g' $USTREAM_MK
  sed -i '/^PKG_SOURCE:=/d' $USTREAM_MK
  sed -i '/^PKG_HASH:=/d'   $USTREAM_MK
fi
rm -rf dl/ustream-ssl-*
rm -rf build_dir/target-*/ustream-ssl-*

# 移除fchomo和nikki
rm -rf feeds/luci/applications/luci-app-fchomo
rm -rf feeds/luci/applications/luci-app-nikki
rm -rf package/feeds/luci/luci-app-fchomo
rm -rf package/feeds/luci/luci-app-nikki

# rm -rf feeds/luci/applications/luci-app-quickstart
# rm -rf feeds/packages/utils/luci-app-partexp

# 移除 default-settings 中的 UPnP
find package/feeds -type f | xargs sed -i -e '/luci-app-upnp/d' -e '/luci-i18n-upnp/d' -e '/miniupnpd/d'
sed -i '/luci-app-upnp/d' package/Makefile
sed -i '/luci-i18n-upnp/d' package/Makefile
sed -i '/miniupnpd/d' package/Makefile
rm -f tmp/.package_install

# 修复 default-settings 问题
echo ">>> Purge default-settings (all variants)"
find package/feeds -maxdepth 2 -type d -name "default-settings*" -exec rm -rf {} +
rm -rf package/default-settings*

mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-system
#!/bin/sh
uci set system.@system[0].hostname='OpenWrt'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci -q delete system.ntp.server
uci add_list system.ntp.server='ntp.aliyun.com'
uci add_list system.ntp.server='time1.cloud.tencent.com'
uci add_list system.ntp.server='time.apple.com'
uci add_list system.ntp.server='time.windows.com'
uci commit system
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-system
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-luci
#!/bin/sh
uci set luci.main.lang='zh_cn'
uci commit luci
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-luci

find . -type f \( -name "Makefile" -o -name "*.mk" \) \
-exec sed -i 's#https://git.openwrt.org/#https://github.com/openwrt/#g' {} \;

rm -rf dl/ustream-ssl-* build_dir/target-*/ustream-ssl-*
find package -type f | xargs sed -i \
  -e '/luci-app-upnp/d' \
  -e '/luci-i18n-upnp/d' \
  -e '/miniupnpd/d' || true


echo "========================="
echo " DIY2 配置完成……"
