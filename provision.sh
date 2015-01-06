#!/bin/bash

curl -sSL https://get.rvm.io | bash -s

source /home/vagrant/.rvm/scripts/rvm

rvm mount -r https://rvm.io/binaries/ubuntu/14.04/x86_64/ruby-1.9.3-p547.tar.bz2
rvm mount -r https://rvm.io/binaries/ubuntu/14.04/x86_64/ruby-2.0.0-p576.tar.bz2
rvm mount -r https://rvm.io/binaries/ubuntu/14.04/x86_64/ruby-2.1.5.tar.bz2

# Not available yet
#rvm mount -r https://rvm.io/binaries/ubuntu/14.04/x86_64/ruby-2.2.0.tar.bz2
rvm install 2.2.0

rvm use 2.2.0 --default
