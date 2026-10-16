set -o pipefail
V="$VCPKG_INSTALLATION_ROOT/installed/arm64-android"
L="$V/lib"
VC="$VCPKG_INSTALLATION_ROOT/vcpkg"
TC="$VCPKG_INSTALLATION_ROOT/scripts/buildsystems/vcpkg.cmake"
CH="$ANDROID_NDK_LATEST_HOME/build/cmake/android.toolchain.cmake"
git clone --depth 1 https://forge.a-lec.org/speed-dreams/speed-dreams-code.git sd
git -C sd submodule update --init --depth 1 freesolid
for p in sdl2 sdl2-mixer sdl2-ttf openal-soft enet libpng libjpeg-turbo curl expat glm tinygltf cjson minizip utf8proc rhash sqlite3 libogg libvorbis; do
  "$VC" install $p --triplet arm64-android >> vcpkg.log 2>&1 || echo "FALHOU: $p" >> falhou.txt
done
git clone --depth 1 https://github.com/ptitSeb/gl4es.git
cmake -S gl4es -B gl4es-b -G Ninja -DCMAKE_TOOLCHAIN_FILE=$CH -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DCMAKE_BUILD_TYPE=Release -DNOX11=ON -DGLX_STUBS=ON > gl4es.log 2>&1 || true
cmake --build gl4es-b >> gl4es.log 2>&1 || true
GL=$(find "$PWD/gl4es" -name 'libGL.so*' | head -1)
RH=$(find "$L" -name '*rhash*.a' | head -1)
SQ=$(find "$L" -name 'libsqlite3*.a' | head -1)
export PKG_CONFIG_PATH="$L/pkgconfig"
STUB="$PWD/libtinygltf_stub.a"; ar rc "$STUB" 2>/dev/null || true
sed -i 's/MESSAGE(FATAL_ERROR "Cannot find X11 libraries")/MESSAGE(STATUS "Cannot find X11 libraries")/' sd/cmake/thirdpartydeps.cmake
COMMON="-G Ninja -DCMAKE_TOOLCHAIN_FILE=$TC -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$CH -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_MANIFEST_MODE=OFF -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DOPTION_OFFICIAL_ONLY=ON -DSD_ASSUME_DATADIR=1 -DOPTION_OSGGRAPH=OFF"
BASE="-DSDL2_LIBRARY=$L/libSDL2.a -DSDL2_MIXER_LIBRARY=$L/libSDL2_mixer.a -DSDL2_MIXER_LIBRARIES=$L/libSDL2_mixer.a -DSDL2_TTF_LIBRARY=$L/libSDL2_ttf.a -DSDL2_TTF_LIBRARIES=$L/libSDL2_ttf.a -DSDL2_TTF_INCLUDE_DIRS=$V/include/SDL2 -DSDL2_TTF_INCLUDE_DIR=$V/include/SDL2 -DPNG_LIBRARY=$L/libpng16.a -DJPEG_LIBRARY=$L/libjpeg.a -DEXPAT_LIBRARY=$L/libexpat.a -DEXPAT_LIBRARY_RELEASE=$L/libexpat.a -DOPENSSL_CRYPTO_LIBRARY=$L/libcrypto.a -DOPENSSL_SSL_LIBRARY=$L/libssl.a -DOPENAL_LIBRARY=$L/libopenal.a -DOGG_LIBRARY=$L/libogg.a -DVORBIS_LIBRARY=$L/libvorbis.a -DVORBISFILE_LIBRARY=$L/libvorbisfile.a -DGLM_INCLUDE_DIR=$V/include -DCJSON_INCLUDE_DIR=$V/include/cjson -DCJSON_LIBRARY=$L/libcjson.a -DTINYGLTF_INCLUDE_DIR=$V/include -DTINYGLTF_LIBRARY=$STUB -Dminizip_LIBRARIES=$L/libminizip.a -Dminizip_INCLUDE_DIRS=$V/include/minizip -Dutf8proc_LIBRARIES=$L/libutf8proc.a -Dutf8proc_INCLUDE_DIRS=$V/include -Drhash_LIBRARIES=$RH -Drhash_INCLUDE_DIRS=$V/include -DSQLITE3_LIBRARY=$SQ -DSQLITE3_LIBRARIES=$SQ -DSQLITE3_INCLUDE_DIR=$V/include -DSQLITE3_INCLUDE_DIRS=$V/include -DENET_LIBRARY=$L/libenet.a -DENET_LIBRARIES=$L/libenet.a -DENET_INCLUDE_DIR=$V/include -DENET_INCLUDE_DIRS=$V/include -DOPENGL_opengl_LIBRARY=$GL -DOPENGL_glx_LIBRARY=$GL -DOPENGL_INCLUDE_DIR=$PWD/gl4es/include"
findlib() { f=$(find "$L" -maxdepth 1 -name "lib$1*.a" | head -1); [ -z "$f" ] && f=$(find "$L" -maxdepth 1 -iname "*$1*.a" | head -1); echo "$f"; }
incdir() { if [ -d "$V/include/$1" ]; then echo "$V/include/$1"; else echo "$V/include"; fi; }
EXTRA=""; OK=0
for i in $(seq 1 25); do
  (cd sd && cmake -S . -B bx $COMMON $BASE $EXTRA > ../cfg.log 2>&1)
  if grep -q "Build files have been written" cfg.log; then echo "CONFIGURE OK na tentativa $i"; OK=1; break; fi
  E=$(awk '/CMake Error/{f=1} f' cfg.log | head -10 | tr '\n' ' ' | sed 's/  */ /g')
  NEW=""
  VARS=$(echo "$E" | grep -oP 'missing: \K[^)]*' | head -1)
  for v in $VARS; do
    pre=$(echo "$v" | sed -E 's/_(LIBRARIES|LIBRARY|LIBRARY_RELEASE|INCLUDE_DIRS|INCLUDE_DIR|INCLUDE_PATH|INCLUDEDIR)$//I')
    low=$(echo "$pre" | tr 'A-Z' 'a-z')
    case "$low" in osg*|openscenegraph*|openthreads*|plib*) continue;; esac
    case "$v" in
      *[Ll][Ii][Bb][Rr][Aa][Rr]*)
        f=$(findlib "$low")
        if [ -z "$f" ]; then timeout 900 "$VC" install "$low" --triplet arm64-android >> vcpkg.log 2>&1; f=$(findlib "$low"); fi
        [ -n "$f" ] && NEW="$NEW -D$v=$f";;
      *[Ii][Nn][Cc][Ll][Uu][Dd][Ee]*) NEW="$NEW -D$v=$(incdir "$low")";;
    esac
  done
  HN=$(echo "$E" | grep -oP 'Cannot find \K[A-Za-z0-9_]+(?= (header|librar))' | head -1)
  if [ -n "$HN" ]; then
    hl=$(echo "$HN" | tr 'A-Z' 'a-z'); f=$(findlib "$hl")
    NEW="$NEW -D${HN}_INCLUDE_DIR=$(incdir "$hl") -D${HN}_INCLUDE_DIRS=$(incdir "$hl")"
    [ -n "$f" ] && NEW="$NEW -D${HN}_LIBRARY=$f -D${HN}_LIBRARIES=$f"
  fi
  if [ -z "$NEW" ] || echo "$EXTRA" | grep -qF -- "$NEW"; then echo "SEM PROGRESSO na tentativa $i"; break; fi
  EXTRA="$EXTRA $NEW"
done
echo "=== RESUMO"
echo "--- falhas do vcpkg"; cat falhou.txt 2>/dev/null || echo nenhuma
echo "--- argumentos descobertos"; echo "$EXTRA" | tr ' ' '\n' | grep '^-D'
echo "--- ultimo erro do cmake"; awk '/CMake Error/{f=1} f' cfg.log | head -14
echo "--- ainda faltando"; grep "Could NOT" cfg.log | grep -v X11 | sort -u
if [ "$OK" = 1 ]; then
  echo "=== COMPILANDO"
  cmake --build sd/bx -- -k 0 -j4 > build.log 2>&1 || true
  tail -n 3 build.log
  echo "--- primeiros erros"; grep -E "error:|FAILED:|fatal error" build.log | head -40
fi
