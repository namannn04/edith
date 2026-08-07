FLAGS := $(if $(PR),--pr $(PR)) $(if $(BRANCH),--branch $(BRANCH))

.PHONY: build install reset reinstall release loc ci ci-comments ci-secrets ci-lint ci-scripts ci-site ci-promo ci-swift ci-swift-check site-dev cli

ci:
	bun install --frozen-lockfile
	$(MAKE) ci-comments ci-secrets ci-lint ci-scripts ci-site ci-promo ci-swift

site-dev:
	cd apps/site && python3 -m http.server 8000

cli:
	cd apps/macos && swift build -c release --product ed --product edh
	apps/macos/.build/release/ed install --directory $(HOME)/.local/bin
	apps/macos/.build/release/ed completions install

ci-comments:
	bun scripts/strip-comments.mjs --selftest
	bun scripts/strip-comments.mjs --check

ci-secrets:
	bun run check-secrets

ci-lint:
	bun run lint

ci-scripts:
	bun test ./scripts

ci-site:
	test -f apps/site/index.html
	test -f apps/site/CNAME
	grep -qx edith.pulkit.page apps/site/CNAME
	@! grep -rhoE '(src|href)="https?://[^"]+' apps/site/*.html \
	  | grep -vE 'https://(github\.com|www\.gnu\.org|docs\.github\.com|edith\.pulkit\.page)' \
	  || { echo "site references an unexpected external origin" >&2; exit 1; }
	@cd apps/site && rc=0; \
	  for ref in $$(grep -rhoE '(src|href)="/[^"#]*' ./*.html | cut -d'"' -f2); do \
	    test -e ".$$ref" || { echo "missing: $$ref" >&2; rc=1; }; \
	  done; \
	  exit $$rc

ci-promo:
	cd apps/promo-video && npm ci && npx tsc --noEmit

ci-swift-check:
	cd apps/macos && swift format lint --strict --parallel --recursive Sources Tests Package.swift
	cd apps/macos && swift build
	cd apps/macos && ./test.sh

ci-swift: ci-swift-check
	cd apps/macos && ./build.sh --no-open
	test -f apps/macos/dist/Edith.app/Contents/MacOS/Edith
	test -x apps/macos/dist/Edith.app/Contents/MacOS/ed
	test -x apps/macos/dist/Edith.app/Contents/MacOS/edh
	test -f apps/macos/dist/Edith.app/Contents/Resources/Edith_EdithKit.bundle/claude.svg
	test -f apps/macos/dist/Edith.app/Contents/Resources/Edith_EdithKit.bundle/codex.svg
	test -f apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/MacOS/Edith
	test -f apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/Resources/AppIcon.icns
	test -f apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/Resources/Edith_EdithKit.bundle/claude.svg
	test -f apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/Resources/Edith_EdithKit.bundle/codex.svg
	test -z "$$(find apps/macos/dist/Edith.app -print | grep Helper)"
	/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/Info.plist | grep -qx Edith
	@for plist in apps/macos/dist/Edith.app/Contents/Info.plist apps/macos/dist/Edith.app/Contents/Library/LoginItems/Edith.app/Contents/Info.plist; do \
	  for field in CFBundleName CFBundleDisplayName; do \
	    /usr/libexec/PlistBuddy -c "Print :$$field" "$$plist" | grep -q Helper \
	      && { echo "$$plist $$field mentions Helper" >&2; exit 1; }; \
	  done; \
	done; exit 0
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
	@set -eu; \
	test -n "$(V)" || { echo "release blocked: set V, for example make release V=1.8.0" >&2; exit 1; }; \
	command -v gh >/dev/null 2>&1 || { echo "release blocked: gh CLI is not installed" >&2; exit 1; }; \
	gh auth status >/dev/null 2>&1 || { echo "release blocked: gh CLI is not authenticated" >&2; exit 1; }; \
	KEY=$$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' apps/macos/Resources/Info.plist 2>/dev/null || true); \
	test -n "$$KEY" || { echo "release blocked: set SUPublicEDKey in apps/macos/Resources/Info.plist" >&2; exit 1; }; \
	if command -v generate_appcast >/dev/null 2>&1; then \
	  GENERATE_APPCAST=$$(command -v generate_appcast); \
	elif test -x apps/macos/.build/artifacts/sparkle/Sparkle/bin/generate_appcast; then \
	  GENERATE_APPCAST=apps/macos/.build/artifacts/sparkle/Sparkle/bin/generate_appcast; \
	else \
	  echo "release blocked: generate_appcast is not on PATH or at apps/macos/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" >&2; \
	  exit 1; \
	fi; \
	BUILD=$$(( $$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' apps/macos/Resources/Info.plist) + 1 )); \
	for p in apps/macos/Resources/Info.plist apps/macos/Resources/HelperInfo.plist; do \
	  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(V)" $$p; \
	  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $$BUILD" $$p; \
	done; \
	git commit -m "Bump version to $(V)" apps/macos/Resources/Info.plist apps/macos/Resources/HelperInfo.plist; \
	git tag "v$(V)"; \
	(cd apps/macos && ./build.sh --no-open --release); \
	rm -rf apps/macos/dmg-root; \
	rm -f apps/macos/Edith.dmg; \
	mkdir apps/macos/dmg-root; \
	cp -R apps/macos/dist/Edith.app apps/macos/dmg-root/; \
	ln -s /Applications apps/macos/dmg-root/Applications; \
	hdiutil create -volname Edith -srcfolder apps/macos/dmg-root -format UDZO apps/macos/Edith.dmg; \
	rm -rf apps/macos/dmg-root; \
	rm -rf apps/macos/dist/appcast; \
	mkdir apps/macos/dist/appcast; \
	cp apps/macos/Edith.dmg apps/macos/dist/appcast/; \
	"$$GENERATE_APPCAST" \
	  --download-url-prefix "https://github.com/pulkitxm/edith/releases/download/v$(V)/" \
	  apps/macos/dist/appcast; \
	test -f apps/macos/dist/appcast/appcast.xml || mv apps/macos/dist/appcast/appcast apps/macos/dist/appcast/appcast.xml; \
	test -f apps/macos/dist/appcast/appcast.xml || { echo "release blocked: generate_appcast did not create apps/macos/dist/appcast/appcast.xml" >&2; exit 1; }; \
	grep -q 'url="https://github.com/pulkitxm/edith/releases/download/v$(V)/Edith.dmg"' apps/macos/dist/appcast/appcast.xml \
	  || { echo "release blocked: appcast enclosure does not point at the v$(V) release asset" >&2; exit 1; }; \
	git push origin HEAD "v$(V)"; \
	gh release create "v$(V)" --title "Edith v$(V)" --generate-notes \
	  apps/macos/Edith.dmg \
	  apps/macos/dist/appcast/appcast.xml \
	|| gh release upload "v$(V)" --clobber \
	  apps/macos/Edith.dmg \
	  apps/macos/dist/appcast/appcast.xml

loc:
	cloc --vcs=git
