.PHONY: get clean run run-chrome run-android apk appbundle web web-serve

get:
	flutter pub get

clean:
	flutter clean
	flutter pub get

run:
	flutter run

run-chrome:
	flutter run -d chrome

run-android:
	flutter run -d android

apk:
	flutter build apk --release

appbundle:
	flutter build appbundle --release

web:
	flutter build web --release

web-serve: web
	python3 -m http.server 5500 --directory build/web
