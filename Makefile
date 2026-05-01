DEFINES := --dart-define-from-file=dart_defines.json
SYMBOLS := --split-debug-info=build/app/outputs/symbols
FLUTTER := cd mobile && flutter
DART    := cd mobile && dart

.PHONY: run run-profile run-release \
        build-apk build-ipa \
        clean fix analyze test \
        release-check

# ── Geliştirme ───────────────────────────────────────────────────────────────

run:
	$(FLUTTER) run $(DEFINES)

run-profile:
	$(FLUTTER) run --profile $(DEFINES)

run-release:
	$(FLUTTER) run --release --obfuscate $(SYMBOLS) $(DEFINES)

# ── Release Build ─────────────────────────────────────────────────────────────

build-apk:
	$(FLUTTER) build apk --release --obfuscate $(SYMBOLS) $(DEFINES)

build-ipa:
	$(FLUTTER) build ipa --release --obfuscate $(SYMBOLS) $(DEFINES)

# ── Kalite Kontrol ───────────────────────────────────────────────────────────

fix:
	$(DART) fix --apply

analyze:
	$(FLUTTER) analyze --no-fatal-infos

test:
	$(FLUTTER) test

clean:
	$(FLUTTER) clean && $(FLUTTER) pub get

# ── Release Kontrolü (deploy öncesi çalıştır) ─────────────────────────────────
# Sırasıyla: temizlik → otomatik düzeltme → analiz → testler

release-check: clean fix analyze test
	@echo ""
	@echo "✓ Release kontrolü tamamlandı — build-apk veya build-ipa çalıştırabilirsin."
