.PHONY: build sign clean

TARGET = $(shell pwd)/target
KEYFILE ?= $(shell pwd)/fruit-apk-key.rsa
USER = fruitdev
ARCH ?= $(shell apk --print-arch)

SSH_KEY_FILE = $(shell echo $$HOME)/.ssh/id_rsa
RSYNC_SOURCE_DIR = $(TARGET)/packages/$(ARCH)/
RSYNC_DEST_DIR = fruitos/edge/main/$(ARCH)/
RSYNC_TESTING_DIR = fruitos/edge/testing/$(ARCH)/
RSYNC_USER = fruit
RSYNC_HOST = fruit-testbed.org


PACKAGES = \
	fruit-rpi-bootloader.apk \
	fruit-rpi-linux.apk \
	rpi-firmware.apk \
	rpi-devicetree.apk \
	uboot-tools.apk \
	fruit-initramfs.apk \
	fruit-u-boot.apk \
	fruit-keys.apk \
	fruit-baselayout.apk \
	overlayfs-tools.apk \
	fruit-agent.apk \
	apk-repositories.apk \
	py-serial.apk \
	py3-pistack.apk \

ifeq ($(ARCH),armhf)
	PACKAGES := $(PACKAGES) \
		fruit-rpi2-linux.apk
endif

ifeq ($(TARGET),)
	TARGET = $(shell pwd)/target
endif

ifeq ($(USER),root)
	USER = fruitdev
endif


build: $(PACKAGES) sign

rsync: $(SOURCE_DIR)
	rsync -avz --delete --progress \
		-e "ssh -i $(SSH_KEY_FILE) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
		$(RSYNC_SOURCE_DIR) "$(RSYNC_USER)@$(RSYNC_HOST):$(RSYNC_DEST_DIR)"

rsync.testing: $(SOURCE_DIR)
	rsync -avz --delete --progress \
		-e "ssh -i $(SSH_KEY_FILE) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
		$(RSYNC_SOURCE_DIR) "$(RSYNC_USER)@$(RSYNC_HOST):$(RSYNC_TESTING_DIR)"

overlay:
	mkdir -p .distfiles .distfiles.workdir /var/cache/distfiles && \
		mount -t overlay -o lowerdir=/var/cache/distfiles,upperdir=.distfiles,workdir=.distfiles.workdir overlay /var/cache/distfiles
	mkdir -p .usr .usr.workdir && \
		mount -t overlay -o lowerdir=/usr,upperdir=.usr,workdir=.usr.workdir overlay /usr
	mkdir -p .fruitdev .fruitdev.workdir /home/fruitdev && \
		mount -t overlay -o lowerdir=/home/fruitdev,upperdir=.fruitdev,workdir=.fruitdev.workdir overlay /home/fruitdev
	mkdir -p .tmp .tmp.workdir && \
		mount -t overlay -o lowerdir=/tmp,upperdir=.tmp,workdir=.tmp.workdir overlay /tmp && \
		chmod 1777 /tmp

clean.overlay:
	[ "$$(mount | grep ' on /usr ')" = "" ] || umount -f /usr
	[ "$$(mount | grep ' on /var/cache/distfiles ')" = "" ] || umount -f /var/cache/distfiles
	[ "$$(mount | grep ' on /home/fruitdev ')" = "" ] || umount -f /home/fruitdev
	rm -rf .distfiles .distfiles.workdir .usr .usr.workdir .fruitdev .fruitdev.workdir

.prepare:
	apk update && apk upgrade && apk add alpine-sdk rsync
	adduser -s /bin/sh -D $(USER) && \
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
	addgroup $(shell id -un) abuild
	mkdir -p /var/cache/distfiles && chmod a+w /var/cache/distfiles
	touch .prepare
	@if [ "$$(id | grep '(abuild)')" = "" ]; then \
		echo "$$(id -un) is not belong to group abuild. Please logout and login again!"; \
		exit 1; \
	fi

$(TARGET): .prepare $(PACKAGES)

%.apk: .prepare
	@if [ -e packages/$*/APKBUILD ]; then \
		echo "Building $*..."; \
		cd packages/$* && abuild -F -P $(TARGET) deps && su $(USER) -c "abuild -P $(TARGET)"; \
	else \
		echo "Fetching $*..."; \
		apk fetch -o $(TARGET)/packages/$(ARCH) -R $*; \
	fi

%.checksum: .prepare
	cd packages/$* && su $(USER) -c 'abuild checksum'

sign:
	rm -f $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz
	cd $(TARGET)/packages/$(ARCH) && apk index -o APKINDEX.tar.gz --rewrite-arch $(ARCH) *.apk
	abuild-sign -q -k $(KEYFILE) $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz

tgz:
	cd $(TARGET)/ && tar cvzf fruit-apks.tar.gz packages


clean.packages:
	@if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ] && [ -e /usr/bin/abuild ]; then \
		for package in packages/*; do \
			if [ -e $$package/APKBUILD ]; then \
				echo "Cleaning $$package..."; \
				su $(USER) -c "cd $$package && abuild clean"; \
			fi; \
		done; \
	fi

clean: clean.packages
	@[ "$$(grep $(USER) /etc/passwd)" = "" ] || deluser $(USER)
	@[ ! -e /etc/sudoers ] || sed -i 's/^$(USER).*$$//' /etc/sudoers
	@[ "$$(mount | grep ' on /var/cache/distfiles ')" = "" ] || umount -f /var/cache/distfiles
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
	@rm -rf /var/cache/distfiles/*

clean.%:
	@if [ -e packages/$* ]; then \
		echo "Cleaning $*..."; \
		cd packages/$* && abuild -F clean && abuild -F cleancache; \
	else \
		echo "Package $* does not exist"; \
	fi

cleanapks:
	rm -f $(TARGET)/fruit-apks.tar.gz

cleanall: clean cleantarget cleancache cleanapks
