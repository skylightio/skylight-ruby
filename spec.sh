#!/bin/bash

set -e -x

cd ext
ruby extconf.rb
make

case `uname` in
  Darwin)
    LIBEXT=bundle
    ;;
  Linux)
    LIBEXT=so
    ;;
  *)
    echo "Unknown OS" >&2
    exit 1
    ;;
esac

cp skylight_native.${LIBEXT} ../lib/

cd ..

bundle exec rspec -cfs spec/
