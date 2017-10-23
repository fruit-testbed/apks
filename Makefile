.PHONY: build sign clean

TARGET = $(shell pwd)/target
KEYFILE = $(shell pwd)/fruit-apk-key.rsa
USER = fruitdev
ARCH = armhf
CACHE = $(shell pwd)/cache

PACKAGES = \
	fruit-boot-conf.apk \
	fruit-keys.apk \
	rpi-boot-linux.apk \
	rpi2-boot-linux.apk \
	rpi-kernel-modules.apk \
	rpi2-kernel-modules.apk \
	alpine-base.apk \
	tzdata.apk \
	kbd-bkeymaps.apk \
	wireless-tools.apk \
	wpa_supplicant.apk \
	openssh.apk \
	openssh-server.apk \
	curl.apk \
	dnsmasq.apk \
	nfs-utils.apk \
	qemu.apk \
	docker.apk \
	openvpn.apk \
	btrfs-progs.apk \
	parted.apk \
	singularity.apk \
	bash.apk \
	python.apk \
	e2fsprogs.apk \
	abuild.apk \
	sfdisk.apk \
	raspberrypi.apk \
	fruit-base.apk \


ifeq ($(TARGET),)
	TARGET = $(shell pwd)/target
endif

ifeq ($(USER),root)
	USER = fruitdev
endif


build: sign

.prepare:
	apk update
	apk upgrade
	apk add alpine-sdk
	adduser -D $(USER)
	echo "$(USER)  ALL=(ALL) ALL" >> /etc/sudoers; \
	addgroup $(USER) abuild
	mkdir -p /var/cache/distfiles
	chmod a+w /var/cache/distfiles
	chown -R $(USER):$(USER) .
	mkdir -p /home/$(USER)/.abuild/
	cp -f $(KEYFILE) /home/$(USER)/.abuild/
	chmod 0400 /home/$(USER)/.abuild/$$(basename $(KEYFILE))
	chown $(USER):$(USER) /home/$(USER)/.abuild/$$(basename $(KEYFILE))
	echo "PACKAGER_PRIVKEY=/home/fruitdev/.abuild/$$(basename $(KEYFILE))" > /home/$(USER)/.abuild/abuild.conf
	su $(USER) -c 'mkdir -p $(TARGET)'
	if [ "$(CACHE)" != "" ]; then \
		mkdir -p $(CACHE); \
		mkdir -p $(CACHE).workdir; \
		mount -t overlay -o lowerdir=/var/cache/distfiles,upperdir=$(CACHE),workdir=$(CACHE).workdir overlay /var/cache/distfiles; \
	fi
	touch .prepare

$(TARGET): .prepare $(PACKAGES)

%.apk: .prepare
	if [ -e packages/$*/APKBUILD ]; then \
		su $(USER) -c "cd packages/$* && abuild -r -P $(TARGET)"; \
	else \
		apk fetch -o $(TARGET)/packages/$(ARCH) -R $*; \
	fi

sign: $(TARGET)
	rm -f $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz
	cd $(TARGET)/packages/$(ARCH) && apk index -o APKINDEX.tar.gz --rewrite-arch $(ARCH) *.apk
	abuild-sign -k $(KEYFILE) $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz

clean:
	if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ]; then \
		for package in packages/*; do \
			if [ -e $$package/APKBUILD ]; then \
				su $(USER) -c "cd $$package && abuild clean"; \
			fi; \
		done; \
	fi
	if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ]; then \
		deluser $(USER); \
	fi
	if [ -e /etc/sudoers ]; then \
		sed -i 's/^$(USER).*$$//' /etc/sudoers; \
	fi
	if [ $$(mount | grep ' on /var/cache/distfiles ' | wc -l) -ne 0 ]; then \
		umount -f /var/cache/distfiles; \
	fi
	chown -R $$(id -u -n):$$(id -g -n) .
	rm -f .prepare

cleantarget:
	rm -rf $(TARGET)

cleancache:
	for package in packages/*; do \
		if [ -e $$package/APKBUILD ]; then \
			cd $$package && abuild -F cleancache; \
		fi; \
	done

cleanall: clean cleantarget cleancache
