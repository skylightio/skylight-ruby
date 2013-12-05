#!/bin/bash

cd ext
ruby extconf.rb
make

cp skylight_native.so ../lib/

cd ..

bundle exec rspec -cfs spec/
