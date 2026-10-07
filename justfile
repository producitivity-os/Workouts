set shell := ["zsh", "-cu"]

default:
    @just --list

generate:
    xcodegen generate

build-macos: generate
    xcodebuild -project Workouts.xcodeproj -scheme Workouts -configuration Debug -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath .build/xcode build CODE_SIGNING_ALLOWED=NO

test-macos: generate
    xcodebuild -project Workouts.xcodeproj -scheme Workouts -configuration Debug -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath .build/xcode test CODE_SIGNING_ALLOWED=NO

run-macos: build-macos
    ../../tools/apple-app.sh run-macos "$PWD" Workouts com.productivitysuite.workouts

install-macos: release-macos
    ../../tools/apple-app.sh install-macos "$PWD" Workouts com.productivitysuite.workouts

release-macos: generate
    xcodebuild -project Workouts.xcodeproj -scheme Workouts -configuration Release -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath .build/xcode build CODE_SIGNING_ALLOWED=NO

build-sim: generate
    ../../tools/apple-app.sh build-sim "$PWD" Workouts WorkoutsIOS com.productivitysuite.workouts.ios

test-sim: generate
    ../../tools/apple-app.sh test-sim "$PWD" Workouts WorkoutsIOS com.productivitysuite.workouts.ios

run-sim: generate
    ../../tools/apple-app.sh run-sim "$PWD" Workouts WorkoutsIOS com.productivitysuite.workouts.ios

build-device: generate
    ../../tools/apple-app.sh build-device "$PWD" Workouts WorkoutsIOS com.productivitysuite.workouts.ios

install-device: generate
    ../../tools/apple-app.sh install-device "$PWD" Workouts WorkoutsIOS com.productivitysuite.workouts.ios

run-device: generate
    ../../tools/apple-app.sh run-device "$PWD" Workouts WorkoutsIOS com.productivitysuite.workouts.ios

update-icon picture:
    Tools/update-app-icon.sh "{{picture}}"

icons:
    @echo "Lucide icons are bundled by packages/ProductivityUI"

build: build-macos
test: test-macos
run: run-macos
release: release-macos
