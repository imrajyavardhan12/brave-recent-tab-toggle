.PHONY: build check install package test uninstall

build:
	swift build --package-path native --configuration release --product recent-tab-toggle-host

check:
	npm run check:extension

test:
	npm test

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

package:
	./scripts/package-extension.sh
