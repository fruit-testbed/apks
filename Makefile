.PHONY: build sign clean

TARGET = $(shell pwd)/target
KEYFILE = $(shell pwd)/fruit-apk-key.rsa
USER = fruitdev
ARCH = armhf

PACKAGES = \
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
	util-linux.apk \
	raspberrypi.apk \
	mkinitfs.apk \
	\
	rpi-boot-linux.apk \
	rpi2-boot-linux.apk \
	rpi-firmware.apk \
	\
	fruit-keys.apk \
	fruit-base.apk \


ifeq ($(TARGET),)
	TARGET = $(shell pwd)/target
endif

ifeq ($(USER),root)
	USER = fruitdev
endif


build: sign

overlay:
	mkdir -p .cache .cache.workdir /var/cache/distfiles && \
		mount -t overlay -o lowerdir=/var/cache/distfiles,upperdir=.cache,workdir=.cache.workdir overlay /var/cache/distfiles
	mkdir -p .usr .usr.workdir && \
		mount -t overlay -o lowerdir=/usr,upperdir=.usr,workdir=.usr.workdir overlay /usr
	mkdir -p .etc .etc.workdir && \
		mount -t overlay -o lowerdir=/etc,upperdir=.etc,workdir=.etc.workdir overlay /etc

.prepare:
	apk update && apk upgrade && apk add alpine-sdk
	adduser -D $(USER) && \
		echo "$(USER)  ALL=(ALL) ALL" >> /etc/sudoers && \
		addgroup $(USER) abuild && \
		chown $(USER):$(USER) . && \
		chown $(USER):$(USER) -R packages && \
		mkdir -p /home/$(USER)/.abuild/ && \
		cp -f $(KEYFILE) /home/$(USER)/.abuild/ && \
		chmod 0400 /home/$(USER)/.abuild/$$(basename $(KEYFILE)) && \
		chown $(USER):$(USER) /home/$(USER)/.abuild/$$(basename $(KEYFILE)) && \
		echo "PACKAGER_PRIVKEY=/home/fruitdev/.abuild/$$(basename $(KEYFILE))" > /home/$(USER)/.abuild/abuild.conf && \
		mkdir -p $(TARGET)/packages/$(ARCH) && \
		chown -R $(USER):$(USER) $(TARGET)
	mkdir -p /var/cache/distfiles && chmod a+w /var/cache/distfiles
	touch .prepare

$(TARGET): .prepare $(PACKAGES)

%.apk: .prepare
	@echo "Building $*..."
	@if [ -e packages/$*/APKBUILD ]; then \
		cd packages/$* && abuild -F deps && su $(USER) -c "abuild -P $(TARGET)"; \
	else \
		apk fetch -o $(TARGET)/packages/$(ARCH) -R $*; \
	fi

sign: $(TARGET)
	rm -f $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz
	cd $(TARGET)/packages/$(ARCH) && apk index -o APKINDEX.tar.gz --rewrite-arch $(ARCH) *.apk
	abuild-sign -q -k $(KEYFILE) $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz

apks:
	cd $(TARGET)/ && tar cvzf fruit-apks.tar.gz packages


clean:
	@if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ] && [ -e /usr/bin/abuild ]; then \
		for package in packages/*; do \
			if [ -e $$package/APKBUILD ]; then \
				echo "Cleaning $$package..."; \
				su $(USER) -c "cd $$package && abuild clean"; \
			fi; \
		done; \
	fi
	@if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ]; then \
		deluser $(USER); \
	fi
	@if [ -e /etc/sudoers ]; then \
		sed -i 's/^$(USER).*$$//' /etc/sudoers; \
	fi
	@if [ $$(mount | grep ' on /var/cache/distfiles ' | wc -l) -ne 0 ]; then \
		umount -f /var/cache/distfiles; \
	fi
	@chown -R $$(id -u -n):$$(id -g -n) .
	rm -f .prepare

cleantarget:
	rm -rf $(TARGET)

cleancache:
	@if [ -e /usr/bin/abuild ]; then \
		for package in packages/*; do \
			if [ -e $$package/APKBUILD ]; then \
				echo "Cleaning cache of $$package..."; \
				cd $$package && abuild -F cleancache; \
			fi; \
		done; \
	fi

cleanapks:
	rm -f $(TARGET)/fruit-apks.tar.gz

cleanall: clean cleantarget cleancache cleanapks
