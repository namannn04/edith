FLAGS := $(if $(PR),--pr $(PR)) $(if $(BRANCH),--branch $(BRANCH))

.PHONY: build install reset reinstall release loc ci ci-comments ci-lint ci-scripts ci-promo ci-swift ci-swift-check

ci:
	bun install --frozen-lockfile
	$(MAKE) ci-comments ci-lint ci-scripts ci-promo ci-swift-check

ci-comments:
	bun scripts/strip-comments.mjs --selftest
	bun scripts/strip-comments.mjs --check

ci-lint:
	bun run lint

ci-scripts:
	bun test ./scripts

ci-promo:
	cd apps/promo-video && npm ci && npx tsc --noEmit

ci-swift-check:
	cd apps/macos && swift format lint --strict --parallel --recursive Sources Tests Package.swift
	cd apps/macos && swift build
	cd apps/macos && ./test.sh

ci-swift: ci-swift-check
	cd apps/macos && ./build.sh --no-open
	test -f apps/macos/dist/Edith.app/Contents/MacOS/Edith
	test -f apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/MacOS/Edith
	test -f apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/Resources/AppIcon.icns
	/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/Info.plist | grep -qx Edith
	codesign --verify apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app
	codesign --verify apps/macos/dist/Edith.app

build:
	apps/macos/build.sh $(FLAGS)

install:
	apps/macos/build.sh --install $(FLAGS)

reset:
	apps/macos/reset.sh

reinstall: reset
	apps/macos/build.sh --install $(FLAGS)

release:
	@test -n "$(V)" || { echo "usage: make release V=1.8.0"; exit 1; }
	@BUILD=$$(( $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' apps/macos/Resources/Info.plist) + 1 )); \
	for p in apps/macos/Resources/Info.plist apps/macos/Resources/HelperInfo.plist; do \
	  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(V)" $$p; \
	  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$BUILD" $$p; \
	done
	@KEY=$$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' apps/macos/Resources/Info.plist 2>/dev/null); \
	test -n "$$KEY" || { echo "release blocked: set SUPublicEDKey in apps/macos/Resources/Info.plist"; exit 1; }
	@mkdir -p apps/macos/dist/appcast; \
	if command -v generate_appcast >/dev/null 2>&1; then \
	  generate_appcast apps/macos/dist/appcast; \
	else \
	  echo "Sparkle tools not found. Install them and generate apps/macos/dist/appcast/appcast.xml before uploading."; \
	fi
	git commit -m "Bump version to $(V)" apps/macos/Resources/Info.plist apps/macos/Resources/HelperInfo.plist
	git tag "v$(V)"
	git push origin HEAD "v$(V)"

loc:
	cloc --vcs=git
