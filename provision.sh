#!/bin/bash

sudo apt-get update
sudo apt-get install git -y
sudo apt-get install sqlite -y
sudo apt-get install libgmp3-dev -y

curl -sSL https://get.rvm.io | bash -s

source /home/vagrant/.rvm/scripts/rvm

rvm install 1.9.3
rvm install 2.0.0
rvm install 2.1.10
rvm install 2.4.0

rvm use 2.4.0 --default
