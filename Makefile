.PHONY: build clean

TARGET = $(shell pwd)/target
KEYFILE = fruit-apk-key.rsa
USER = fruitdev

ifeq ($(TARGET),)
	TARGET = $(shell pwd)/target
endif

ifeq ($(USER),root)
	USER = fruitdev
endif


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
	touch .prepare

build: .prepare
	su $(USER) -c 'mkdir -p $(TARGET)'
	for package in packages/*; do if [ -e $$package/APKBUILD ]; then su $(USER) -c "cd $$package && abuild -r -P $(TARGET)"; fi; done

clean:
	[ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ] && for package in packages/*; do if [ -e $$package/APKBUILD ]; then su $(USER) -c "cd $$package && abuild clean"; fi; done || true
	if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ]; then deluser $(USER); fi
	rm -rf .prepare $(TARGET)
	chown -R $$(id -u -n):$$(id -g -n) .

cleancache:
	for package in packages/*; do if [ -e $$package/APKBUILD ]; then cd $$package && abuild -F cleancache; fi; done
