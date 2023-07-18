#!/bin/bash

OS_TYPE="ios"

if [[ "$*" == *"--release"* ]]; then
    BUILD_TYPE=Release
elif [[ "$*" == *"--debug"* ]]; then
    BUILD_TYPE=Debug
else
    echo "Build type not set. Please specify it by passing '--debug' or '--release' as argument!"
    exit 1
fi

echo "Set build type as ${BUILD_TYPE}."

cmake -S. -Bcmake-build-${OS_TYPE}-${BUILD_TYPE} -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DAPPLE_IOS=TRUE
cmake --build cmake-build-${OS_TYPE}-${BUILD_TYPE} -j 8