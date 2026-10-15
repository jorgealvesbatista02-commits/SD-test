set -o pipefail
V="$VCPKG_INSTALLATION_ROOT/installed/arm64-android"
L="$V/lib"
TC="$VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake"
CH="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake"
git clone --depth 1 https://forge.a-lec.org/speed-dreams/speed-dreams-code.git sd
git -C sd submodule update --init --depth 1 freesolid
VC="$VCPKG_INSTALLATION_ROOT/vcpkg"
"$VC" install sdl2 sdl2-mixer openal-soft enet libpng libjpeg-turbo curl expat --triplet arm64-android > vcpkg.log 2>&1 || true
for p in glm tinygltf cjson minizip sdl2-ttf; do
  "$VC" install $p --triplet arm64-android >> vcpkg.log 2>&1 || echo "FALHOU: $p" >> falhou.txt
done
export PKG_CONFIG_PATH="$L/pkgconfig"
STUB="$PWD/libtinygltf_stub.a"
ar rc "$STUB" 2>/dev/null || true
COMMON="-G Ninja -DCMAKE_TOOLCHAIN_FILE=$TC -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$CH -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_MANIFEST_MODE=OFF -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DOPTION_OFFICIAL_ONLY=ON -DSD_ASSUME_DATADIR=1 -DOPTION_OSGGRAPH=OFF"
cd sd
cmake -S . -B b6 $COMMON \
  -DSDL2_LIBRARY=$L/libSDL2.a \
  -DSDL2_MIXER_LIBRARY=$L/libSDL2_mixer.a -DSDL2_MIXER_LIBRARIES=$L/libSDL2_mixer.a \
  -DSDL2_TTF_LIBRARIES=$L/libSDL2_ttf.a -DSDL2_TTF_INCLUDE_DIRS=$V/include/SDL2 \
  -DPNG_LIBRARY=$L/libpng16.a -DJPEG_LIBRARY=$L/libjpeg.a \
  -DEXPAT_LIBRARY=$L/libexpat.a -DEXPAT_LIBRARY_RELEASE=$L/libexpat.a \
  -DOPENSSL_CRYPTO_LIBRARY=$L/libcrypto.a -DOPENSSL_SSL_LIBRARY=$L/libssl.a \
  -DOPENAL_LIBRARY=$L/libopenal.a -DOGG_LIBRARY=$L/libogg.a \
  -DVORBIS_LIBRARY=$L/libvorbis.a -DVORBISFILE_LIBRARY=$L/libvorbisfile.a \
  -DGLM_INCLUDE_DIR=$V/include -DCJSON_INCLUDE_DIR=$V/include/cjson \
  -DCJSON_LIBRARY=$L/libcjson.a -DTINYGLTF_INCLUDE_DIR=$V/include \
  -DTINYGLTF_LIBRARY=$STUB \
  -Dminizip_LIBRARIES=$L/libminizip.a -Dminizip_INCLUDE_DIRS=$V/include/minizip \
  > ../b6.log 2>&1 || true
cd ..
echo "=== VCPKG: $(tail -n 1 vcpkg.log)"
echo "=== FALHAS"; cat falhou.txt 2>/dev/null || echo nenhuma
echo "=== ARQUIVOS"; ls "$L" | grep -i -E 'ttf|freetype|minizip|tinygltf'
echo "=== HEADERS"; ls "$V/include" | grep -i -E 'tiny|minizip|ttf'; ls "$V/include/minizip" 2>&1 | head -5
echo "=== COMO O JOGO USA TINYGLTF E MINIZIP"
grep -rn -E "tiny_gltf|unzip\.h" sd/src --include=*.cpp --include=*.h --include=CMakeLists.txt | head -8
echo "=== OPENGL NO CMAKE"; grep -n -i "opengl" sd/cmake/checks.cmake | head -15
echo "=== ERROS DO CMAKE"; grep -B2 -A10 "CMake Error" b6.log | head -60
echo "=== AINDA FALTANDO"; grep "Could NOT" b6.log | grep -v X11 | sort -u
