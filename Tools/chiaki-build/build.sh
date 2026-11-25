#!/usr/bin/env bash
# Builds chiaki-lib (Pylux fork) + its static dependencies for tvOS device and tvOS arm64 simulator,
# and packs them as Chiaki.xcframework.
#   build.sh <pylux-source> <ios.toolchain.cmake> <out-dir>
# Runs on a macOS runner (see .github/workflows/chiaki-tvos.yml).
set -euo pipefail
trap 'echo "::error::build.sh line $LINENO: $BASH_COMMAND"' ERR
SRC="$1"; TOOLCHAIN="$2"; OUT="$3"
TVOS_MIN="${TVOS_MIN:-13.0}"  # must match the 13.0 Pylux forces as CMAKE_OSX_DEPLOYMENT_TARGET
mkdir -p "$OUT"

build_platform() {
  local platform="$1" dir="$OUT/build-$1"
  echo "== $platform"
  cmake -S "$SRC/ios" -B "$dir" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DPLATFORM="$platform" \
    -DDEPLOYMENT_TARGET="$TVOS_MIN" \
    -DENABLE_BITCODE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LIBIDN2=OFF -DCURL_USE_LIBPSL=OFF -DUSE_NGHTTP2=OFF \
    -DHAVE_FORK=OFF \
    -DMBEDTLS_FATAL_WARNINGS=OFF \
    -DCMAKE_C_FLAGS="-Wno-overriding-option" -DCMAKE_CXX_FLAGS="-Wno-overriding-option" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 > "$OUT/configure-$platform.log" 2>&1 \
    || { tail -60 "$OUT/configure-$platform.log"; return 1; }
  cmake --build "$dir" --config Release --target chiaki-lib > "$OUT/build-$platform.log" 2>&1 \
    || { grep -E "error:|FAILED:" "$OUT/build-$platform.log" | head -40; return 1; }
  # One static library holding chiaki-lib and every dependency it was built with.
  find "$dir" -name "*.a" -print0 | xargs -0 libtool -static -o "$OUT/libchiaki-$platform.a" 2> "$OUT/libtool-$platform.log"
  ls -la "$OUT/libchiaki-$platform.a"
}

build_platform TVOS
build_platform SIMULATORARM64_TVOS

# Public headers: the library's own include tree plus the headers CMake generates (config.h, version.h).
HDR="$OUT/include"
rm -rf "$HDR"; mkdir -p "$HDR"
cp -R "$SRC/lib/include/chiaki" "$HDR/"
find "$OUT/build-TVOS" -path "*include/chiaki/*.h" -exec cp {} "$HDR/chiaki/" \;
rm -f "$HDR/chiaki/version.h.in"
# chiaki/ecdh.h includes mbedtls headers, so ship mbedTLS's public headers next to chiaki's.
MBED_INC="$(find "$OUT/build-TVOS" -type d -path "*mbedtls-src/include" | head -1)"
[ -n "$MBED_INC" ] || { echo "mbedtls include dir not found"; exit 1; }
cp -R "$MBED_INC"/. "$HDR/"
rm -f "$HDR/CMakeLists.txt"
cat > "$HDR/module.modulemap" <<'EOF'
module Chiaki {
    umbrella "chiaki"
    exclude header "chiaki/ffmpegdecoder.h"
    exclude header "chiaki/pidecoder.h"
    export *
    module * { export * }
}
EOF

rm -rf "$OUT/Chiaki.xcframework"
xcodebuild -create-xcframework \
  -library "$OUT/libchiaki-TVOS.a" -headers "$HDR" \
  -library "$OUT/libchiaki-SIMULATORARM64_TVOS.a" -headers "$HDR" \
  -output "$OUT/Chiaki.xcframework"
(cd "$OUT" && ditto -c -k --keepParent Chiaki.xcframework Chiaki.xcframework.zip)
ls -la "$OUT/Chiaki.xcframework.zip"
