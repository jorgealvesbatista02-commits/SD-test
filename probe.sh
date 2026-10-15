set -o pipefail
V="$VCPKG_INSTALLATION_ROOT/installed/arm64-android"
TC="$VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake"
CH="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake"
git clone --depth 1 https://forge.a-lec.org/speed-dreams/speed-dreams-code.git sd
git -C sd submodule update --init --depth 1 freesolid
"$VCPKG_INSTALLATION_ROOT/vcpkg" install sdl2 sdl2-mixer openal-soft enet libpng libjpeg-turbo curl expat --triplet arm64-android > vcpkg.log 2>&1 || true
COMMON="-G Ninja -DCMAKE_TOOLCHAIN_FILE=$TC -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$CH -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_MANIFEST_MODE=OFF -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DOPTION_OFFICIAL_ONLY=ON -DSD_ASSUME_DATADIR=1 -DOPTION_OSGGRAPH=OFF"
cd sd
cmake -S . -B b1 $COMMON > ../b1.log 2>&1 || true
cmake -S . -B b2 $COMMON -DCMAKE_PREFIX_PATH="$V" -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH > ../b2.log 2>&1 || true
cd ..
echo "=== VCPKG: $(tail -n 1 vcpkg.log)"
echo "=== LIBS"; ls "$V/lib" | head -40
echo "=== SDL2 HEADERS"; ls "$V/include/SDL2" 2>&1 | head -3
echo "=== FINDER"; grep -n "SDL2" sd/cmake/thirdpartydeps.cmake | head -15
echo "=== TENTATIVA 2"; grep -E "NOT found|Could NOT|CMake Error|Configuring|Generating" b2.log | tail -25
