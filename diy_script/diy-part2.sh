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
# 修改主机名字，修改你喜欢的就行（不能纯数字或者使用中文）
sed -i "/uci commit system/i\uci set system.@system[0].hostname='OpenWrt'" package/lean/default-settings/files/zzz-default-settings
sed -i "s/hostname='.*'/hostname='OpenWrt'/g" ./package/base-files/files/bin/config_generate

# 默认地址
sed -i 's/192.168.1.1/192.168.23.250/g' package/base-files/files/bin/config_generate

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

# =========================================================
# 1. 统一变量定义
# =========================================================
build_date=$(date +%Y.%m.%d)
build_name="24.10"

# 动态抓取源码原始版本号 (例如 R26.02.20)
lean_r_ver=$(grep -oE "R[0-9]{2}\.[0-9]{2}\.[0-9]{2}" package/lean/default-settings/files/zzz-default-settings | head -n1)
[ -z "$lean_r_ver" ] && lean_r_ver="R26.02.20"

# =========================================================
# 2. 彻底解决显示后缀和边框问题 (源码级硬核修改)
# =========================================================

# 【A. 阻止 Lean 的 autocore 在编译期强行注入换行符 <br />】
find package/lean/autocore/ -type f -name "Makefile" | xargs -i sed -i '/<br \/>/d' {}

# 【B. 修复系统前缀：确保 /etc/openwrt_release 内容正确】
# 这一步保证“固件版本”行的前半部分显示为：Lede by ranqw R2026.04.15 @OpenWrt R26.02.20
custom_description="Lede by ranqw R${build_date} @OpenWrt "
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='${custom_description}'/g" package/lean/default-settings/files/zzz-default-settings
sed -i "s/DISTRIB_REVISION='.*'/DISTRIB_REVISION='${lean_r_ver}'/g" package/lean/default-settings/files/zzz-default-settings

# 【C. 终极一击：直接修改 LuCI 源码，消灭 git-xxxx 分支信息】

# 1. 处理 23.05+ 的 ucode 架构 (feeds/luci/modules/luci-base/ucode/version.uc)
# 原理：直接把原本由 luci.mk 动态生成的 revision 和 branch 替换为固定值
if [ -f "feeds/luci/modules/luci-base/ucode/version.uc" ]; then
    echo "正在修改 version.uc 以移除 Git 后缀..."
    # 替换 revision 为 'Lede'，替换 branch 为 '- 24.10'
    sed -i "s/revision = .*,/revision = 'Lede',/g" feeds/luci/modules/luci-base/ucode/version.uc
    sed -i "s/branch = .*/branch = '- ${build_name}';/g" feeds/luci/modules/luci-base/ucode/version.uc
fi

# 2. 处理旧版 Lua 架构 (feeds/luci/modules/luci-base/luasrc/version.lua)
if [ -f "feeds/luci/modules/luci-base/luasrc/version.lua" ]; then
    echo "正在修改 version.lua 以兼容旧架构..."
    sed -i "s/luciname    = .*/luciname    = 'Lede'/g" feeds/luci/modules/luci-base/luasrc/version.lua
    sed -i "s/luciversion = .*/luciversion = '- ${build_name}'/g" feeds/luci/modules/luci-base/luasrc/version.lua
fi

# 【清理之前的 JS 篡改，恢复原生拼合逻辑】
# 既然我们已经把后端变量改好了，前端 JS 就会自动拼出 " / Lede - 24.10"
git checkout feeds/luci/modules/luci-mod-system/htdocs/luci-static/resources/view/system/system.js 2>/dev/null
git checkout feeds/luci/modules/luci-base/htdocs/luci-static/resources/luci.js 2>/dev/null

# =========================================================
# 3. Argon 主题页脚动态渲染
# =========================================================
# 覆盖页脚模板文件
cp -f $GITHUB_WORKSPACE/personal/argon/footer.ut package/luci-theme-argon/ucode/template/themes/argon/footer.ut
cp -f $GITHUB_WORKSPACE/personal/argon/footer_login.ut package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut

# 渲染 footer.ut
sed -i "s|\${build_name}|${build_name}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut
sed -i "s|\${build_date}|${build_date}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut
sed -i "s|\${lean_r_ver}|${lean_r_ver}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut

# 渲染 footer_login.ut
sed -i "s|\${build_name}|${build_name}|g" package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut
sed -i "s|\${build_date}|${build_date}|g" package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut
sed -i "s|\${lean_r_ver}|${lean_r_ver}|g" package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut

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
