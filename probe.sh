set -o pipefail
V="$VCPKG_INSTALLATION_ROOT/installed/arm64-android"
L="$V/lib"
TC="$VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake"
CH="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake"
git clone --depth 1 https://forge.a-lec.org/speed-dreams/speed-dreams-code.git sd
git -C sd submodule update --init --depth 1 freesolid
VC="$VCPKG_INSTALLATION_ROOT/vcpkg"
"$VC" install sdl2 sdl2-mixer sdl2-ttf openal-soft enet libpng libjpeg-turbo curl expat glm tinygltf cjson minizip utf8proc --triplet arm64-android > vcpkg.log 2>&1 || true
git clone --depth 1 https://github.com/ptitSeb/gl4es.git
cmake -S gl4es -B gl4es-b -G Ninja -DCMAKE_TOOLCHAIN_FILE=$CH -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DNOX11=ON -DGLX_STUBS=ON > gl4es.log 2>&1 || true
cmake --build gl4es-b >> gl4es.log 2>&1 || true
GL=$(find "$PWD/gl4es" -name 'libGL.so*' | head -1)
export PKG_CONFIG_PATH="$L/pkgconfig"
STUB="$PWD/libtinygltf_stub.a"
ar rc "$STUB" 2>/dev/null || true
sed -i '477s/FATAL_ERROR/STATUS/' sd/cmake/thirdpartydeps.cmake
COMMON="-G Ninja -DCMAKE_TOOLCHAIN_FILE=$TC -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$CH -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_MANIFEST_MODE=OFF -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DOPTION_OFFICIAL_ONLY=ON -DSD_ASSUME_DATADIR=1 -DOPTION_OSGGRAPH=OFF"
cd sd
cmake -S . -B b10 $COMMON \
  -DSDL2_LIBRARY=$L/libSDL2.a \
  -DSDL2_MIXER_LIBRARY=$L/libSDL2_mixer.a -DSDL2_MIXER_LIBRARIES=$L/libSDL2_mixer.a \
  -DSDL2_TTF_LIBRARY=$L/libSDL2_ttf.a -DSDL2_TTF_LIBRARIES=$L/libSDL2_ttf.a -DSDL2_TTF_INCLUDE_DIRS=$V/include/SDL2 -DSDL2_TTF_INCLUDE_DIR=$V/include/SDL2 \
  -DPNG_LIBRARY=$L/libpng16.a -DJPEG_LIBRARY=$L/libjpeg.a \
  -DEXPAT_LIBRARY=$L/libexpat.a -DEXPAT_LIBRARY_RELEASE=$L/libexpat.a \
  -DOPENSSL_CRYPTO_LIBRARY=$L/libcrypto.a -DOPENSSL_SSL_LIBRARY=$L/libssl.a \
  -DOPENAL_LIBRARY=$L/libopenal.a -DOGG_LIBRARY=$L/libogg.a \
  -DVORBIS_LIBRARY=$L/libvorbis.a -DVORBISFILE_LIBRARY=$L/libvorbisfile.a \
  -DGLM_INCLUDE_DIR=$V/include -DCJSON_INCLUDE_DIR=$V/include/cjson \
  -DCJSON_LIBRARY=$L/libcjson.a -DTINYGLTF_INCLUDE_DIR=$V/include -DTINYGLTF_LIBRARY=$STUB \
  -Dminizip_LIBRARIES=$L/libminizip.a -Dminizip_INCLUDE_DIRS=$V/include/minizip \
  -Dutf8proc_LIBRARIES=$L/libutf8proc.a -Dutf8proc_INCLUDE_DIRS=$V/include \
  -DENET_LIBRARY=$L/libenet.a -DENET_LIBRARIES=$L/libenet.a -DENET_INCLUDE_DIR=$V/include -DENET_INCLUDE_DIRS=$V/include \
  -DOPENGL_opengl_LIBRARY=$GL -DOPENGL_glx_LIBRARY=$GL -DOPENGL_INCLUDE_DIR=$PWD/../gl4es/include \
  > ../b10.log 2>&1 || true
cd ..
echo "=== VCPKG: $(tail -n 1 vcpkg.log)"
echo "=== ENET"; ls "$V/include" | grep -i enet; ls "$V/include/enet" 2>&1 | head -3
sed -n '326,338p' sd/cmake/thirdpartydeps.cmake
echo "=== CONFIGURE"; grep -E "Configuring|Generating|Build files" b10.log
grep -B2 -A10 "CMake Error" b10.log | head -40
echo "=== AINDA FALTANDO"; grep "Could NOT" b10.log | grep -v X11 | sort -u
echo "=== CHECAGENS DO JOGO"; grep -n -E "^MACRO|FATAL_ERROR" sd/cmake/thirdpartydeps.cmake | head -50
if grep -q "Build files have been written" b10.log; then
  echo "=== COMPILANDO"
  cmake --build sd/b10 -- -k 0 -j4 > build.log 2>&1 || true
  tail -n 3 build.log
  echo "=== PRIMEIROS ERROS"; grep -E "error:|FAILED:|fatal error" build.log | head -30
fi
