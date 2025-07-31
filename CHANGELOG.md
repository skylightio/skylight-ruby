## 7.0.0.beta (July 31, 2025)

- IMPROVEMENT Initial support for AWS Lambda
- BREAKING end support for Ruby 2.7

## 6.1.0.beta (June 11, 2024)

- [IMPROVEMENT] Initial support for parsing queries from activerecord-sqlserver-adapter

## 6.0.4 (February 23, 2024)

- [IMPROVEMENT] Set "turbo-frame" in the request segment when making a Turbo-Frame request

## 6.0.3 (January 18, 2024)

- [IMPROVEMENT] Remove an outdated "abbrev" requirement

## 6.0.2 (January 9, 2024)

- [IMPROVEMENT] When using certain versions of Rubygems (< 3.4.9), some users experienced a Rubygems bug in which the wrong version of Psych native extensions were loaded during Skylight's native extension building. We have inlined the data needed to download libskylight, so YAML is no longer required during installation. Note that for existing versions of Skylight, this issue may also be corrected by updating Rubygems to at least 3.4.9.

## 6.0.1 (September 12, 2023)

- [BUGFIX] Fix a logger message that could raise an error when I18n is misconfigured or unconfigured.
- [BUGFIX] Fix an issue with proxy config in skylightd.

## 6.0.0 (September 11, 2023)

- [BREAKING] End support for Ruby 2.6
- The following libraries are no longer tested and are not guaranteed to work with Skylight 6:
  - Sinatra 1.x
  - GraphQL 1.7 and 1.8
  - Sidekiq 4
- NOTE: There is an inconsistency in the order of application of `ruby2_keywords` and `instrument_method` in
  Ruby >= 3.2. We recommend not combining these two annotations at all, but if you must, call `instrument_method`
  after your method has been defined.
- [IMPROVEMENT] When Rails's `exceptions_app` (used by ActionDispatch::ShowExceptions) is set to another instrumented
  responder (like a Rails router), Skylight will not set the endpoint name after exception processing has started.
  This means that error traces will now be aggregated under the original endpoint that generated the error (but with
  the 'error' segment), rather than under the exception handler's controller and action name.
- [IMPROVEMENT] (Once again) Provide native support for FreeBSD.
- [BUGFIX] Fix an issue in which the daemon could time out if the processes file descriptor count was set very high (e.g. on Heroku's Performance dynos)
- [IMPROVEMENT] Better support for GraphQL versions >= 2.0.18.

## 5.3.5 (January 18, 2024)

- [IMPROVEMENT] Remove an outdated "abbrev" requirement

## 5.3.4 (October 17, 2022)

- [BUGFIX] Fix a middleware response method that was incompatible with Puma >= 6.
- [IMPROVEMENT] Improved support for Redis v5

## 5.3.3 (July 13, 2022)

- [IMPROVEMENT] Track the original class/method name for Sidekiq delayed object proxies
- [BUGFIX] Fix `mongoid` probe not activating correctly
- [BUGFIX] Fix `mongo` probe not instrumenting clients created before Skylight initialization

## 5.3.2 (April 6, 2022)

- [BUGFIX] Fix case-sensitivity issue when computing relative paths

## 5.3.1 (February 28, 2022)

- [BUGFIX] Fix Elasticsearch integration for gem versions >= 8.

## 5.3.0 (February 9, 2022)

- [FEATURE] Support for Rails 7's `load_async`.
- [IMPROVEMENT] `skylight doctor` now checks glibc compatibility.
- [BUGFIX] Fix an issue where `skylight doctor` wouldn't correctly log installation errors.

## 5.2.0 (February 3, 2022)

- [FEATURE] Experimental gRPC transport
- [IMPROVEMENT] Internal native client refactors
- [IMPROVEMENT] Add Rack::Builder probe to better instrument middlewares in Sinatra and other Builder-based apps
- [BUGFIX] Fix some internal errors related to Rails 7
- [BUGFIX] Fix an issue in which trace logging could output the incorrect request ID.
- [BUGFIX] Fix native extension configuration for arm64 hosts

## 5.1.1 (May 27, 2021)

- [BUGFIX] Correct ruby version requirement in skylight.gemspec

## 5.1.0 (May 24, 2021) [YANKED]

- [FEATURE] Add experimental tcp-based `skylightd` (may be enabled with `SKYLIGHT_ENABLE_TCP=true`)

- [IMPROVEMENT] Support aarch64-darwin targets (Apple M1)
- [IMPROVEMENT] Support aarch64-linux-gnu targets
- [IMPROVEMENT] Support aarch64-linux-musl targets
- [IMPROVEMENT] Prevent large traces from shutting down the instrumenter
- [IMPROVEMENT] Avoid 'invalid option' warnings when instrumenting certain Tilt templates in Sinatra
- [IMPROVEMENT] Decrease verbosity of source locations logs in the debug level.

- [BREAKING] Remove `SKYLIGHT_SSL_CERT_DIR` config
- [BREAKING] Drop support for Ruby 2.5

## 5.0.1 (March 11, 2021)

- [IMPROVEMENT] Use argument-forwarding (...) where available in custom instrumentation

## 5.0.0 (March 5, 2021)

- [FEATURE] Add normalizer for Shrine events (thanks @janko!)
- [FEATURE] Source Locations detection and reporting is now enabled by default (can be disabled with `SKYLIGHT_ENABLE_SOURCE_LOCATIONS=false`)
- [FEATURE] Configuration for the Source Locations caches via `SYLIGHT_SOURCE_LOCATION_CACHE_SIZE`

- [IMPROVEMENT] Improve keyword argument handling in Skylight::Helpers (thanks @lukebooth!)
- [IMPROVEMENT] Replace a Kernel.puts with Skylight.log (thanks @johnnyshields!)
- [IMPROVEMENT] Various updates to the SQL lexer
- [IMPROVEMENT] Reduce volume of log messages sent to the native logger in debug level
- [IMPROVEMENT] Optimizations for the Source Locations extension
- [IMPROVEMENT] Improved Delayed::Job probe
- [IMPROVEMENT] Maintain method visibility when instrumenting with `instrument_method`
- [IMPROVEMENT] Update probes to use `Module#prepend` where possible
- [IMPROVEMENT] New tokio-based skylightd
- [IMPROVEMENT] Support `render_layout` notifications in Rails 6.1
- [IMPROVEMENT] Support `ActionMailer::MailDeliveryJob` in Rails 6.1
- [IMPROVEMENT] Better logging config. `SKYLIGHT_NATIVE_LOG_LEVEL` now defaults to `warn`.

- [BREAKING] Rename `environment` keyword argument to `priority_key`. Note `env` has not changed.
- [BREAKING] Merge skylight-core into skylight. All classes previously namespaced under `Skylight::Core` have been moved to `Skylight`.
- [BREAKING] Remove `Skylight::Util::Inflector`
- [BREAKING] Drop support for Rails 4
- [BREAKING] Drop support for Ruby 2.3 and 2.4
- [BREAKING] Drop support for glibc < 2.23

- [BUGFIX] Fix issue with missing metadata in MongoDB probe
- [BUGFIX] Resolve an inability to parse certain SQL queries containing arrays
- [BUGFIX] Allow multiple probes to be registered under the same key
- [BUGFIX] Do not refer to Redis constant until the probe is installed
- [BUGFIX] Fix nested calls to `Normalizers::Faraday::Request.disable`

## 4.3.2 (December 14, 2020)

- [BUGFIX] Backport an ActionView fix from Skylight 5 (makes Skylight 4 compatible with Rails 6.1)

## 4.3.1 (June 24, 2020)

- [BUGFIX] Fix an issue in which `Mime::NullType` would result in an exception

## 4.3.0 (March 18, 2020)

- [IMPROVEMENT] Fix Ruby 2.7 warnings
- [IMPROVEMENT] Update Grape normalizer for version 1.3.1
- [BUGFIX] Fix an issue where GraphQL normalizers could fail to load in non-Rails contexts

## 4.2.2 (February 25, 2020)

- Support graphql-ruby version 1.10

## 4.2.1 (January 14, 2020)

- [IMPROVEMENT] Enable instrumentation for ActionMailer::MailDeliveryJob
- [BUGFIX] Improved handling for non-SPEC compliant Rack middleware

## 4.2.0 (October 30, 2019)

- [FEATURE] Add GraphQL probe
- [FEATURE] Optionally add Rack mount point to Sinatra endpoint names
- [FEATURE] Add `Skylight.mute` and `Skylight.unmute` blocks to selectively disable and re-enable
- [IMPROVEMENT] Shut down the native instrumenter when the remote daemon is unreachable
  instrumentation
- [IMPROVEMENT] Revise agent authorization strategy (fixes some issues related to activation for background jobs)
- [IMPROVEMENT] Fix Rails 6 deprecation warnings
- [BUGFIX] Skip the Sidekiq probe if Sidekiq is not present

## 4.1.2 (June 27, 2019)

- [BUGFIX] Correct an issue where the delayed_job probe may not be activated on startup

## 4.1.1 (June 25, 2019)

- [BUGFIX] Fix Skylight installation when bundled with edge rails [Issue #132](https://github.com/skylightio/skylight-ruby/issues/132)
- [IMPROVEMENT] Improve socket retry handling in skylightd

## 4.1.0 (June 3, 2019)

- [FEATURE] add normalizers for Graphiti >= 1.2
- [BUGFIX] re-enable aliases in skylight.yml

## 4.0.2 (May 21, 2019)

- [BUGFIX] Fix an issue with Delayed::Job worker name formatting

## 4.0.1 (May 9, 2019)

- [BUGFIX] Better detection of known web servers

## 4.0.0 (May 6, 2019)

- [FEATURE] Skylight for Background Jobs
- [FEATURE] instrument ActiveStorage notifications
- [FEATURE] Probe for Delayed::Job (standalone)
- [FEATURE] Add Skylight#started? method
- [IMPROVEMENT] Support anonymous ActiveModelSerializer classes
- [IMPROVEMENT] Improve error handling in normalizers
- [IMPROVEMENT] Handle Rails 6's middleware instrumentation
- [IMPROVEMENT] Better rendered format detection in Rails controllers
- [IMPROVEMENT] Recognize the Passenger startup script as 'web'
- [IMPROVEMENT] ActionMailer::DeliveryJob are now reported using the mailer name and method
- [IMPROVEMENT] Better content type handling for ActionController normalizer
- [IMPROVEMENT] Better handle some things in Ruby 2.6
- [IMPROVEMENT] Better logging in a couple places
- [IMPROVEMENT] Fixed a couple Ruby warnings (thanks, @y-yagi!)
- [IMPROVEMENT] Handle 403 config validation response
- [IMPROVEMENT] Config for `prune_large_traces` is now true by default
- [BUGFIX] Require http formatters for Faraday (thanks, @serkin!)
- [BREAKING] Drop support for Ruby 2.2 since it is EOL
- [BREAKING] New method for assigning 'segment' to a trace endpoint name

## 3.1.4 (January 24, 2019)

- [BUGFIX] ActiveJob#perform_now should not reassign the endpoint name

## 3.1.3 (January 23, 2019)

- [BUGFIX] skylightd correctly closes cloned file descriptors on startup
- [BUGFIX] Convert numeric git shas to strings

## 3.1.2 (November 29, 2018)

- [BUGFIX] Fix derived endpoint names under Grape 1.2

## 3.1.1 (October 25, 2018)

- [IMPROVEMENT] Get AMS version from `Gem.loaded_specs` (thanks @mattias-lundell!)

## 3.1.0 (October 22, 2018)

- [IMPROVEMENT] Trace Mongo aggregate queries
- [BUGFIX] Correct configuration keys in skylight.yml
- [BUGFIX] SQL queries with schema-qualified table names are parsed correctly
- [BUGFIX] `SELECT ... FOR UPDATE` queries are parsed correctly
- [BUGFIX] Revision to SQL string escaping rules
- [BUGFIX] Fix issue where Rails routing errors could result in a broken trace.

## 3.0.0 (September 5, 2018)

- [FEATURE] First class support for [multiple application environments](https://www.skylight.io/support/environments)
- [IMPROVEMENT] Better instrumentation of ActiveJob enqueues
- [BREAKING] The ActiveJob enqueue_at normalizer is now a probe that is enabled by default. The normalizer no longer needs to be required.
- [BREAKING] Remove SKYLIGHT_USE_OLD_SQL_LEXER config option

## 2.0.2 (June 4, 2018)

- [IMPROVEMENT] Improve handling of broken middleware traces
- [IMPROVEMENT] Don't rely on ActiveSupport's String#first (Thanks @foxtacles!)
- [BUGFIX] Susbcribe to AS::Notifications events individually
- [IMPROVEMENT] add normalizer for 'format_response.grape' notifications
- [BUGFIX] Correctly deprecate the Grape probe

## 2.0.1 (May 1, 2018)

- [BUGFIX] Correctly deprecate the now unncessary Grape probe.

## 2.0.0 (April 25, 2018)

- [FEATURE] New SQL lexer to support a wider variety of SQL queries.
- [BREAKING] Drop support for Ruby versions prior to 2.2
- [BREAKING] Drop support for Rails versions prior to 4.2
- [BREAKING] Drop support for Tilt versions prior to 1.4.1
- [BREAKING] Drop support for Sinatra versions prior to 1.4
- [BREAKING] Drop support for Grape versions prior to 0.13.0
- [BREAKING] Drop support for Linux with glibc versions prior to 2.15
- [BREAKING] Remove couch_potato normalizer as it doesn't appear to have ever worked
- [BREAKING] `log_sql_parse_errors` config option is now on by default.
- [IMPROVEMENT] Auto-disable Middleware probe if it appears to be causing issues
- [IMPROVEMENT] More detailed logging and improved error handling
- [IMPROVEMENT] Fix Ruby Warnings (Thanks @amatsuda!)
- [IMPROVEMENT] Improved handling of errors generated in the Rust agent.
- [IMRPOVEMENT] Add logging to Instrumentable for easier access
- [IMPROVEMENT] Improved logging during startup

## 1.7.0 (April 24, 2018)

- [FEATURE] New API for loading Probes. Example: `Skylight.probe(:excon')`
- [FEATURE] New API for enabling non-default Normalizers. Example: `Skylight.enable_normalizer('active_job')`
- [DEPRECATION] Support for Rails versions prior to 4.2
- [DEPRECATION] Support for Tilt versions prior to 1.4.1
- [DEPRECATION] Support for Sinatra versions prior to 1.4
- [DEPRECATION] Support for Grape versions prior to 0.13.0

## 1.6.1 (April 12, 2018)

- [IMPROVEMENT] Include endpoint name in error logging
- [BUGFIX] Make sure to correctly release broken traces
- [BUGFIX] Keep the `require` method private when overwriting

## 1.6.0 (March 21, 2018)

- [FEATURE] Time spent the Rails router is now identified separately in the trace
- [IMPROVEMENT] Switch logger to debug mode if tracing is enabled
- [IMPROVEMENT] Improved logging for a number of error cases
- [IMPROVEMENT] Middleware probe should now accept anything allowed by Rack::Lint
- [IMPROVEMENT] We were using arity checks to determine Rails version but due to other libraries' monkey patches this could sometimes fail. We just check version numbers now.
- [BUGFIX] Middleware probe no longer errors when Middleware returns a frozen array

## 1.5.1 (February 7, 2018)

- [BUGFIX] `skylight doctor` no longer erroneously reports inability to reach Skylight servers.

## 1.5.0 (December 6, 2017)

- [FEATURE] [Coach](https://github.com/gocardless/coach) instrumentation. Enabled automatically via ActiveSupport::Notifications.
- [FEATURE] Option to enable or disable agent by setting SKYLIGHT_ENABLED via ENV.
- [IMPROVEMENT] Better logging for certain error cases.
- [BUGFIX] Backport a SPEC compliance fix for older Rack::ETag to resolve case where the Middleware probe could cause empty traces.
- [BUGFIX] Fix a case where using the non-block form of `Skylight.instrument` with `Skylight.done` could cause lost trace data.

## 1.4.4 (November 7, 2017)

- [BUGFIX] The minimum glibc requirement was errorneously bumped to 2.15. We have returned it to 2.5.

## 1.4.3 (October 18, 2017)

- [BUGFIX] In rare cases, Rails Middleware can be anonymous classes. We now handle those without raising an exception.

## 1.4.2 (October 11, 2017)

- [BUGFIX] For experimental deploy tracking support, resolve an error that occurred if the Git SHA and description were not set.

## 1.4.1 (October 10, 2017)

- [BUGFIX] Fix an issue that would prevent the daemon from starting up on FreeBSD.

## 1.4.0 (October 4, 2017)

- [FEATURE] Add probe for Rack Middlewares
- [FEATURE] ActiveRecord Instantiation instrumentation
- [FEATURE] Faraday instrumentation. Add 'faraday' to your probes list.
- [IMPROVEMENT] Increase limit for items tracked in a requests
- [IMPROVEMENT] Allow for more fine-grained control over position of Skylight::Middleware
- [IMPROVEMENT] Improved handling of the user-level configuration options
- [IMPROVEMENT] Avoid processing Skylight::Middleware unnecessarily
- [EXPERIMENTAL] FreeBSD support. (This should work automatically on FreeBSD systems, but real-world testing has been minimal.)
- [EXPERIMENTAL] ActionJob Enqueue instrumentation. (Only tracks the enqueuing of new jobs. Does not instrument jobs themselves. Off by default since it's not clear how useful it is. To enable: `require 'skylight/normalizers/active_job/enqueue_at'`.)

## 1.3.1 (May 17, 2017)

- [IMPROVEMENT] Better suggestions in `skylight doctor`.

## 1.3.0 (May 17, 2017)

- [FEATURE] Add normalizer for couch_potato. (Thanks @cobot)
- [IMPROVEMENT] `skylight doctor` now validates SSL configuration
- [IMPROVEMENT] Add ENV option to force use of bundled SSL certificates

## 1.2.2 (April 28, 2017)

- [BUGFIX] Update bundled SSL certificates to avoid an authentication issue some users encountered due to a new skylight.io certificate.

## 1.2.1 (April 20, 2017)

- [BUGFIX] Ignored heartbeat endpoints with response types weren't actually ignored. They now will be!

## 1.2.0 (April 10, 2017)

- [FEATURE] Response Type tracking for all applications. (Previously known as Segments.)

## 1.1.0 (March 9, 2017)

- [FEATURE] Support musl-based OSes (including Alpine Linux)
- [FEATURE] Add Elasticsearch Probe
- [FEATURE] Add HTTPClient probe (#76)j
- [IMPROVEMENT] Update tested Ruby versions, drop 1.9.2
- [BUGFIX] Fix HTTP_PROXY handling of empty strings (#90)
- [BUGFIX] Don't crash on empty content_type strings
- [BUGFIX] Use more robust method to detect home dir (#75)
- [BUGFIX] Add option to suppress environment warning (#62)

## 1.0.1 (November 15, 2016)

- [BUGFIX] Gracefully handle non-writable log files
- [BUGFIX] Fix skylight doctor's handling of config files
- [BUGFIX] Support MetalControllers that don't use ActionController::Rendering

## 1.0.0 (October 19, 2016)

- [BETA FEATURE] Track separate segments for endpoints. Contact support@skylight.io to have this feature enabled for your account.
- [FEATURE] Initial 'skylight doctor' command
- [BREAKING] Removed old `skylight setup` without creation token
- [BREAKING] Remove Ruby based SQL lexer
- [IMPROVEMENT] Internal refactors
- [BUGFIX] Correctly pass 'false' config values to Rust agent

## 0.10.6 (August 10, 2016)

- [BUGFIX] Turn off -Werror and -pedantic for builds. [Issue #64](https://github.com/skylightio/skylight-ruby/issues/64)

## 0.10.5 (June 22, 2016)

- [BUGFIX] Fix issue with Grape multi-method naming
- [BUGFIX] Add http to proxy_url for native fetching
- [BUGFIX] Fix setting `proxy_url` in config YML
- [IMPROVEMENT] Log errors during authentication validation

## 0.10.4 (June 3, 2016)

- [BUGFIX] Sinatra instrumenation now works for latest master
- [BUGFIX] Sequel support for 4.35.0
- [BUGFIX] Handle latest ActiveModel::Serializers version
- [BUGFIX] More precise check for existence of Rails
- [BREAKING] Drop official support for Sinatra 1.2 (it likely never worked correctly)
- [IMPROVEMENT] On Heroku, logs are now written to STDOUT
- [IMPROVEMENT] Allow Skylight to raise on logged errors, useful for testing and debugging
- [IMPROVEMENT] Finish Rack::Responses in Middleware
- [IMRPOVEMENT] Better message when config/skylight.yml already exists
- [IMPROVEMENT] Update Rust Agent with SQL improvements, including handling for arrays and WITH

## 0.10.3 (February 2, 2016)

- [BUGFIX] Don't validate configuration on disabled environments.

## 0.10.2 (January 19, 2016)

- [BUGFIX] Fix git repository warning on startup. [Issue #58](https://github.com/skylightio/skylight-ruby/issues/58)

## 0.10.1 (January 4, 2016) [YANKED]

- [FEATURE] Preliminary work for deploy tracking (not yet functional)
- [BUGFIX] Don't crash if user config (~/.skylight) is empty
- [BUGFIX] Better handling of unsupported moped versions
- [IMPROVEMENT] Internal refactor of configuration handling
- [IMPROVEMENT] Improve automated tests
- [IMPROVEMENT] Fix tests in Rails 5 (No actual code changes required!)

## 0.10.0 (December 3, 2015)

- [FEATURE] ActiveModel::Serializers Instrumentation. Always on in latest HEAD, for previous version add 'active_model_serializers' to probes list.
- [BUGFIX] Handle multi-byte characters in SQL lexer

## 0.9.4 (November 23, 2015)

- [FEATURE] Added instrumentation for official Mongo Ruby Driver (utilized by Mongoid 5+). Add 'mongo' to probes list to enable.
- [BUGFIX] SQL lexer now handles indentifiers beginning with underscores.
- [BUGFIX] Excon instrumentation now works correctly.
- [BUGFIX] Graceful handling of native agent failures on old OS X versions.
- [IMPROVEMENT] Freeze some more strings for (likely very minor) performance improvements.
- [IMPROVEMENT] Better error messages when sockdir is an NFS mount.
- [IMPROVEMENT] On OS X, ensure that Xcode license has been approved before trying to build native agent.

## 0.9.3 (November 17, 2015)

- [BUGFIX] Update SQL lexer to handle more common queries
- [BUGFIX] Correctly report native gem installation failures

## 0.9.2 (November 13, 2015)

- [BUGFIX] Correctly update Rust agent to include SQL fixes that were supposed to land in 0.9.1.

## 0.9.1 (November 10, 2015)

- [BUGFIX] Update Rust SQL lexer to handle `NOT` and `::` typecasting.

## 0.9.0 (November 6, 2015)

- [FEATURE] Expose Skylight::Helpers.instrument_class_method
- [BUGFIX] Allow for instrumentation of setters
- [BUGFIX] Fix an issue where loading some items in the Grape namespace without loading the whole library would cause an exception.
- [IMPROVEMENT] Switch to Rust SQL lexer by default
- [IMPROVEMENT] Add support for Redis pipelined and multi
- [IMPROVEMENT] Updated Rust internals
- [IMPROVEMENT] Agent should now work on current Rails master
- [IMPROVEMENT] Better disabling of development mode warning

## 0.8.1 (October 1, 2015)

- [BUGFIX] Fix agent on OS X El Capitan.
- [PERFORMANCE] Explicitly subscribe to normalized events
- [IMPROVEMENT] Use native unique description tracking
- [IMPROVEMENT] Native SQL: Support multistatement queries

## 0.8.0 (August 13, 2015)

- [FEATURE] Add Grape instumentation. See https://docs.skylight.io/grape
- [FEATURE] Process ERB in config/skylight.yml
- [FEATURE] Add Rust based SQL lexing. Currently beta. Enable with `config.sql_mode = 'rust'`.
- [BUGFIX] Fixed a case where, With some logger configurations, duplicate messages could be written to STDOUT.

## 0.7.1 (August 4, 2015)

- [BUGFIX] Fix bug in FFI error handling

## 0.7.0 (August 3, 2015)

- [BUFIX] Condvar bug in Rust. Updated to latest nightly.
- [BUGFIX] Don't crash on ruby stack overflow
- [IMPROVEMENT] Silence a noisy log message
- [IMPROVEMENT] Update to latest openssl & curl
- [FEATURE] Add probe on ActionView for layout renders

## 0.6.1 (June 30, 2015)

- [BUGFIX] Don't use $DEBUG to enable verbose internal logging

## 0.6.0 (January 27, 2015)

- [IMPROVEMENT] Eliminates runtime dependency on the Rails
  constant across the entire codebase
- [FEATURE] Support for Sinatra applications. See https://docs.skylight.io/sinatra/
- [FEATURE] Support for the Sequel ORM (off by default for Rails apps)
- [FEATURE] Support for Tilt templates (off by default for Rails apps)

## 0.5.2 (December 15, 2014)

- [IMPROVEMENT] Support ignoring multiple heartbeat endpoints
- [BUGFIX] Fix compilation errors on old GCC

## 0.5.1 (December 5, 2014)

- [BUGFIX] Fix issues with working directory dissappearing

## 0.5.0 (December 4, 2014)

- [IMPROVEMENT] Automatically load configuration from ENV
- [FEATURE] Track object allocations per span
- [IMPROVEMENT] Fix C warnings

## 0.4.3 (November 17, 2014)

- [BUGFIX] Fix Moped integration when queries include times

## 0.4.2 (November 12, 2014)

- [BUGFIX] Fix exit status on MRI 1.9.2
- [BUGFIX] Strip SQL comments for better aggregation

## 0.4.1 (November 7, 2014)

- [BUGFIX] Fix downloading native agent on 32bit systems
- [BUGFIX] Support legacy config settings
- [FEATURE] Check FS permissions on instrumenter start

## 0.4.0 (November 3, 2014)

- Featherweight Agent: lowered CPU and memory overhead
- [IMPROVEMENT] Add support for ignoring an endpoint by name

## 0.3.21 (October 8, 2014)

- [BUGFIX] Skylight crashing on start won't crash entire app

## 0.3.20 (September 3, 2014)

- [BUGFIX] Fix app name fetching on Windows for `skylight setup`

## 0.3.19 (July 30, 2014)

- [IMPROVEMENT] HEAD requests are no longer instrumented and will not count towards usage totals.
- [IMPROVEMENT] Added LICENSE and CLA
- [IMPROVEMENT] Improve how warnings are logged to reduce overall noise and interfere less with cron jobs
- [BUGFIX] Fixed a case where failed app creation raised an exception instead of printing error messages

## 0.3.18 (July 17, 2014)

- [FEATURE] Redis probe (Not enabled by default. See https://docs.skylight.io/agent/#railtie)
- [FEATURE] Support app creation with token instead of email/password
- [BUGFIX] App creation now works even when Webmock is enabled
- [BUGFIX] Fix instrumentation for methods ending in special chars
- [BUGFIX] Improved SQL parsing
- [IMPROVEMENT] Respect collector token expiration to reduce token requests

## 0.3.17 (July 1, 2014)

- Fix warning for Cache.instrument overwrite

## 0.3.16 (July 1, 2014) [YANKED]

- Fixed ActiveSupport::Cache monkeypatch

## 0.3.15 (June 30, 2014) [YANKED]

- Basic instrumentation for ActiveSupport::Cache
- Fix incompatibility with old version of rack-mini-profiler
- Better error messages when config/skylight.yml is invalid
- Better error messages for non-writeable lock/sockfile path

## 0.3.14 (June 3, 2014)

- Do not build C extension if dependencies (libraries/headers) are
  missing
- [RUST] Improve performance by not double copying memory when serializing
- Enable the Net::HTTP probe by default

## 0.3.13 (May 12, 2014)

- Load probes even when agent is disabled
- Check for Excon::Middlewares before installing the probe
- SQL error encoder should not operate in-place
- Fix Middleware
- More debug logging
- Log Rails version in MetricsReporter
- Handle missing Net::ReadTimeout in 1.9.3
- Include original exception information in sql_parse errors
- Debugging for failed application creation
- Make double sure that Trace started_at is an Integer

## 0.3.12 (April 17, 2014)

- Include more information in type check errors
- Use stdlib SecureRandom instead of ActiveSupport::SecureRandom - Fixes Rails 3.1
- Instrumenter#start! should fail if worker not spawned
- Configurable timeouts for Util::HTTP
- Improve proxy handling for Util::HTTP
- Improve HTTP error handling
- Refactor sql_parse errors

## 0.3.11 (April 11, 2014)

- Improved error handling and internal metrics
- Improved missing native agent message
- Improved install logging
- Added initial inline docs
- Respects HTTP_PROXY env var during installation
- Don't overwrite sockfile_path if set explicitly

## 0.3.10 (April 8, 2014)

- Don't raise on missing native agent path

## 0.3.9 (April 8, 2014)

- Avoid finalizing sockets in the child process
- Fix non-displaying warnings around native agent
- Remove HTTP path information from title for better grouping

## 0.3.8 (April 3, 2014)

- Update vendored highline to 1.6.21
- Send more information with exceptions for easier debugging
- Instrument and report internal agent metrics for easier debugging
- Fix bug with tracking request counts per endpoint

## 0.3.7 (March 31, 2014)

- Use a default event category if none passed to Skylight.instrument
- Fix bugs around disabling the agent
- Fix native extension compilation bugs

## 0.3.6 (March 27, 2014)

- Shorter token validation timeout
- Allow validation to be skipped

## 0.3.5 (March 26, 2014)

- Update Rust component
- Return true from Task#handle to avoid sutdown
- Fix numeric check that caused crash on some 32-bit systems
- Improve error message for missing Skylight ext
- Better config error messages
- Validate authentication token before starting
- Add proxy support

## 0.3.4 (March 13, 2014)

- Don't try to boot Skylight without native agent
- Make exception classes always available
- CLI should require railtie before loading application.rb

## 0.3.3 (March 12, 2014)

- Load the railtie even without native agent

## 0.3.2 (March 11, 2014)

- Autoload Skylight:Helpers even when native agent isn't available
- Fix SEGV

## 0.3.1 (March 8, 2014)

- Fix requires to allow CLI to function without native extension.

## 0.3.0 (February 28, 2014)

- Native Rust agent
- Send exceptions occurring during HTTP requests to the client.
- Warn users when skylight is potentially disabled incorrectly.
- Update SQL Lexer to 0.0.6
- Log the backtraces of unhandled exceptions
- Add support for disabling GC tracking
- Add support for disabling agent

## 0.2.7 (February 26, 2014)

- Disable annotations to reduce memory load.

## 0.2.6 (February 25, 2014)

- `inspect` even whitelisted payload props
- Ignore Errno::EINTR for 'ps' call

## 0.2.5 (February 21, 2014)

- Revert "Update SqlLexer to 0.0.4"

## 0.2.4 (February 20, 2014)

- Whitelist process action annotation keys.
- Update SqlLexer to 0.0.4

## 0.2.3 (December 20, 2013)

- Fix SQL lexing for comments, arrays, double-colon casting, and multiple queries
- Handle template paths from gems
- Status and exception reports for agent debugging

## 0.2.2 (December 10, 2013)

- Added support for Mongoid/Moped
- Fix probe enabling
- Improved error reporting
- Fix bug with multiple subscribers to same notification

## 0.2.1 (December 4, 2013)

- Fix bin/skylight

## 0.2.0 (December 3, 2013)

- Added Probes, initially Net::HTTP and Excon
- Wide-ranging memory cleanup
- Better resiliance to binary and encoding errors
- Add support for disabling
- De-dupe rendering instrumentation better
- Fix send_file event to not spew a gazillion nodes
- Rails 3.0 compatibility
- Detailed SQL annotations

## 0.1.8 (July 19, 2013)

- Update agent for new authentication scheme
- Change ENV variable prefix from SK* to SKYLIGHT*

## 0.1.7 (July 11, 2013)

- Add instrument_method helper
- Add the ability to configure logging from railtie
- Tracks the current host
- [BUG] Handle AS::N monkey patching when there are already subscribers
- [BUG] Handle ruby 1.9.2 encoding bug

## 0.1.6 (June 11, 2013)

- [BUG] Fix unix domain socket write function in standalone agent
- Performance improvements
- Tolerate invalid trace building
- Fix Skylight on Rails 4

## 0.1.5 (May 31, 2013)

- Provide a default CA cert when one is not already present
- Expose Skylight.start! and Skylight.trace as APIs
- Expose Skylight.instrument as an API for custom instrumentation.

## 0.1.4 (May 30, 2013)

- [BUG] Fix some errors caused by floating point rounding
- [BUG] Handle clock skew caused by system clock changes

## 0.1.3 (May 29, 2013)

- [BUG] Require net/https and openssl
- [BUG] Rails' logger does not respond to #log. Use level methods
  instead

## 0.1.2 (May 29, 2013)

- [BUG] Disable GC profiling on JRuby

## 0.1.1 (May 29, 2013)

- [BUG] GC Profiling was not getting enabled

## 0.1.0 (May 24, 2013)

- Initial release
