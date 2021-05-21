module Skylight
  # pre-release versions should be given here as "5.0.0-alpha"
  # for compatibility with semver when it is parsed by the rust agent.
  # This string will be transformed in the gemspec to "5.0.0.alpha"
  # to conform with rubygems.
  VERSION = "5.1.0-beta3".freeze
end
