# 编辑中

# PiKVM_Prebuild_image_NanoPi-Neo

这是一个NanoPi Neo的预构建镜像，该镜像可以让Pikvm运行在NanoPi Neo上。

[PiKVM](https://github.com/pikvm/pikvm)是一个基于树莓派的开源、低成本的IP-KVM系统。不同于向日葵、teamviewer、Todesk这类远程控制软件，他可以实现硬件层的远程控制管理各类设备。  

当然这些年树莓派4B成为理财产品，便有了在各类便宜的ARM开发板上运行pikvm的需求。  

感谢[xe5700](https://github.com/xe5700)、[srepac](https://github.com/srepac)等大佬的开发移植，项目[kvmd-armbian](https://github.com/srepac/kvmd-armbian)已经实现在Allwinner全志, Amlogic晶晨以及Rockchip瑞芯微为核心的电视盒子以及开发板上运行PiKVM。  

而我曾尝试在Nanopi NEO上刷入Armbian官网提供的[Armbian 23.02 Jammy镜像](https://www.armbian.com/nanopi-neo/)，并运行[kvmd-armbian](https://github.com/srepac/kvmd-armbian)时，因kernel版本太低而缺少forced_eject功能，会导致[MSD](https://docs.pikvm.org/msd/)功能异常，导致无法虚拟U盘/镜像的。  

但是我惊喜的发现Armbian在GitHub上的编译工具[build](https://github.com/armbian/build)已经修复了kernel缺少forced_eject功能的问题,于是我很没技术水平的用GitHub Action编译Armbian固件，并在编译的同时集成了大部分[kvmd-armbian](https://github.com/srepac/kvmd-armbian)的大部分依赖，可以有效加快脚本的安装流程。  

这个镜像的优点：
1. 大幅减少脚本的安装时间。（受限于国内网络和NEO的机能，能将1-2小时的安装时间控制在5-10min）
2. 支持MSD功能。
3. 避免在256m内存的NanoPi NEO安装失败的问题（内存不足导致安装失败，但是PiKVM可以直接在256m内存上运行）
4. 想不到，吹不下去了....

当然能力有限，还是做不到刷入即用，还需要手动执行些步骤。  

## 使用步骤  

### 刷入镜像  
前往[发布页](https://github.com/Road-tech/PiKVM_Prebuild_image_NanoPi-Neo/releases)下载镜像，并用[Etcher](https://etcher.balena.io/)刷入镜像。  
如果您不需要使用MSD功能，可直接开机并跳至->步骤[安装Pikvm](#安装Pikvm)，如果需要请留意下一步。  

### 占用分区
因为MSD需要单独的一个分区用于存放镜像文件，而系统第一次启动后会自动扩展分区占用完所有的TF卡空间。当分区扩展完后再压缩就很困难了，所以启动前先使用磁盘分区工具把剩余的空间占用好，避免Armbian的自动扩展。  
我在Windows下使用的是[DiskGenius](https://www.diskgenius.cn/)，镜像刷入TF后大概占用2.3G的样子,把剩余的空间设定为扩展就行了，然后激活主分区就行了。不用担心容量分配不合理，我们会在下一步调整。  

### 插电开机  
第一次启动默认账户为`root`，密码为`1234`。进入系统后会让你设定新密码以及System command shell。  
在让你设置新的用户账户时即可`Ctrl+C`退出。  

配图1

### 调整MSD分区
查看分区信息
```fidsk -l```
调整分区大小
```cfdisk /dev/mmcblk0```
重建主分区空间
```resize2fs /dev/mmcblk0p1```
格式化MSD分区
```mkfs -t ext4 /dev/mmcblk0p2```

### 安装Pikvm

```cd kvmd-armbian && ./install.sh```
安装分两部分，Part1安装完成后会重启一次，需再次执行以上命令完成Part2安装.  

### 挂载MSD分区
编辑文件  
```vi /etc/fstab```
在文件最下方新增一行，补充下面内容  
```/dev/mmcblk0p2  /var/lib/kvmd/msd   ext4  nodev,nosuid,noexec,ro,errors=remount-ro,data=journal,X-kvmd.otgmsd-root=/var/lib/kvmd/msd,X-kvmd.otgmsd-user=kvmd  0  0```
挂载分区  
``` mount -a```

### 开启PiKVM的MSD功能
编辑文件  
```/etc/kvmd/override.yaml```
删除以下内容  

重启PiKVM或者NanoPi NEO     
`systemctl restart kvmd` 或 `reboot`  
