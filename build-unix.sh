#!/bin/bash

FAT=false

if [[ "$*" == *"--release"* ]]; then
    BUILD_TYPE=Release
elif [[ "$*" == *"--debug"* ]]; then
    BUILD_TYPE=Debug
else
    echo "Build type not set. Please specify it by passing '--debug' or '--release' as argument!"
    exit 1
fi

echo "Set build type as ${BUILD_TYPE}."

build_macos()
{
  ARCH=$1
  cmake -S. -Bcmake-build-${OS_TYPE}-${ARCH}-${BUILD_TYPE} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_OSX_ARCHITECTURES=${ARCH}
  cmake --build cmake-build-${OS_TYPE}-${ARCH}-${BUILD_TYPE} -j 8
}

build_linux()
{
  cmake -S. -Bcmake-build-${OS_TYPE}-${BUILD_TYPE} -DCMAKE_BUILD_TYPE=${BUILD_TYPE}
  cmake --build cmake-build-${OS_TYPE}-${BUILD_TYPE} -j 8
}

build_android arm64-v8a

if [ $(uname) = "Darwin" ]; then
  OS_TYPE="macos"

  build_macos arm64
  build_macos x86_64

  # create fat binary
  mkdir -p cmake-build-${OS_TYPE}-fat-${BUILD_TYPE}
  FILE_X86=$(find cmake-build-${OS_TYPE}-x86_64-${BUILD_TYPE} -name "*.dylib")
  FILE_ARM64=$(find cmake-build-${OS_TYPE}-arm64-${BUILD_TYPE} -name "*.dylib")
  FILE_FAT=$(basename ${FILE_X86})
  lipo -create -output cmake-build-${OS_TYPE}-fat-${BUILD_TYPE}/${FILE_FAT} ${FILE_X86} ${FILE_ARM64}
  cp cmake-build-${OS_TYPE}-fat-${BUILD_TYPE}/${FILE_FAT} native/macos/${FILE_FAT}
else
  OS_TYPE="linux"
  build_linux
fi
