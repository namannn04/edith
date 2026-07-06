FLAGS := $(if $(PR),--pr $(PR)) $(if $(BRANCH),--branch $(BRANCH))

.PHONY: build reset reinstall loc

build:
	apps/macos/build.sh $(FLAGS)

reset:
	apps/macos/reset.sh

reinstall: reset
	apps/macos/build.sh --install $(FLAGS)

loc:
	cloc --vcs=git
