.PHONY: setup run test

# One command from a clean clone to a running app. See README "How to run".
setup:
	flutter pub get
	dart run build_runner build --delete-conflicting-outputs
	flutter gen-l10n

run: setup
	flutter run

test: setup
	flutter test
