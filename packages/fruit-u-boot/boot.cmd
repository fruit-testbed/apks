setenv kernel vmlinuz;
setenv ramdisk initramfs;
setenv boot_prefix /boot;
setenv env_file boot-root.env;
setenv env_addr_r ${fdt_addr_r};
if fatload mmc 0:1 ${env_addr_r} ${env_file};
then
	env import -t ${env_addr_r};
	if test "${root_dev}" = "/dev/mmcblk0p2";
	then
		setenv root_dev /dev/mmcblk0p3;
		setenv root_part "0:3";
	else
		setenv root_dev /dev/mmcblk0p2;
		setenv root_part "0:2";
	fi;
else
	setenv root_dev /dev/mmcblk0p2;
	setenv root_part "0:2";
fi;
mw ${env_addr_r} 0x20 0x100;
env export -t ${env_addr_r} root_dev;
fatwrite mmc 0:1 ${env_addr_r} ${env_file} 24;
setenv bootargs_default "8250.nr_uarts=1 console=ttyAMA0,115200 console=tty1 noquite panic=5 loglevel=7 dwc_otg.lpm_enable=0 root=${root_dev} rootfstype=ext4";
if fatload mmc 0:1 ${env_addr_r} nooverlaytmpfs;
then
	setenv bootargs ${bootargs_default};
else
	setenv bootargs "${bootargs_default} overlaytmpfs";
fi;
ext4load mmc ${root_part} ${kernel_addr_r} ${boot_prefix}/${kernel};
ext4load mmc ${root_part} ${ramdisk_addr_r} ${boot_prefix}/${ramdisk};
echo "set root_dev=${root_dev}";
echo "set bootargs=${bootargs}";
sleep 2;
if bootz ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr};
then
	true;
else
	echo "Failed to boot Linux kernel root_dev=${root_dev}";
	echo "The system will reboot in 5 seconds";
	sleep 5;
	reset;
fi;
