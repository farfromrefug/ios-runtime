#!/usr/bin/env bash

set -e

source "$(dirname "$0")/common.sh"
CONFIGURATION="Release"
MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:=10.13}

WEBKIT_SOURCE_PATH="$WORKSPACE/src/webkit"
WEBKIT_BUILD_OUTPUT_PATH="$WORKSPACE/cmake-build/WebKit-Xcode"
BUILD_DIR="$WORKSPACE/build"

INSPECTOR_SOURCE_PATH="$WORKSPACE/src/debugging/Inspector/Inspector"
INSPECTOR_BUILD_OUTPUT_PATH="$WORKSPACE/cmake-build/Inspector"

checkpoint "Inspector build started"

checkpoint "Building WebKit"

CCACHE_ARGS=""
if type -p ccache >/dev/null 2>&1; then
    ./cmake-gen.sh
    CCACHE_ARGS="CXX=$PWD/cmake-build/launch-cxx CC=$PWD/cmake-build/launch-c"
fi


xcodebuild \
    -workspace "$WEBKIT_SOURCE_PATH/WebKit.xcworkspace" \
    -configuration "$CONFIGURATION" \
    -scheme "All Source" \
    -derivedDataPath "$WEBKIT_BUILD_OUTPUT_PATH" \
    $CCACHE_ARGS \
    VALID_ARCHS="x86_64" ARCHS="x86_64" ONLY_ACTIVE_ARCH="NO" \
    MACOSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
    OTHER_CFLAGS='$(inherited) -Wno-unguarded-availability-new -Wno-availability' \
    build \
    -quiet
# Suppress unguarded-availability-new warnings to be able to build for High Sierra:
# CompileC /Users/bektchiev/work/ios-runtime-2/cmake-build/WebKit-Xcode/Build/Intermediates.noindex/MiniBrowser.build/Release/MiniBrowser.build/Objects-normal/x86_64/AppDelegate.o mac/AppDelegate.m normal x86_64 objective-c com.apple.compilers.llvm.clang.1_0.compiler
# mac/AppDelegate.m:105:34: error: 'setProcessSwapsOnNavigation:' is only available on macOS 10.14 or newer [-Werror,-Wunguarded-availability-new]
#             processConfiguration.processSwapsOnNavigation = true;
#                                  ^~~~~~~~~~~~~~~~~~~~~~~~



# These are some invalid symlinks that are generated by Xcode sometimes in the CI
rm -f "$WEBKIT_BUILD_OUTPUT_PATH/Build/Products/$CONFIGURATION/WebKit.framework/DatabaseProcess.app/DatabaseProcess.app"
rm -f "$WEBKIT_BUILD_OUTPUT_PATH/Build/Products/$CONFIGURATION/WebKit.framework/NetworkProcess.app/NetworkProcess.app"
rm -f "$WEBKIT_BUILD_OUTPUT_PATH/Build/Products/$CONFIGURATION/WebKit.framework/PluginProcess.app/PluginProcess.app"
rm -f "$WEBKIT_BUILD_OUTPUT_PATH/Build/Products/$CONFIGURATION/WebKit.framework/WebProcess.app/WebProcess.app"
rm -f "$WEBKIT_BUILD_OUTPUT_PATH/Build/Products/$CONFIGURATION/WebKit.framework/XPCServices/XPCServices"

checkpoint "Copying frameworks"
rm -rf "$INSPECTOR_SOURCE_PATH/Frameworks"
find "$WEBKIT_BUILD_OUTPUT_PATH/Build/Products/$CONFIGURATION" -name "*.framework" -type d -maxdepth 1 -print \
    -exec rsync -a {} "$INSPECTOR_SOURCE_PATH/Frameworks/" \;

checkpoint "Building Inspector app"
rm -rf "$INSPECTOR_BUILD_OUTPUT_PATH"

VERSION=$(python "$BUILD_DIR/scripts/get_version.py" "$BUILD_DIR/npm/inspector_package.json" 2>&1)
IFS=';' read -ra VERSION_ARRAY <<< "$VERSION"

xcodebuild \
    -project "$INSPECTOR_SOURCE_PATH/Inspector.xcodeproj" \
    -scheme "Inspector" \
    -archivePath "$INSPECTOR_BUILD_OUTPUT_PATH/Inspector.xcarchive" \
    MACOSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
    PACKAGE_VERSION="${VERSION_ARRAY[0]}" \
    archive \
    -quiet
xcodebuild \
    -exportArchive \
    -archivePath "$INSPECTOR_BUILD_OUTPUT_PATH/Inspector.xcarchive" \
    -exportOptionsPlist "$INSPECTOR_SOURCE_PATH/export-options.plist" \
    -exportPath "$INSPECTOR_BUILD_OUTPUT_PATH" \
    -quiet

checkpoint "Packaging Inspector app"
pushd "$INSPECTOR_BUILD_OUTPUT_PATH"
mv "Inspector.app" "NativeScript Inspector.app"
zip -r \
    --symlinks \
    "NativeScript Inspector.zip" \
    "NativeScript Inspector.app"
popd

mkdir -p "$DIST_DIR"
cp "$INSPECTOR_BUILD_OUTPUT_PATH/NativeScript Inspector.zip" "$DIST_DIR"

checkpoint "Inspector build finished - $DIST_DIR/NativeScript Inspector.zip"
