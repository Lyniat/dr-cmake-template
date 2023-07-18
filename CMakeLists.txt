cmake_minimum_required(VERSION 3.22)

set(THIS_PROJECT_NAME "cext")

project(${THIS_PROJECT_NAME} LANGUAGES C CXX)

# both standards should support all the stuff you want to do
# if not change it to your needs
# btw. I totally recommend to read this: https://gist.github.com/bkaradzic/2e39896bc7d8c34e042b
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)

if(MSVC)
    message(FATAL_ERROR "MSVC is not supported as compiler.
    Please use MinGW (https://winlibs.com) when building for Windows.")
endif()

# following code is important for building for multiple platforms at one time
# *_BIN_DIR is set to different paths depending on your target platform and build type
# this makes sure that building Release and Debug or building wasm and macOS don't get in each others way
# the order of these is important!

# EMSCRIPTEN is automatically set when using the emscripten toolchain
if(EMSCRIPTEN)
    message("Building for WASM.")
    set(PROJECT_BIN_DIR emscripten-wasm-${CMAKE_BUILD_TYPE})
    # without the following line, the linker will pretty sure complain about building a dynamic lib for wasm
    set_property(GLOBAL PROPERTY TARGET_SUPPORTS_SHARED_LIBS TRUE)
# Raspberry Pi is currently not supported. I will try to fix this in the future
elseif(RASPBERRY_PI)
    message(FATAL_ERROR "Raspberry Pi is currently not supported.")
    # message("Building for WASM.")
    set(PROJECT_BIN_DIR linux-raspberrypi-${CMAKE_BUILD_TYPE})
elseif(WIN32)
    # following will pretty sure almost never be important BUT if it is necessary for your project to figure out if your
    # host machine is running an ARM Windows version (this might be the case when using Paralles on a Apple silicon)
    # this is the right way to do it (without needing to search on the internet like forever)
    # if (CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "(x86_64)|(X86_64)|(amd64)|(AMD64)")
    # do your Windows ARM stuff
    # endif()
    message("Building for Windows.")
    set(PROJECT_BIN_DIR windows-amd64-${CMAKE_BUILD_TYPE})

    # CMake might not work successfully if your project path is too long. You can fix this by
    # increasing the CMAKE_OBJECT_PATH_MAX value like:
    # set(CMAKE_OBJECT_PATH_MAX 350)
elseif(APPLE)
    if(APPLE_IOS)
        message("Building for iOS.")
        set(PROJECT_BIN_DIR ios-device-${CMAKE_BUILD_TYPE})

        # TODO: CMAKE_OSX_SYSROOT is different depending on building for a real iOS device or the iOS simulator
        #set(CMAKE_OSX_SYSROOT "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk")
        set(CMAKE_OSX_SYSROOT "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk")

    # to create a macOS fat binary you have to target both architectures
    # the unix-build script will handle this for you automatically and will also create a fat binary
    elseif (CMAKE_OSX_ARCHITECTURES MATCHES "x86_64")
        message("Building for macOS (Intel).")
        set(PROJECT_BIN_DIR macos-x86_64-${CMAKE_BUILD_TYPE})
    else()
        message("Building for macOS (Apple Silicon).")
        set(PROJECT_BIN_DIR macos-arm64-${CMAKE_BUILD_TYPE})
    endif()
# not every Unix is Linux
elseif(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    message("Building for Linux.")
    set(PROJECT_BIN_DIR linux-amd64-${CMAKE_BUILD_TYPE})
    set(LINUX TRUE)
# ANDROID_ABI is automatically set by the android build script
elseif(ANDROID)
    set(PROJECT_BIN_DIR android-${ANDROID_ABI}-${CMAKE_BUILD_TYPE})
    if(${ANDROID_ABI} MATCHES "arm64-v8a")
        set(ANDROID_TYPE android-arm64)
    elseif(${ANDROID_ABI} MATCHES "armeabi-v7a")
        set(ANDROID_TYPE android-arm32)
    elseif(${ANDROID_ABI} MATCHES "x86_64")
        set(ANDROID_TYPE android-amd64)
    elseif(${ANDROID_ABI} MATCHES "x86")
        set(ANDROID_TYPE android-x86)
    else()
        message(FATAL_ERROR "Unsupported Android ABI ${ANDROID_ABI}.")
    endif()

    message("Building for Linux ${ANDROID_TYPE}.")

    # your compiler might complain if following not set
    set(CMAKE_C_COMPILER_WORKS 1)
    set(CMAKE_CXX_COMPILER_WORKS 1)
else()
    message(FATAL_ERROR "Unsupported platform.")
endif()

# currently not used but maybe it will be important for you to know your iOS app name (appname=myappname) in the ios_metadata.txt file
if(APPLE_IOS)
    execute_process(COMMAND "bash" "${CMAKE_CURRENT_SOURCE_DIR}/tools/get-ios-info.sh"
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            RESULT_VARIABLE IOS_INFO_RESULT
            OUTPUT_VARIABLE IOS_INFO_OUT)

    if(NOT ${IOS_INFO_RESULT} STREQUAL "0")
        message(FATAL_ERROR ${IOS_INFO_OUT})
    else()
        message("Found iOS app name: ${IOS_INFO_OUT}.")
    endif ()
endif ()

# find the dragonruby parent directory
# this makes sure you can place your project directory wherever you like as long as it is
# a subdirectory of your DragonRuby directory
# example:
# dragonruby-macos/my-c-project
# dragonruby-macos/my-projects/c-projects/my-exmaple-project
if(${CMAKE_HOST_SYSTEM} MATCHES "Windows*") # "WIN32" not working here if cross compiling
    # find DR parent directory on Windows
    set(FIND_DR_COMMAND "cmd" "/C" "${CMAKE_CURRENT_SOURCE_DIR}/tools/find-dr.bat")
else()
    # find DR parent directory on Unix
    set(FIND_DR_COMMAND "bash" "${CMAKE_CURRENT_SOURCE_DIR}/tools/find-dr.sh")
endif()

execute_process(COMMAND ${FIND_DR_COMMAND}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        RESULT_VARIABLE FIND_DR_COMMAND_RESULT
        OUTPUT_VARIABLE FIND_DR_COMMAND_OUT)

# remove new line on Unix
string(REPLACE "\n" "" FIND_DR_COMMAND_OUT ${FIND_DR_COMMAND_OUT})
# remove new line on Windows
string(REPLACE "\\" "/" FIND_DR_COMMAND_OUT ${FIND_DR_COMMAND_OUT})

# this probably means that your project directory is NOT a subdirectory
# of your DragonRuby directory as explained above
if(NOT ${FIND_DR_COMMAND_RESULT} STREQUAL "0")
    message(FATAL_ERROR ${FIND_DR_COMMAND_OUT})
else()
    message("Found the DragonRuby directory at ${FIND_DR_COMMAND_OUT}.")
endif ()

include_directories(
        ${FIND_DR_COMMAND_OUT}/include
        # add all the other includes from third party projects you want to add
        # example:
        # third-party/cool-lib/include
)

set(THIS_PROJECT_SOURCE
        # GLOB is not really recommended but it makes things easier
        # file(GLOB_RECURSE native-app "*.c" "*.cpp" "*.h" "*.hpp")
        # cleaner way is adding all the files manually
        native-app/cext.h
        native-app/cext.cpp
)

add_library(${THIS_PROJECT_NAME} SHARED ${THIS_PROJECT_SOURCE})

target_link_directories(
        # add all the other directories you want to look for libraries to link with
        # depending on your (target) OS, these should end with .a, .lib
        # example:
        ${THIS_PROJECT_NAME} PRIVATE
            # third-party/cool-lib/bin
            # third-party/another-project/lib
        )


# depending on the target platform you might have to link different system libraries
if(EMSCRIPTEN)
    target_link_libraries(${THIS_PROJECT_NAME} PRIVATE
            # some wasm library
            )
elseif(RASPBERRY_PI)
    target_link_libraries(${THIS_PROJECT_NAME} PRIVATE
            # example for Raspberry Pi library
            # asound
            )
elseif (WIN32)
    target_link_libraries(${THIS_PROJECT_NAME} PRIVATE
            # example for a Windows library
            # winmm
            )
elseif(APPLE_IOS)
    target_link_libraries(${THIS_PROJECT_NAME} PRIVATE
            # example for a iOS library
            # Metal
            )
elseif(APPLE)
    target_link_libraries(${THIS_PROJECT_NAME} PRIVATE
            # example for a macOS library
            # Metal
            )
elseif(LINUX)
    target_link_libraries(${THIS_PROJECT_NAME} PRIVATE
            # example for linux library
            # asound
            )
endif()

# just keep this as it is
set_target_properties(${THIS_PROJECT_NAME}
        PROPERTIES PREFIX ""
        OUTPUT_NAME "${THIS_PROJECT_NAME}"
        )

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")

# flags for optimization
# debug flags
set(CMAKE_C_FLAGS_DEBUG   "${CMAKE_C_FLAGS_DEBUG} -O0")
set(CMAKE_CXX_FLAGS_DEBUG   "${CMAKE_CXX_FLAGS_DEBUG} -O0")

# I personally prefer -O3 for release buildings but depending on your target you might change them
# Emscripten will break with -O3 so we use -O2
if(EMSCRIPTEN)
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O0")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O0")
else()
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O3")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3")
endif ()

if(EMSCRIPTEN)
    set(EMSCRIPTEN_EXTRA_FLAGS "-s WASM=1 -s SIDE_MODULE=1 -pthread")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${EMSCRIPTEN_EXTRA_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${EMSCRIPTEN_EXTRA_FLAGS}")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${EMSCRIPTEN_EXTRA_FLAGS}")
elseif(APPLE_IOS)
    # use -arch arm64 for a real device
    set(IOS_EXTRA_FLAGS
            "-arch x86_64 \
            -install_name @rpath/socket.framework/socket \
            -fembed-bitcode -dead_strip -fobjc-arc -fobjc-link-runtime \
            -mios-simulator-version-min=10.3 -licucore -stdlib=libc++ \
            -framework CFNetwork -framework UIKit -framework Foundation"
            )
    set(IOS_EXTRA_LINKER_FLAGS
            "-rpath @loader_path/Frameworks -rpath -fobjc-arc -fobjc-link-runtime"
            )
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${IOS_EXTRA_FLAGS} -ObjC++")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${IOS_EXTRA_FLAGS} -ObjC")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${IOS_EXTRA_LINKER_FLAGS}")
elseif(APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${IOS_EXTRA_FLAGS} -ObjC++")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${IOS_EXTRA_FLAGS} -ObjC")
elseif (WIN32)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m64")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m64")
    set(CMAKE_SHARED_LINKER_FLAGS "-static-libgcc -static-libstdc++ -static")
endif()

# copy file to the right directory depending on target OS
if(EMSCRIPTEN)
    set(DR_TARGET_FILE ../native/emscripten-wasm/${THIS_PROJECT_NAME}.wasm)
elseif (APPLE_IOS)
    set(DR_TARGET_FILE ../native/ios-device/socket.framework/${THIS_PROJECT_NAME})
elseif (APPLE)
    set(DR_TARGET_FILE ../native/macos/${THIS_PROJECT_NAME}.dylib)
elseif (LINUX)
    set(DR_TARGET_FILE ../native/linux-amd64/${THIS_PROJECT_NAME}.so)
elseif (WIN32)
    set(DR_TARGET_FILE ../native/windows-amd64/${THIS_PROJECT_NAME}.dll)
elseif(ANDROID)
    set(DR_TARGET_FILE ../native/${ANDROID_TYPE}/${THIS_PROJECT_NAME}.so)
endif()

add_custom_command(TARGET ${THIS_PROJECT_NAME}
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:${THIS_PROJECT_NAME}> ${DR_TARGET_FILE}
        )

set(EXTERNAL_EXTRA_FLAGS "")
set(EXTERNAL_PATCH_COMMAND "")
set(THIRD_PARTY_CMAKE_COMMAND ${CMAKE_COMMAND})

if(EMSCRIPTEN)
    set(THIRD_PARTY_CMAKE_COMMAND emcmake cmake)
elseif (ANDROID)
    set (EXTERNAL_EXTRA_FLAGS
            -DCMAKE_C_COMPILER_WORKS=${CMAKE_C_COMPILER_WORKS} -DCMAKE_CXX_COMPILER_WORKS=${CMAKE_CXX_COMPILER_WORKS}
            -DANDROID_ABI=${ANDROID_ABI}
            -DANDROID_PLATFORM=${ANDROID_PLATFORM}
            -DANDROID_NDK=${ANDROID_NDK}
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
            )
elseif(APPLE_IOS)
    set (EXTERNAL_EXTRA_FLAGS
            -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
            -DCMAKE_CXX_FLAGS=${IOS_EXTRA_FLAGS}
            -DCMAKE_C_FLAGS=${IOS_EXTRA_FLAGS}
            )
elseif(APPLE)
    set(EXTERNAL_EXTRA_FLAGS "-DCMAKE_OSX_ARCHITECTURES=${CMAKE_OSX_ARCHITECTURES}")
endif()

# maybe you want to add an external project without adding all it's code to your source
# IMPORTANT: to make this work you have at least to change URL and URL_HASH
# other options that might be important could be INSTALL_COMMAND and PATCH_COMMAND
# for a full list of commands and their meanings, please see the official CMake documentation
# I recommend not changing the other command without knowing that they do
# they might be important for building your libraries for all DragonRuby targets
# include(ExternalProject)
# ExternalProject_Add(
#        test-project
#        URL https://github.com/Lyniat/test-project/releases/download/v1.0/v1.0.tar.gz
#        URL_HASH MD5=89d66a2bf905b4aacd7274cc285b0b4c
#        DOWNLOAD_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third-party/download/test-project
#        BINARY_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third-party/bin/test-project
#        SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/third-party/src/test-project
#        INSTALL_COMMAND change this if needed
#        PATCH_COMMAND change this if needed
#        CMAKE_COMMAND ${THIRD_PARTY_CMAKE_COMMAND}
#        CMAKE_ARGS
#        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
#        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
#        ${EXTERNAL_EXTRA_FLAGS}
# )
