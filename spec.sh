#!/bin/bash

set -e -x

cd ext
ruby extconf.rb
make

cp skylight_native.{bundle,so} ../lib/

cd ..

bundle exec rspec -cfs spec/
