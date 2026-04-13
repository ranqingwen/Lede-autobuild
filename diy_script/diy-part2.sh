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

# --- 1. 环境与日期变量定义 ---
# 获取当前日期，格式如 2026.04.10
build_date=$(TZ=Asia/Shanghai date "+%Y.%m.%d")
# 自定义版本名称
build_name="24.10"

# === 固件版本信息彻底纯净修改 ===

# 抓取 Lean 原始版本号 (如 R26.02.20)
lean_r_ver=$(grep -oE "R[0-9]{2}\.[0-9]{2}\.[0-9]{2}" package/lean/default-settings/files/zzz-default-settings | head -n1)
[ -z "$lean_r_ver" ] && lean_r_ver="R26.02.20"

# 2. 彻底粉碎 zzz-default-settings 中原本对版本的修改逻辑
# 这步非常关键：直接删掉所有包含 DISTRIB_REVISION 和 DISTRIB_DESCRIPTION 的行
# 这样它就不会再把 "/ LuCI openwrt-23.05..." 那串东西强行塞进修订号了
sed -i '/DISTRIB_REVISION/d' package/lean/default-settings/files/zzz-default-settings
sed -i '/DISTRIB_DESCRIPTION/d' package/lean/default-settings/files/zzz-default-settings

# 3. 在 zzz-default-settings 的最后（exit 0 之前）强行注入我们的纯净赋值
# 这种方式优先级最高，且变量内不含任何斜杠
sed -i "/exit 0/i sed -i \"s|DISTRIB_DESCRIPTION=.*|DISTRIB_DESCRIPTION='Lede by ranqw R$build_date @OpenWrt $lean_r_ver'|g\" /etc/openwrt_release" package/lean/default-settings/files/zzz-default-settings
sed -i "/exit 0/i sed -i \"s|DISTRIB_REVISION=.*|DISTRIB_REVISION='Lede - $build_name'|g\" /etc/openwrt_release" package/lean/default-settings/files/zzz-default-settings

# 4. 修改 LuCI 页面渲染代码 (实现“网页显示有斜杠”的关键)
# 它会在显示时自动把两个变量用 " / " 连接，而不改动变量本身的内容
js_file="feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
if [ -f "$js_file" ]; then
    # 将原来的空格分隔替换为斜杠分隔
    sed -i "s/res.release.revision ? ' ' + res.release.revision : ''/res.release.revision ? ' \/ ' + res.release.revision : ''/g" "$js_file"
fi

# === Argon 主题页脚动态渲染脚本 ===

# 1. 覆盖页脚模板文件
# 保持 .ut 文件内的 ${变量名} 占位符不变，直接复制到源码目录
cp -f $GITHUB_WORKSPACE/personal/argon/footer.ut package/luci-theme-argon/ucode/template/themes/argon/footer.ut
cp -f $GITHUB_WORKSPACE/personal/argon/footer_login.ut package/luci-theme-argon/ucode/template/themes/argon/footer_login.ut

# 2. 精确替换模板中的三个动态变量
# 通过 sed 将 .ut 文件里的占位符强行替换为脚本开头抓取到的实际变量值
# 这样你改一次脚本顶部的变量，页脚就会跟着自动变，不需要去动 .ut 文件

# 渲染 footer.ut (主界面页脚)
sed -i "s|\${build_name}|${build_name}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut
sed -i "s|\${build_date}|${build_date}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut
sed -i "s|\${lean_r_ver}|${lean_r_ver}|g" package/luci-theme-argon/ucode/template/themes/argon/footer.ut

# 渲染 footer_login.ut (登录界面页脚)
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
