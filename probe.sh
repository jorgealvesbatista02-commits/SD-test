set -o pipefail
ROOT=$PWD
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
git clone --depth 1 --branch OpenSceneGraph-3.6.5 https://github.com/openscenegraph/OpenSceneGraph.git osgsrc > osg.log 2>&1 || echo "FALHOU: clone osg" >> falhou.txt
cmake -S osgsrc -B osg-b -G Ninja -DCMAKE_TOOLCHAIN_FILE=$CH -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 -DCMAKE_BUILD_TYPE=Release -DOPENGL_PROFILE=GLES2 -DBUILD_OSG_APPLICATIONS=OFF -DBUILD_OSG_EXAMPLES=OFF -DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF -DBUILD_OSG_DEPRECATED_SERIALIZERS=OFF >> osg.log 2>&1 || true
timeout 1500 cmake --build osg-b --target OpenThreads osg >> osg.log 2>&1 || true
OL=$(find osg-b -name 'libosg.so' | head -1); [ -n "$OL" ] && OL="$ROOT/$OL"
OT=$(find osg-b -name 'libOpenThreads.so' | head -1); [ -n "$OT" ] && OT="$ROOT/$OT"
GL=$(find "$ROOT/gl4es" -name 'libGL.so*' | head -1)
GI="$ROOT/gl4es/include"
RH=$(find "$L" -name '*rhash*.a' | head -1)
SQ=$(find "$L" -name 'libsqlite3*.a' | head -1)
export PKG_CONFIG_PATH="$L/pkgconfig"
STUB="$ROOT/libtinygltf_stub.a"; ar rc "$STUB" 2>/dev/null || true
AC="$ROOT/android_compat.h"
cat > "$AC" << 'EOF'
#pragma once
#include <sched.h>
#include <pthread.h>
#ifndef pthread_setaffinity_np
#define pthread_setaffinity_np(t,s,m) 0
#endif
EOF
sed -i 's/MESSAGE(FATAL_ERROR "Cannot find X11 libraries")/MESSAGE(STATUS "Cannot find X11 libraries")/' sd/cmake/thirdpartydeps.cmake
COMMON="-G Ninja -DCMAKE_TOOLCHAIN_FILE=$TC -DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=$CH -DVCPKG_TARGET_TRIPLET=arm64-android -DVCPKG_MANIFEST_MODE=OFF -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 -DOPTION_OFFICIAL_ONLY=ON -DSD_ASSUME_DATADIR=1 -DOPTION_OSGGRAPH=OFF"
BASE="-DSDL2_LIBRARY=$L/libSDL2.a -DSDL2_MIXER_LIBRARY=$L/libSDL2_mixer.a -DSDL2_MIXER_LIBRARIES=$L/libSDL2_mixer.a -DSDL2_TTF_LIBRARY=$L/libSDL2_ttf.a -DSDL2_TTF_LIBRARIES=$L/libSDL2_ttf.a -DSDL2_TTF_INCLUDE_DIRS=$V/include/SDL2 -DSDL2_TTF_INCLUDE_DIR=$V/include/SDL2 -DPNG_LIBRARY=$L/libpng16.a -DJPEG_LIBRARY=$L/libjpeg.a -DEXPAT_LIBRARY=$L/libexpat.a -DEXPAT_LIBRARY_RELEASE=$L/libexpat.a -DOPENSSL_CRYPTO_LIBRARY=$L/libcrypto.a -DOPENSSL_SSL_LIBRARY=$L/libssl.a -DOPENAL_LIBRARY=$L/libopenal.a -DOGG_LIBRARY=$L/libogg.a -DVORBIS_LIBRARY=$L/libvorbis.a -DVORBISFILE_LIBRARY=$L/libvorbisfile.a -DGLM_INCLUDE_DIR=$V/include -DCJSON_INCLUDE_DIR=$V/include/cjson -DCJSON_LIBRARY=$L/libcjson.a -DTINYGLTF_INCLUDE_DIR=$V/include -DTINYGLTF_LIBRARY=$STUB -Dminizip_LIBRARIES=$L/libminizip.a -Dminizip_INCLUDE_DIRS=$V/include/minizip -Dutf8proc_LIBRARIES=$L/libutf8proc.a -Dutf8proc_INCLUDE_DIRS=$V/include -Drhash_LIBRARIES=$RH -Drhash_INCLUDE_DIRS=$V/include -DSQLITE3_LIBRARY=$SQ -DSQLITE3_LIBRARIES=$SQ -DSQLITE3_INCLUDE_DIR=$V/include -DSQLITE3_INCLUDE_DIRS=$V/include -DENET_LIBRARY=$L/libenet.a -DENET_LIBRARIES=$L/libenet.a -DENET_INCLUDE_DIR=$V/include -DENET_INCLUDE_DIRS=$V/include -DOPENGL_opengl_LIBRARY=$GL -DOPENGL_glx_LIBRARY=$GL -DOPENGL_INCLUDE_DIR=$GI"
report() {
  tail -n 3 "$1"
  echo "--- alvos que falharam"; grep "^FAILED" "$1" | sed -E 's/.*CMakeFiles\///' | head -15
  echo "--- simbolos que faltam"; grep "undefined symbol" "$1" | sed 's/.*undefined symbol: //' | sort -u | head -40
  echo "--- erros de compilacao unicos"
  grep -E "error:" "$1" | grep -v "undefined symbol" | sed -E 's#^/home/runner/work/[^ ]*/sd/##' | awk -F'error: ' '!s[$2]++' | head -25
}
SYS="-llog -landroid -lOpenSLES -lGLESv1_CM"
cd sd
cmake -S . -B bx $COMMON $BASE \
  -DCMAKE_C_FLAGS="-I$GI" \
  -DCMAKE_CXX_FLAGS="-I$GI -I$V/include -I$ROOT/osgsrc/include -I$ROOT/osg-b/include -include $AC" \
  -DCMAKE_C_STANDARD_LIBRARIES="$SYS $GL" \
  -DCMAKE_CXX_STANDARD_LIBRARIES="$SYS $GL $OL $OT" \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--error-limit=0" \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--error-limit=0" \
  > ../cfg.log 2>&1 || true
cd ..
echo "=== RESUMO"
echo "--- falhas"; cat falhou.txt 2>/dev/null || echo nenhuma
if grep -q "Build files have been written" cfg.log; then
  echo "CONFIGURE OK"
  cmake --build sd/bx -- -k 0 -j4 > build.log 2>&1 || true
  echo "##### TENTATIVA 1 (com GLESv1_CM)"; report build.log
  if grep -q "undefined symbol: gl" build.log; then
    echo "##### TENTATIVA 2 (com GLESv2 e EGL tambem)"
    cd sd
    cmake -S . -B bx \
      -DCMAKE_C_STANDARD_LIBRARIES="$SYS $GL -lGLESv2 -lEGL" \
      -DCMAKE_CXX_STANDARD_LIBRARIES="$SYS $GL -lGLESv2 -lEGL $OL $OT" \
      > ../cfg2.log 2>&1 || true
    cd ..
    cmake --build sd/bx -- -k 0 -j4 > build2.log 2>&1 || true
    report build2.log
  fi
  echo "--- bibliotecas geradas"; find sd/bx -name 'lib*.so' | sed -E 's#.*/##' | sort | head -40
else
  echo "CONFIGURE FALHOU"; awk '/CMake Error/{f=1} f' cfg.log | head -20
fi
exit 0
