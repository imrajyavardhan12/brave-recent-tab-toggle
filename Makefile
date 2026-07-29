.PHONY: build check doctor install lint package test uninstall

build:
	swift build --package-path native --configuration release --product recent-tab-toggle-host

check:
	npm run check:extension

test:
	npm test

doctor:
	./scripts/doctor.sh

lint:
	./scripts/lint.sh

install:
	./scripts/install.sh

uninstall:
	./scripts/uninstall.sh

package:
	./scripts/package-extension.sh
