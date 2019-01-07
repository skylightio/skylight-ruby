#!/bin/bash

sudo apt-get update
sudo apt-get install git -y
sudo apt-get install sqlite -y
sudo apt-get install libgmp3-dev -y

curl -sSL https://get.rvm.io | bash -s

source /home/vagrant/.rvm/scripts/rvm

rvm install 2.3
rvm install 2.6

rvm use 2.6 --default
