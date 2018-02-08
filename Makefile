.PHONY: build sign clean

TARGET = $(shell pwd)/target
KEYFILE = $(shell pwd)/fruit-apk-key-20170922.rsa
USER = fruitdev
ARCH = armhf


PACKAGES = \
	fruit-rpi-bootloader.apk \
	fruit-rpi-linux.apk \
	fruit-rpi2-linux.apk \
	rpi-firmware.apk \
	uboot-tools.apk \
	fruit-initramfs.apk \
	fruit-u-boot.apk \
	fruit-keys.apk \
	fruit-baselayout.apk \
	fruit-agent.apk \
	singularity.apk \
	openvpn.apk \


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

clean.overlay:
	[ "$$(mount | grep ' on /usr ')" = "" ] || umount -f /usr
	[ "$$(mount | grep ' on /var ')" = "" ] || umount -f /var
	[ "$$(mount | grep ' on /etc ')" = "" ] || umount -f /etc
	rm -rf .cache .cache.workdir .usr .usr.workdir .etc .etc.workdir

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

sign: $(TARGET)
	rm -f $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz
	cd $(TARGET)/packages/$(ARCH) && apk index -o APKINDEX.tar.gz --rewrite-arch $(ARCH) *.apk
	abuild-sign -q -k $(KEYFILE) $(TARGET)/packages/$(ARCH)/APKINDEX.tar.gz

tgz:
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
