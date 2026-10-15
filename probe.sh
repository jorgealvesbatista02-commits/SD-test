set -eo pipefail
ROOT=$PWD
trap 'echo "=== vcpkg ==="; tail -n 30 "$ROOT/vcpkg.log" || true; echo "=== cmake ==="; tail -n 40 "$ROOT/configure.log" || true' EXIT
git clone --depth 1 https://forge.a-lec.org/speed-dreams/speed-dreams-code.git sd
git -C sd submodule update --init --depth 1 freesolid
"$VCPKG_INSTALLATION_ROOT/vcpkg" install sdl2 sdl2-mixer openal-soft enet libpng libjpeg-turbo curl expat --triplet arm64-android 2>&1 | tee vcpkg.log
cd sd
cmake -S . -B build-android -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake" \
  -DVCPKG_TARGET_TRIPLET=arm64-android \
  -DVCPKG_MANIFEST_MODE=OFF \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DOPTION_OFFICIAL_ONLY=ON \
  -DSD_ASSUME_DATADIR=1 \
  -DOPTION_OSGGRAPH=OFF 2>&1 | tee "$ROOT/configure.log"
