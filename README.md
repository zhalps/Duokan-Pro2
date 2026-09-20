# 小米多看电纸书 Pro 2 Root 教程：无官方固件、无拆机（墨案系 RK3566 通用思路）

> - 适配机型：**小米多看电纸书 Pro 2**（Moaan MiDuoKanReader Pro II / RK3566 / Android 11）
> - 同思路适用：墨案系电纸书（多看一代 / Pro / inkPalm 5 / inkPad / Mix 7 等），
>   只需按本文"第四步·GSI 架构"一节换成你自己设备的架构
> - 特点：**不需要官方固件包、不需要拆机短接、不改任何 bootloader 分区**，
>   利用 Android 自带的 **DSU（动态系统更新）** 临时启动一个带 root 的系统来提取 boot 镜像
> - 作者环境：Windows 11 + adb；全程一根 USB 线

---

## 免责声明

刷机有风险。本教程涉及向设备的 `boot` 分区写入修改过的镜像，
**如果操作失误且你手中没有对应的备份，设备可能无法正常启动**。
本文所用方法已在一台 Pro 2 上完整验证，但请务必：
1. **先完成第五步的全分区备份再进行任何写入**；
2. 确认你理解每条命令在做什么；
3. 风险自负。

---

## 一、这台设备的难点（为什么常规方法都不行）

| 难点 | 说明 |
|---|---|
| **没有官方固件包** | OTA 服务器上查不到任何可下载的固件；一旦写坏 boot 没有软件救回途径 |
| **Loader 模式读取墙** | Rockchip Loader 模式只能读 flash 前 32MB（u-boot 上报 `ReadLBA: Disable`），而 boot 分区在 40MB 之后 |
| **MaskROM 不可用** | 实测进入 MaskROM 后 USB 栈卡死 / loader 无法接管 |
| **recovery 只认官方签名** | `adb sideload` 自签包直接被拒（AOSP testkey 也不行，见踩坑记录） |
| **系统是 user + release-keys** | 没有 `adb root`，没有 testkey 后门 |
| **无 SD 卡槽** | 没有"存卡里带走"的退路，所有产物只能通过 adb 传输 |

## 二、破局思路（一句话）

> **既然读不出 boot 分区，那就换一个有 root 权限的系统来读。**

Android 自带 **DSU（Dynamic System Update，动态系统更新）**：
它把一个 GSI（通用系统镜像）安装到 `/data` 下的**文件回环设备**上，
**不写入任何只读分区**，重启即进入临时系统，再重启一次就回到原厂系统。

于是流程变成：

```
原厂系统（无 root）
   ↓  DSU 安装一个 userdebug 的 GSI
临时 GSI 系统（adb root = uid 0）
   ↓  dd 读出 boot 分区
boot.img 到手 → Magisk 修补 → 刷回 → 原厂系统获得 root
```

## 三、前置条件

- Android **11**（DSU 要求 ≥10）、**动态分区**（`ro.boot.dynamic_partitions=true`）、
  **Treble**（`ro.treble.enabled=true`）
- bootloader 已解锁（`ro.boot.flash.locked=0`）——Pro2 出厂即为解锁状态，
  fastbootd 里确认 `unlocked: yes`
- userdata 剩余空间 > 8GB（DSU 需要在 /data 里放 GSI 镜像 + 分配 userdata 空间）
- DSU 组件完整：`/system/bin/gsid`、`com.android.dynsystem`（ priv-app，一般都有）
- PC 装好 adb（platform-tools）

自查命令：
```bash
adb shell getprop ro.build.version.release      # 11
adb shell getprop ro.treble.enabled             # true
adb shell getprop ro.boot.dynamic_partitions    # true
adb shell getprop ro.boot.flash.locked          # 0
adb shell getprop ro.product.cpu.abilist        # ← 决定 GSI 架构，见第四步
```

## 四、★★ GSI 架构选择（本文最大的坑）

GSI 文件名里的架构字段**必须与设备匹配**，选错 = GSI 必然无法启动：

| GSI 架构字段 | 适用设备 | 判定依据 |
|---|---|---|
| `arm` | **32 位内核** + 32 位用户态 | `/proc/config.gz` 里 `CONFIG_ARM64=n` |
| **`arm32_binder64`**（部分构建叫 `a64`） | **64 位内核 + 32 位用户态** | `CONFIG_ARM64=y` 且 abilist 无 arm64 |
| `arm64` | 64 位内核 + 64 位用户态 | abilist 含 arm64-v8a |

Pro 2 实测：`CONFIG_ARM64=y`（64 位内核），`ro.product.cpu.abilist = armeabi-v7a,armeabi`
（32 位用户态，`abilist64` 为空）→ **必须选 `arm32_binder64`（a64）**。

> ⚠️ **我们最初选了 `arm` 版 GSI，三次安装三次引导失败**——架构错一个位（binder 位数），
> 系统就起不来，且表象（重启后掉进 fastboot/回原厂）极具迷惑性。
> 判定内核位宽**不要用 `uname -m`**（64 位内核跑 32 位进程时它也显示 `armv8l`），
> 必须看 `/proc/config.gz` 的 `CONFIG_ARM64`。

VNDK 版本也要匹配：Pro 2 是 Android 11（VNDK 30），所以选 **Android 11 的 GSI**。

最终使用的 GSI（phh treble 官方构建，自带 root）：
```
https://github.com/phhusson/treble_experimentations/releases/download/v313/
  system-roar-arm32_binder64-ab-vanilla.img.xz
```
（`roar` = Android 11；`ab` = A/B 分区；`vanilla` = 无谷歌服务；
v313 的安全补丁级别 2021-10 晚于本机 2021-06，能通过 DSU 的补丁检查）

解压（xz）得到约 1GB 的 `.img`，**补齐到 512 字节对齐**（DSU 会检查）：
```python
import os
f = 'system-roar-arm32_binder64-ab-vanilla.img'
size = os.path.getsize(f)
pad = (512 - size % 512) % 512
if pad:
    open(f, 'ab').write(b'\0' * pad)
```
然后 gzip 打包成 `.img.gz`（**DSU 只接受 .gz/.xz 等压缩扩展名，裸 .img 会被拒**）：
```bash
gzip -1 -c system-roar-arm32_binder64-ab-vanilla.img > system-roar-arm32_binder64-ab-vanilla.img.gz
```

## 五、步骤 1：DSU 安装（不写入任何只读分区）

### 1. 推送镜像
```bash
adb push system-roar-arm32_binder64-ab-vanilla.img.gz /storage/emulated/0/Download/
```

### 2. ★ 打开 DSU 的隐藏开关（最容易卡住的一步）
DSU 的确认界面前有一个**特性标志（FeatureFlag）检查**，不开就"点了没反应"：
```bash
adb shell setprop persist.sys.fflag.override.settings_dynamic_system true
```
> 这个开关**不在** Settings 数据库里，网上教程常写 `settings put global ...`，对本机无效。

### 3. 触发 DSU 安装
```bash
adb shell am start-activity \
  -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
  -a android.os.image.action.START_INSTALL \
  -d file:///storage/emulated/0/Download/system-roar-arm32_binder64-ab-vanilla.img.gz \
  --el KEY_SYSTEM_SIZE 1081640960 \
  --el KEY_USERDATA_SIZE 8589934592
```
> `KEY_SYSTEM_SIZE` = 镜像的 raw 大小（sparse 头里 `total_blocks × block_size`），
> 直接决定 DSU 分区大小，给小了安装会失败。

设备上会弹出确认框 → 确认 → 等待安装完成（约 5~15 分钟）。

## 六、步骤 2：进入临时系统并提取 boot

1. 安装完成后，**点通知栏里的"重启"按钮**（不要用电源菜单重启，也不要混用其他启用方式，
   否则整个安装会被回滚清掉）。
2. 重启后**屏幕黑屏/卡在第一屏是正常现象**（GSI 缺少墨水屏驱动）——
   **不影响 adb**。等 `adb devices` 重新出现设备即可。
3. 拿 root：
```bash
adb root          # userdebug GSI，直接生效
adb shell id      # 应显示 uid=0(root)
```
4. 提取分区镜像：
```bash
adb shell '
for p in boot_b boot_a vbmeta_b vbmeta_a dtbo_b dtbo_a misc; do
  dd if=/dev/block/by-name/$p of=/data/local/tmp/$p.img bs=4M
done
chmod 644 /data/local/tmp/*.img'
adb pull /data/local/tmp/boot_b.img .
```
验收：`boot_b.img` 大小 = 分区表里 boot 分区的大小（本机 96MB = 100,663,296 字节），
开头 8 字节为 `ANDROID!`。

> 至此**整个 boot 链的备份已经到手**——后续无论怎么改，都能刷回原样。

## 七、步骤 3：Magisk 命令行修补（黑屏无 UI 也能做）

GSI 没有可用的屏幕，Magisk App 的图形界面用不了，改用 **Magisk 自带的命令行修补脚本**。

1. 从 [Magisk 官方 Release](https://github.com/topjohnwu/Magisk/releases) 下载 Magisk APK；
2. 用仓库里的 [`scripts/make_magisk_kit.sh`](scripts/make_magisk_kit.sh) 从 APK 中提取并改名；
3. 把整个 `magisk_kit/` 推到设备并执行：
```bash
adb push magisk_kit /data/local/tmp/magisk_kit
adb shell '
cd /data/local/tmp/magisk_kit
chmod -R 755 .
export BOOTMODE=true KEEPVERITY=true KEEPFORCEENCRYPT=true
sh boot_patch.sh /data/local/tmp/boot_b.img'
```
4. 拉取产物：
```bash
adb pull /data/local/tmp/magisk_kit/new-boot.img magisk_patched_boot.img
```

## 八、步骤 4：刷入修补后的 boot

> 执行这一步前，请确认第七步的 `boot_b.img` 原厂备份已经拉回电脑！

```bash
adb shell dd if=/data/local/tmp/magisk_kit/new-boot.img of=/dev/block/by-name/boot_b bs=4M
adb shell md5sum /dev/block/by-name/boot_b     # 与 new-boot.img 的 md5 比对
adb reboot
```

重启回原厂系统后：
1. 安装 Magisk App（`adb install Magisk-v30.7.apk`）；
2. 首次打开会提示"需要额外安装，完成后自动重启" → 确认 → 自动重启一次；
3. `adb shell su -c id` → `uid=0(root)` ✅
   （如果提示"某应用遮挡了超级用户页面"，是因为 **Magisk 不在前台**——
   先把 Magisk 调到前台再发一次请求即可。）

## 九、恢复 / 救砖

| 场景 | 救法 |
|---|---|
| 刷入修补 boot 后起不来 | 启动失败会**自动掉进 fastboot**（A/B 失败计数兜底）→ `fastboot flash boot_b boot_b.img`（原厂备份）→ `fastboot continue` |
| 想彻底 unroot | 直接刷回原厂 boot_b 即可 |
| 系统 OTA 前 | 必须先在 Magisk 里"还原原厂映像"，升级完成后再重新修补 |

## 十、踩坑记录（浓缩版）

1. **GSI 架构选错 = 引导必败**，且表象（掉 fastboot / 回原厂）极具迷惑性——用 `/proc/config.gz` 判内核位宽，别用 `uname -m`
2. **DSU 的 FeatureFlag 开关**：`persist.sys.fflag.override.settings_dynamic_system` 是系统属性，不是 Settings 键
3. **DSU 只认压缩扩展名**：裸 `.img` 直接 `UnsupportedFormatException`
4. **不能直接启动安装服务**：会报 "Verification failed. Did you use VerificationActivity?"——必须走 Activity
5. **DSU 装完只能点通知栏的"重启"**：与其他启用方式混用会导致整个安装被回滚
6. **Magisk 授权需要前台**：请求弹出时 Magisk 不在前台会被自动拒绝（"应用遮挡"）
7. **Pro2 的 recovery 不接受 testkey 签名的 sideload 包**（实测），与墨案 inkPalm5 等老机型不同
8. **u-boot fastboot 下不要执行 `fastboot getvar all`**：会搞死 USB 通道，只能重插线

## 十一、致谢与参考

- [qwerty12/inkPalm-5-EPD105-root](https://github.com/qwerty12/inkPalm-5-EPD105-root) ——
  墨案系 root 的先河，本文的 Magisk 修补流程沿用了它的思路
- [墨案 Mix7 root 小记（tenpurro）](https://blog.tenpurro.xyz/posts/moaan-mix-7-root) ——
  同为 Rockchip + Android 11 + 内核 4.19，其"DSU 黑屏但 adb 可用"的经验是本文的关键参考
- [小米多看电纸书系列 root（ximin.top）](https://ximin.top/blog/140.html)、
  [CSDN 同款设备救砖记录](https://blog.csdn.net/sz3076799/article/details/163073372)
- [Magisk](https://github.com/topjohnwu/Magisk) ·
  [phh treble GSI](https://github.com/phhusson/treble_experimentations) ·
  [Andy Yan GSI builds](https://sourceforge.net/projects/andyyan-gsi/)

---
*本文所有操作在一台小米多看电纸书 Pro 2 上完整验证（Android 11 / RK3566 / 无拆机 / 数据保留）。*
