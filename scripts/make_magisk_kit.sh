#!/usr/bin/env bash
# 从 Magisk APK 中提取命令行修补工具包（boot_patch.sh 所需的全部文件）
# 用法: ./make_magisk_kit.sh <Magisk.apk> [输出目录，默认 magisk_kit]
# 平台: 在 PC（Linux/macOS/Git Bash）或任何有 unzip 的环境运行
set -e

APK="${1:?用法: $0 <Magisk.apk> [输出目录]}"
OUT="${2:-magisk_kit}"
ARCH="${ARCH:-armeabi-v7a}"   # 32 位用户态设备用 armeabi-v7a；64 位用户态设备改 arm64-v8a

command -v unzip >/dev/null || { echo "需要 unzip"; exit 1; }
[ -f "$APK" ] || { echo "找不到 $APK"; exit 1; }

mkdir -p "$OUT"
echo "[1/3] 解压脚本与二进制 (架构: $ARCH) ..."
unzip -q -o "$APK" \
  "assets/boot_patch.sh" "assets/util_functions.sh" "assets/stub.apk" \
  "lib/$ARCH/*" -d "$OUT"

echo "[2/3] 改名（boot_patch.sh 要求的文件名）..."
cd "$OUT"
mv "lib/$ARCH/libmagisk.so"        magisk
mv "lib/$ARCH/libmagiskinit.so"    magiskinit
mv "lib/$ARCH/libmagiskboot.so"    magiskboot
mv "lib/$ARCH/libinit-ld.so"       init-ld
mv "lib/$ARCH/libbusybox.so"       busybox
[ -f "lib/$ARCH/libmagiskpolicy.so" ] && cp "lib/$ARCH/libmagiskpolicy.so" magiskpolicy
rm -rf lib

echo "[3/3] 完成。目录内容:"
ls -l
echo
echo "把整个 $OUT/ 目录推送到设备后，root shell 里执行:"
echo "  export BOOTMODE=true KEEPVERITY=true KEEPFORCEENCRYPT=true"
echo "  sh boot_patch.sh /data/local/tmp/boot_b.img"
