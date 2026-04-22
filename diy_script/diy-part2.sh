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

#!/bin/bash

#!/bin/bash

# =========================================================
# 1. 统一变量定义
# =========================================================
build_date=$(date +%Y.%m.%d)
build_name="24.10"

# 动态抓取源码原始修订号 (R26.xx.xx)
lean_r_ver=$(grep -oE "R[0-9]{2}\.[0-9]{2}\.[0-9]{2}" package/lean/default-settings/files/zzz-default-settings | head -n1)
[ -z "$lean_r_ver" ] && lean_r_ver="R2026.02.20"

# 构造完整的描述字符串：这里一定要包含 ${lean_r_ver}
custom_description="Lede by ranqw R${build_date} @OpenWrt ${lean_r_ver}"

# =========================================================
# 2. 修正固件版本显示 & 移除“边框”（换行符）
# =========================================================

# 【A. 彻底清理 autocore 的换行符】
# 之前只改了 Makefile 是不够的，必须清理 autocore 源码中所有可能注入 <br /> 的地方
# 这能解决你看到的“边框/错位”问题
find package/lean/autocore/ -type f | xargs -i sed -i 's/<br \/>//g' {}

# 【B. 修正系统描述 /etc/openwrt_release】
sed -i "s/DISTRIB_DESCRIPTION='.*'/DISTRIB_DESCRIPTION='${custom_description}'/g" package/lean/default-settings/files/zzz-default-settings
# 将 REVISION 设为空或者特定字符，防止 LuCI 在后面二次拼接导致重复显示
sed -i "s/DISTRIB_REVISION='.*'/DISTRIB_REVISION=''/g" package/lean/default-settings/files/zzz-default-settings

# 【C. 暴力覆盖 LuCI 版本文件 - 解决 25.12 顽固显示】
# 处理 ucode 架构 (version.uc)
UC_FILE=$(find feeds/luci/modules/luci-base/ -name "version.uc" | head -n 1)
if [ -n "$UC_FILE" ]; then
    echo "export const branch = 'Lede', revision = '- ${build_name}';" > "$UC_FILE"
fi

# 处理 Lua 架构 (version.lua)
LUA_FILE=$(find feeds/luci/modules/luci-base/ -name "version.lua" | head -n 1)
if [ -n "$LUA_FILE" ]; then
    cat << EOF > "$LUA_FILE"
local pcall, dofile, _G = pcall, dofile, _G
module "luci.version"
if pcall(dofile, "/etc/openwrt_release") and _G.DISTRIB_DESCRIPTION then
	distname    = ""
	distversion = _G.DISTRIB_DESCRIPTION
	if _G.DISTRIB_REVISION and _G.DISTRIB_REVISION ~= "" then
		distrevision = _G.DISTRIB_REVISION
		if not distversion:find(distrevision,1,true) then
			distversion = distversion .. " " .. distrevision
		end
	end
else
	distname    = "OpenWrt"
	distversion = "Development Snapshot"
end
luciname    = "Lede"
luciversion = "- ${build_name}"
EOF
fi

# 【D. 拦截 Makefile 变量】
sed -i "s/PKG_VERSION_BRANCH:=.*/PKG_VERSION_BRANCH:=Lede/g" feeds/luci/modules/luci-base/Makefile 2>/dev/null
sed -i "s/PKG_VERSION_REVISION:=.*/PKG_VERSION_REVISION:=- ${build_name}/g" feeds/luci/modules/luci-base/Makefile 2>/dev/null

# =========================================================
# 3. Argon 主题页脚动态渲染 (保持你之前的逻辑不变)
# =========================================================
cp -f $GITHUB_WORKSPACE/personal/argon/footer.ut package/luci-theme-argon/ucode/template/themes/argon/footer.ut
cp -f $GITHUB_WORKSPACE/personal/argon/footer_login.ut package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut

sed -i "s|\${build_name}|${build_name}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut
sed -i "s|\${build_date}|${build_date}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut
sed -i "s|\${lean_r_ver}|${lean_r_ver}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut

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

# =========================================================
# 4. 彻底解决 fchomo 和 nikki 导致的递归依赖循环
# =========================================================
echo ">>> 正在强制清理冲突插件..."

# 1. 使用 find 命令全局查找并删除，确保无论是哪个 feed 里的都被删掉
find ./feeds/ -type d -name "luci-app-fchomo" | xargs rm -rf
find ./feeds/ -type d -name "luci-app-nikki" | xargs rm -rf
find ./feeds/ -type d -name "nikki" | xargs rm -rf
find ./package/feeds/ -type d -name "luci-app-fchomo" | xargs rm -rf
find ./package/feeds/ -type d -name "luci-app-nikki" | xargs rm -rf
find ./package/feeds/ -type d -name "nikki" | xargs rm -rf

# 2. 关键一步：强制删除 tmp 目录，清除已损坏的依赖索引
# 如果不删 tmp，即便删了插件，系统可能还会报递归错误
rm -rf tmp

echo ">>> 冲突插件清理完成。"

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
