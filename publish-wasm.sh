#!/bin/bash

# help script for publishing (and hosting wasm) without all the unneeded files

get_dr_directory(){
  # taken from the tools/find-dr.sh file
  dircounter=0
  while ! [[ -n $(find "$PWD"/ -maxdepth 1 -name "dragonruby") ]] ; do
  ((dircounter++))
  if [ "$dircounter" -gt "10" ]; then
  echo "Could not find any valid DragonRuby super directory. Make sure that this project is somewhere in your DragonRuby directory or any subdirectory of it!"
  exit 1
  fi
  currentdir=${PWD##*/}/${currentdir}
  cd ..
  done
  echo $PWD
}

get_app_name(){
  FILE=metadata/game_metadata.txt

  if ! [ -f "$FILE" ]; then
      echo "Could not find $FILE!"
      exit 1
  fi

  title_line=$(grep "gametitle=" "$FILE")

  if [ -z "$title_line" ]; then
    echo "gametitle= in $FILE does not have a value!"
    exit 1
  fi

  version_line=$(grep "version=" "$FILE")

  if [ -z "$version_line" ]; then
    echo "version= in $FILE does not have a value!"
    exit 1
  fi

  title=$(echo $title_line | sed s/"gametitle="//)
  version=$(echo $version_line | sed s/"version="//)

  echo ${title}-html5-${version}
}

FULL_PATH=$PWD
DR_DIR=$(get_dr_directory)
FOLDER_NAME=$(basename "$PWD")

APP_NAME=$(get_app_name)

dest=${DR_DIR}/${FOLDER_NAME}-clean

mkdir -p ${dest}
mkdir -p ${dest}/app
mkdir -p ${dest}/metadata
mkdir -p ${dest}/native
mkdir -p ${dest}/sprites

cp -r ./app ${dest}
cp -r ./metadata ${dest}
cp -r ./native ${dest}
cp -r ./sprites ${dest}

cd ${DR_DIR}
./dragonruby-publish --only-package ${FOLDER_NAME}-clean

cd ./builds/${APP_NAME}
python3 ${FULL_PATH}/tools/host_wasm.py