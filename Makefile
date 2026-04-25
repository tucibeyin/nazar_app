DEFINES := --dart-define-from-file=dart_defines.json
FLUTTER  := cd mobile && flutter

.PHONY: run run-profile run-release build-apk build-ipa clean test analyze

run:
	$(FLUTTER) run $(DEFINES)

run-profile:
	$(FLUTTER) run --profile $(DEFINES)

run-release:
	$(FLUTTER) run --release $(DEFINES)

build-apk:
	$(FLUTTER) build apk --release $(DEFINES)

build-ipa:
	$(FLUTTER) build ipa --release $(DEFINES)

clean:
	$(FLUTTER) clean && $(FLUTTER) pub get

test:
	$(FLUTTER) test

analyze:
	$(FLUTTER) analyze
