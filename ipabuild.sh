if [[ $* == *--scriptdebug* ]]; then
    set -x
fi
set -e

WORKING_LOCATION="$(pwd)"
APP_BUILD_FILES="$WORKING_LOCATION/layout/Applications/Helium.app"
DEBUG_LOCATION="$WORKING_LOCATION/.theos/obj/debug"
RELEASE_LOCATION="$WORKING_LOCATION/.theos/obj"
if [[ $* == *--debug* ]]; then
    BUILD_LOCATION="$DEBUG_LOCATION/Helium.app"
else
    BUILD_LOCATION="$RELEASE_LOCATION/Helium.app"
fi

if [[ $* == *--clean* ]]; then
    echo "[*] Cleaning..."
    rm -rf build
    rm -rf widget_build
    make clean
fi

if [ ! -d "build" ]; then
    mkdir build
fi
#remove existing archive if there
if [ -d "build/Helium.tipa" ]; then
    rm -rf "build/Helium.tipa"
fi

if ! type "gmake" >/dev/null; then
    echo "[!] gmake not found, using macOS bundled make instead"
    make clean
    if [[ $* == *--debug* ]]; then
        make
    else
        make FINALPACKAGE=1
    fi
else
    gmake clean
    if [[ $* == *--debug* ]]; then
        gmake -j"$(sysctl -n machdep.cpu.thread_count)"
    else
        gmake -j"$(sysctl -n machdep.cpu.thread_count)" FINALPACKAGE=1
    fi
fi

# ============= Build Widget Extension Manually =============
echo "[*] Building widget extension..."
WIDGET_BUILD_DIR="$WORKING_LOCATION/widget_build"
WIDGET_SRC="$WORKING_LOCATION/src/widget"
rm -rf "$WIDGET_BUILD_DIR"
mkdir -p "$WIDGET_BUILD_DIR"

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
echo "  Using SDK: $SDK_PATH"

WIDGET_BUILD_OK=true

set +e
for ARCH in arm64 arm64e; do
    echo "  Compiling widget for $ARCH..."

    # Compile ObjC
    xcrun -sdk iphoneos clang -arch $ARCH \
        -miphoneos-version-min=14.0 \
        -fobjc-arc \
        -isysroot "$SDK_PATH" \
        -c "$WIDGET_SRC/WidgetSpawnHelper.m" \
        -o "$WIDGET_BUILD_DIR/WidgetSpawnHelper_$ARCH.o"
    if [ $? -ne 0 ]; then WIDGET_BUILD_OK=false; break; fi

    # Compile Swift and link
    xcrun -sdk iphoneos swiftc \
        -target ${ARCH}-apple-ios14.0 \
        -sdk "$SDK_PATH" \
        -parse-as-library \
        -import-objc-header "$WIDGET_SRC/HeliumWidget-Bridging-Header.h" \
        -framework WidgetKit \
        -framework SwiftUI \
        -application-extension \
        -Xlinker -application_extension \
        -Xlinker -rpath -Xlinker /usr/lib/swift \
        "$WIDGET_SRC/HeliumWidget.swift" \
        "$WIDGET_BUILD_DIR/WidgetSpawnHelper_$ARCH.o" \
        -o "$WIDGET_BUILD_DIR/HeliumWidget_$ARCH"
    if [ $? -ne 0 ]; then WIDGET_BUILD_OK=false; break; fi
done
set -e

if [ "$WIDGET_BUILD_OK" = true ]; then
    echo "  Creating fat binary..."
    lipo -create \
        "$WIDGET_BUILD_DIR/HeliumWidget_arm64" \
        "$WIDGET_BUILD_DIR/HeliumWidget_arm64e" \
        -output "$WIDGET_BUILD_DIR/HeliumWidget"

    if [[ $* != *--debug* ]]; then
        strip "$WIDGET_BUILD_DIR/HeliumWidget" 2>/dev/null || true
    fi

    echo "[*] Widget extension built successfully"
else
    echo "[!] Widget extension build FAILED"
fi
# ============= End Widget Build =============

if [ -d $BUILD_LOCATION ]; then
    # Add the necessary files
    echo "Adding application files"
    cp -r "$APP_BUILD_FILES/icon.png" "$BUILD_LOCATION/icon.png"
    cp -r "$APP_BUILD_FILES/Info.plist" "$BUILD_LOCATION/Info.plist"
    cp -r "$APP_BUILD_FILES/Assets.car" "$BUILD_LOCATION/Assets.car"
    cp -r "$APP_BUILD_FILES/en.lproj" "$BUILD_LOCATION/"
    cp -r "$APP_BUILD_FILES/zh-Hans.lproj" "$BUILD_LOCATION/"
    cp -r "$APP_BUILD_FILES/fonts" "$BUILD_LOCATION/"
    cp -r "$APP_BUILD_FILES/credits" "$BUILD_LOCATION/"

    # Package widget extension
    if [ "$WIDGET_BUILD_OK" = true ] && [ -f "$WIDGET_BUILD_DIR/HeliumWidget" ]; then
        echo "Packaging widget extension"
        mkdir -p "$BUILD_LOCATION/PlugIns/HeliumWidget.appex"
        cp "$WIDGET_BUILD_DIR/HeliumWidget" "$BUILD_LOCATION/PlugIns/HeliumWidget.appex/"
        cp "$WIDGET_SRC/Resources/Info.plist" "$BUILD_LOCATION/PlugIns/HeliumWidget.appex/"

        # Sign widget with entitlements
        echo "Signing widget extension"
        ldid -S"$WORKING_LOCATION/widget-ent.plist" "$BUILD_LOCATION/PlugIns/HeliumWidget.appex/HeliumWidget"
    else
        echo "WARNING: Widget extension not available, skipping"
    fi

    # Create payload
    echo "Creating payload"
    cd build
    mkdir Payload
    cp -r $BUILD_LOCATION Payload/Helium.app

    # Verify widget before archiving
    echo ""
    echo "=== Pre-Archive Widget Verification ==="
    if [ -d "Payload/Helium.app/PlugIns/HeliumWidget.appex" ]; then
        echo "OK: HeliumWidget.appex exists in Payload"
        ls -la "Payload/Helium.app/PlugIns/HeliumWidget.appex/"
        echo "Binary type:"
        file "Payload/Helium.app/PlugIns/HeliumWidget.appex/HeliumWidget"
        echo "Linked frameworks:"
        otool -L "Payload/Helium.app/PlugIns/HeliumWidget.appex/HeliumWidget" 2>/dev/null || true
        echo "Mach-O header (check MH_APP_EXTENSION_SAFE = 0x02000000 in flags):"
        otool -h "Payload/Helium.app/PlugIns/HeliumWidget.appex/HeliumWidget" 2>/dev/null || true
    else
        echo "FAIL: HeliumWidget.appex NOT found in Payload"
        echo "Contents of PlugIns/:"
        ls -laR "Payload/Helium.app/PlugIns/" 2>/dev/null || echo "  (PlugIns directory does not exist)"
    fi
    echo ""

    # Archive
    echo "Archiving"
    if [[ $* != *--debug* ]]; then
        strip Payload/Helium.app/Helium
    fi
    zip -vr Helium.tipa Payload
    rm -rf Helium.app
    rm -rf Payload

    # Final verification
    echo ""
    echo "=== Final .tipa Verification ==="
    unzip -l Helium.tipa | grep -i "widget\|PlugIns" || echo "  No widget-related files found"
fi

# Cleanup
rm -rf "$WIDGET_BUILD_DIR"
