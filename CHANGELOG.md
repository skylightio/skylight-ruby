## 0.3.14 (June 3, 2014)

* Do not build C extension if dependencies (libraries/headers) are
  missing
* [RUST] Improve performance by not double copying memory when serializing
* Enable the Net::HTTP probe by default

## 0.3.13 (May 12, 2014)

* Load probes even when agent is disabled
* Check for Excon::Middlewares before installing the probe
* SQL error encoder should not operate in-place
* Fix Middleware
* More debug logging
* Log Rails version in MetricsReporter
* Handle missing Net::ReadTimeout in 1.9.3
* Include original exception information in sql_parse errors
* Debugging for failed application creation
* Make double sure that Trace started_at is an Integer

## 0.3.12 (April 17, 2014)

* Include more information in type check errors
* Use stdlib SecureRandom instead of ActiveSupport::SecureRandom - Fixes Rails 3.1
* Instrumenter#start! should fail if worker not spawned
* Configurable timeouts for Util::HTTP
* Improve proxy handling for Util::HTTP
* Improve HTTP error handling
* Refactor sql_parse errors

## 0.3.11 (April 11, 2014)

* Improved error handling and internal metrics
* Improved missing native agent message
* Improved install logging
* Added initial inline docs
* Respects HTTP_PROXY env var during installation
* Don't overwrite sockfile_path if set explicitly

## 0.3.10 (April 8, 2014)

* Don't raise on missing native agent path

## 0.3.9 (April 8, 2014)

* Avoid finalizing sockets in the child process
* Fix non-displaying warnings around native agent
* Remove HTTP path information from title for better grouping

## 0.3.8 (April 3, 2014)

* Update vendored highline to 1.6.21
* Send more information with exceptions for easier debugging
* Instrument and report internal agent metrics for easier debugging
* Fix bug with tracking request counts per endpoint

## 0.3.7 (March 31, 2014)

* Use a default event category if none passed to Skylight.instrument
* Fix bugs around disabling the agent
* Fix native extension compilation bugs

## 0.3.6 (March 27, 2014)

* Shorter token validation timeout
* Allow validation to be skipped

## 0.3.5 (March 26, 2014)

* Update Rust component
* Return true from Task#handle to avoid sutdown
* Fix numeric check that caused crash on some 32-bit systems
* Improve error message for missing Skylight ext
* Better config error messages
* Validate authentication token before starting
* Add proxy support

## 0.3.4 (March 13, 2014)

* Don't try to boot Skylight without native agent
* Make exception classes always available
* CLI should require railtie before loading application.rb

## 0.3.3 (March 12, 2014)

* Load the railtie even without native agent

## 0.3.2 (March 11, 2014)

* Autoload Skylight:Helpers even when native agent isn't available
* Fix SEGV

## 0.3.1 (March 8, 2014)

* Fix requires to allow CLI to function without native extension.

## 0.3.0 (February 28, 2014)

* Native Rust agent
* Send exceptions occurring during HTTP requests to the client.
* Warn users when skylight is potentially disabled incorrectly.
* Update SQL Lexer to 0.0.6
* Log the backtraces of unhandled exceptions
* Add support for disabling GC tracking
* Add support for disabling agent

## 0.2.7 (February 26, 2014)

* Disable annotations to reduce memory load.

## 0.2.6 (February 25, 2014)

* `inspect` even whitelisted payload props
* Ignore Errno::EINTR for 'ps' call

## 0.2.5 (February 21, 2014)

* Revert "Update SqlLexer to 0.0.4"

## 0.2.4 (February 20, 2014)

* Whitelist process action annotation keys.
* Update SqlLexer to 0.0.4

## 0.2.3 (December 20, 2013)

* Fix SQL lexing for comments, arrays, double-colon casting, and multiple queries
* Handle template paths from gems
* Status and exception reports for agent debugging

## 0.2.2 (December 10, 2013)

* Added support for Mongoid/Moped
* Fix probe enabling
* Improved error reporting
* Fix bug with multiple subscribers to same notification

## 0.2.1 (December 4, 2013)

* Fix bin/skylight

## 0.2.0 (December 3, 2013)

* Added Probes, initially Net::HTTP and Excon
* Wide-ranging memory cleanup
* Better resiliance to binary and encoding errors
* Add support for disabling
* De-dupe rendering instrumentation better
* Fix send_file event to not spew a gazillion nodes
* Rails 3.0 compatibility
* Detailed SQL annotations

## 0.1.8 (July 19, 2013)

* Update agent for new authentication scheme
* Change ENV variable prefix from SK_ to SKYLIGHT_

## 0.1.7 (July 11, 2013)

* Add instrument_method helper
* Add the ability to configure logging from railtie
* Tracks the current host
* [BUG] Handle AS::N monkey patching when there are already subscribers
* [BUG] Handle ruby 1.9.2 encoding bug

## 0.1.6 (June 11, 2013)

* [BUG] Fix unix domain socket write function in standalone agent
* Performance improvements
* Tolerate invalid trace building
* Fix Skylight on Rails 4

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
