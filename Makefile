.PHONY: build sign clean

TARGET = $(shell pwd)/target
KEYFILE = $(shell pwd)/fruit-apk-key.rsa
USER = fruitdev
ARCH = armhf

PACKAGES = \
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
	raspberrypi \


ifeq ($(TARGET),)
	TARGET = $(shell pwd)/target
endif

ifeq ($(USER),root)
	USER = fruitdev
endif


build: sign

.prepare:
	apk update
	apk add alpine-sdk
	adduser -D $(USER)
	echo "$(USER)  ALL=(ALL) ALL" >> /etc/sudoers
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
	[ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ] && for package in packages/*; do if [ -e $$package/APKBUILD ]; then su $(USER) -c "cd $$package && abuild clean"; fi; done || true
	if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ]; then deluser $(USER); fi
	rm -rf .prepare $(TARGET)
	chown -R $$(id -u -n):$$(id -g -n) .

cleancache:
	for package in packages/*; do if [ -e $$package/APKBUILD ]; then cd $$package && abuild -F cleancache; fi; done
