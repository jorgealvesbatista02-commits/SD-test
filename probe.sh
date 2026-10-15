set -o pipefail
V="$VCPKG_INSTALLATION_ROOT/installed/arm64-android"
L="$V/lib"
TC="$VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake"
CH="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake"
git clone --depth 1 https://forge.a-lec.org/speed-dreams/speed-dreams-code.git sd
git -C sd submodule update --init --depth 1 freesolid
VC="$VCPKG_INSTALLATION_ROOT/vcpkg"
"$VC" install sdl2 sdl2-mixer openal-soft enet libpng libjpeg-turbo curl expat --triplet arm64-android > vcpkg.log 2>&1 || true
for p in glm tinygltf cjson minizip; do
  "$VC" install $p --triplet arm64-android >> vcpkg.log 2>&1 || echo "FALHOU: $p" >> falhou.txt
done
export PKG_CONFIG_PATH="$L/pkgconfig"
COMMON="-G Ninja -DCMAKE_TOOLCHAIN_FILE=$TC -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$CH -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_MANIFEST_MODE=OFF -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DOPTION_OFFICIAL_ONLY=ON -DSD_ASSUME_DATADIR=1 -DOPTION_OSGGRAPH=OFF"
cd sd
cmake -S . -B b5 $COMMON \
  -DSDL2_LIBRARY=$L/libSDL2.a \
  -DSDL2_MIXER_LIBRARY=$L/libSDL2_mixer.a -DSDL2_MIXER_LIBRARIES=$L/libSDL2_mixer.a \
  -DPNG_LIBRARY=$L/libpng16.a -DJPEG_LIBRARY=$L/libjpeg.a \
  -DEXPAT_LIBRARY=$L/libexpat.a -DEXPAT_LIBRARY_RELEASE=$L/libexpat.a \
  -DOPENSSL_CRYPTO_LIBRARY=$L/libcrypto.a -DOPENSSL_SSL_LIBRARY=$L/libssl.a \
  -DOPENAL_LIBRARY=$L/libopenal.a -DOGG_LIBRARY=$L/libogg.a \
  -DVORBIS_LIBRARY=$L/libvorbis.a -DVORBISFILE_LIBRARY=$L/libvorbisfile.a \
  -DGLM_INCLUDE_DIR=$V/include -DCJSON_INCLUDE_DIR=$V/include/cjson \
  -DCJSON_LIBRARY=$L/libcjson.a -DTINYGLTF_INCLUDE_DIR=$V/include \
  > ../b5.log 2>&1 || true
cd ..
echo "=== VCPKG: $(tail -n 1 vcpkg.log)"
echo "=== PACOTES EXTRAS QUE FALHARAM"; cat falhou.txt 2>/dev/null || echo nenhum
echo "=== ARQUIVOS"; ls "$L" | grep -E 'cjson|minizip|expat|mixer'
echo "=== ERROS DO CMAKE"
grep -B2 -A10 "CMake Error" b5.log > erros.txt; head -70 erros.txt
echo "=== AINDA FALTANDO"
grep "Could NOT" b5.log | grep -v X11 | sort -u
