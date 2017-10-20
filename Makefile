.PHONY: build clean

TARGET = target
KEYFILE = fruit-apk-key.rsa
USER = fruitdev

ifeq ($(TARGET),)
	TARGET = target
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
	su $(USER) -c 'abuild-keygen -a -n'
	chown -R $(USER):$(USER) .
	touch .prepare

build: .prepare
	su $(USER) -c 'mkdir -p $(TARGET)'
	for package in packages/*; do if [ -e $$package/APKBUILD ]; then su $(USER) -c "cd $$package && abuild -r"; fi; done

clean:
	for package in packages/*; do if [ -e $$package/APKBUILD ]; then su $(USER) -c "cd $$package && abuild clean"; fi; done
	if [ $$(grep $(USER) /etc/passwd | wc -l) -ne 0 ]; then deluser $(USER); fi
	rm -rf .prepare $(TARGET)
