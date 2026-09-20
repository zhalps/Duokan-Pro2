小米多看电纸书 Pro 2 Root 教程：无官方固件、无拆机（墨案系 RK3566 通用思路）
  - 适配机型：小米多看电纸书 Pro 2（Moaan MiDuoKanReader Pro II / RK3566 / Android 11）
  - 同思路适用：墨案系电纸书（多看一代 / Pro / inkPalm 5 / inkPad / Mix 7 等），
只需按本文"第四步·GSI 架构"一节换成你自己设备的架构
  - 特点：不需要官方固件包、不需要拆机短接、不改任何 bootloader 分区，
利用 Android 自带的 DSU（动态系统更新） 临时启动一个带 root 的系统来提取 boot 镜像
  - 作者环境：Windows 11 + adb；全程一根 USB 线
