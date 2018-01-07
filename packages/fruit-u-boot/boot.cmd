echo "=== Setting environment variables ===";
setenv kernel vmlinuz;
setenv ramdisk initramfs;
setenv boot_prefix /boot;
setenv env_file boot-root.env;
setenv env_addr_r ${fdt_addr_r};
echo "=== Loading boot root device from boot-root.env ===";
if fatload mmc 0:1 ${env_addr_r} ${env_file};
then
	env import -t ${env_addr_r};
	if test "${root_dev}" = "/dev/mmcblk0p2";
	then
		echo "=== Setting /dev/mmcblk0p3 as root ===";
		setenv root_dev /dev/mmcblk0p3;
		setenv root_part "0:3";
	else
		echo "=== Setting /dev/mmcblk0p2 as root ===";
		setenv root_dev /dev/mmcblk0p2;
		setenv root_part "0:2";
	fi;
else
	echo "=== Failed reading boot-root.env, setting /dev/mmcblk0p2 as root ===";
	setenv root_dev /dev/mmcblk0p2;
	setenv root_part "0:2";
fi;
echo "=== Saving boot root device to boot-root.env ===";
mw ${env_addr_r} 0x20 0x100;
env export -t ${env_addr_r} root_dev;
fatwrite mmc 0:1 ${env_addr_r} ${env_file} 24;
echo "=== Setting boot arguments ===";
setenv bootargs_default "8250.nr_uarts=1 console=ttyAMA0,115200 console=tty1 cgroup_enable=cpuset noquite panic=5 loglevel=7 dwc_otg.lpm_enable=0 root=${root_dev} rootfstype=ext4";
if fatload mmc 0:1 ${env_addr_r} nooverlaytmpfs;
then
	setenv bootargs ${bootargs_default};
else
	setenv bootargs "${bootargs_default} overlaytmpfs";
fi;
echo "=== Loading kernel and initramfs ===";
ext4load mmc ${root_part} ${kernel_addr_r} ${boot_prefix}/${kernel};
ext4load mmc ${root_part} ${ramdisk_addr_r} ${boot_prefix}/${ramdisk};
echo "=== Booting the kernel ===";
echo "set root_dev=${root_dev}";
echo "set bootargs=${bootargs}";
sleep 2;
if bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr};
then
	true;
else
	echo "=== ERROR: Failed to boot Linux kernel root_dev=${root_dev} ===";
	echo "=== The system will reboot in 5 seconds ===";
	sleep 5;
	reset;
fi;
