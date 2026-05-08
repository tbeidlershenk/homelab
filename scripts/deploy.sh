#!/bin/bash

script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

cd $BASE_DIR
git stash --all # in case of local changes for some reason
git fetch --all 
git reset --hard origin/main

$BASE_DIR/scripts/prepare.sh
$BASE_DIR/scripts/restart.sh
