#!/bin/bash

set -e -x

export SKYLIGHT_REQUIRED=true
export SKYLIGHT_ENABLE_TRACE_LOGS=true

cd ext
ruby extconf.rb
echo $?
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
