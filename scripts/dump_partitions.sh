#!/system/bin/sh
# 在已获得 root 的环境（如 DSU 临时系统）里，备份全部引导链分区
# 用法（PC 侧）: adb push dump_partitions.sh /data/local/tmp/ && adb root && adb shell sh /data/local/tmp/dump_partitions.sh
# 结束后: adb pull /data/local/tmp/<分区名>.img

OUT=/data/local/tmp
PARTS="boot_b boot_a vbmeta_b vbmeta_a dtbo_b dtbo_a misc"

[ "$(id -u)" = "0" ] || { echo "需要 root（先执行 adb root）"; exit 1; }

for p in $PARTS; do
  node="/dev/block/by-name/$p"
  [ -e "$node" ] || { echo "跳过 $p（节点不存在）"; continue; }
  echo "== dump $p =="
  dd if="$node" of="$OUT/$p.img" bs=4M
  chmod 644 "$OUT/$p.img"
done

echo
echo "== 校验（boot 镜像开头应为 ANDROID!） =="
for p in boot_b boot_a; do
  printf "%-8s %10s  magic=%s\n" "$p" "$(wc -c < $OUT/$p.img)" \
    "$(dd if=$OUT/$p.img bs=8 count=1 2>/dev/null)"
done

echo
echo "== 拉回 PC =="
echo "adb pull /data/local/tmp/boot_b.img ."
echo "（其余分区同理）"
