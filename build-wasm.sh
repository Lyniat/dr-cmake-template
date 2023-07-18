#!/bin/bash

if [[ "$*" == *"--release"* ]]; then
    BUILD_TYPE=Release
elif [[ "$*" == *"--debug"* ]]; then
    BUILD_TYPE=Debug
else
    echo "Build type not set. Please specify it by passing '--debug' or '--release' as argument!"
    exit 1
fi

echo "Set build type as ${BUILD_TYPE}."

emcmake cmake -Bcmake-build-emscripten-${BUILD_TYPE} -DCMAKE_BUILD_TYPE=Debug
cmake --build cmake-build-emscripten-${BUILD_TYPE} -j 8