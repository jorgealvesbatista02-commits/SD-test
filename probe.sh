set -o pipefail
V="$VCPKG_INSTALLATION_ROOT/installed/arm64-android"
L="$V/lib"
TC="$VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake"
CH="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake"
git clone --depth 1 https://forge.a-lec.org/speed-dreams/speed-dreams-code.git sd
git -C sd submodule update --init --depth 1 freesolid
"$VCPKG_INSTALLATION_ROOT/vcpkg" install sdl2 sdl2-mixer openal-soft enet libpng libjpeg-turbo curl expat --triplet arm64-android > vcpkg.log 2>&1 || true
COMMON="-G Ninja -DCMAKE_TOOLCHAIN_FILE=$TC -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$CH -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_MANIFEST_MODE=OFF -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DOPTION_OFFICIAL_ONLY=ON -DSD_ASSUME_DATADIR=1 -DOPTION_OSGGRAPH=OFF"
cd sd
cmake -S . -B b3 $COMMON --debug-find > ../b3.log 2>&1 || true
cmake -S . -B b4 $COMMON -DSDL2_LIBRARY=$L/libSDL2.a -DPNG_LIBRARY=$L/libpng16.a -DJPEG_LIBRARY=$L/libjpeg.a -DEXPAT_LIBRARY=$L/libexpat.a -DOPENSSL_CRYPTO_LIBRARY=$L/libcrypto.a -DOPENSSL_SSL_LIBRARY=$L/libssl.a -DOPENAL_LIBRARY=$L/libopenal.a -DOGG_LIBRARY=$L/libogg.a -DVORBIS_LIBRARY=$L/libvorbis.a -DVORBISFILE_LIBRARY=$L/libvorbisfile.a > ../b4.log 2>&1 || true
cd ..
echo "=== VCPKG: $(tail -n 1 vcpkg.log)"
echo "=== POR QUE NAO ACHA O SDL2"
grep -n -A22 "Debug Log.*[Ss][Dd][Ll]2" b3.log | head -45
echo "=== CHAMADAS find_library"
grep -n "find_library" b3.log | head -12
echo "=== TENTATIVA COM CAMINHOS EXPLICITOS"
grep -E "Could NOT|CMake Error|Configuring|Generating|not found" b4.log | tail -25
