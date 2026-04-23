#!/bin/bash
# This script will be run monthly to update pdga_data.db for HotRound instances.
script_context=$(dirname "${BASH_SOURCE[0]}")
source "$script_context/doppler-get.sh"

# clone the repo if it doesn't exist
if [ ! -d "$DATA_DIR/hotround/repo/.git" ]; then
    git clone https://github.com/tbeidlershenk/hotround.git "$DATA_DIR/hotround/repo"
fi

# copy the prod db to a new file to scrape into
if [ ! -f "$DATA_DIR/hotround/data/pdga_data_scraped.db" ]; then
    cp $DATA_DIR/hotround/data/pdga_data.db $DATA_DIR/hotround/data/pdga_data_scraped.db
fi

# cd into the repo and pull it
cd $DATA_DIR/hotround/repo
git pull origin main

# create venv and install requirements
if [ ! -d "$DATA_DIR/hotround/repo/venv" ]; then
    python3 -m venv "$DATA_DIR/hotround/repo/venv"
fi
source "$DATA_DIR/hotround/repo/venv/bin/activate"
pip install -r requirements.txt

# run the scraper
python3 src/update.py ../config/update.json

# copy the scraped db over to prod db
cp $DATA_DIR/hotround/data/pdga_data_scraped.db $DATA_DIR/hotround/data/pdga_data.db
