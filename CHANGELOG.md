## unreleased ##

* [BUG] Fix unix domain socket write function in standalone agent
* Performance improvements
* Tolerate invalid trace building

## 0.1.5 (May 31, 2013)

* Provide a default CA cert when one is not already present
* Expose Skylight.start! and Skylight.trace as APIs
* Expose Skylight.instrument as an API for custom instrumentation.

## 0.1.4 (May 30, 2013)

* [BUG] Fix some errors caused by floating point rounding
* [BUG] Handle clock skew caused by system clock changes

## 0.1.3 (May 29, 2013)

* [BUG] Require net/https and openssl
* [BUG] Rails' logger does not respond to #log. Use level methods
  instead

## 0.1.2 (May 29, 2013)

* [BUG] Disable GC profiling on JRuby

## 0.1.1 (May 29, 2013)

* [BUG] GC Profiling was not getting enabled

## 0.1.0 (May 24, 2013)

* Initial release
