ENV["MONGOID_VERSION"] = "skip"
ENV["TILT_VERSION"] = "~> 2.0"

# Dependabot doesn't like interpolation here
eval_gemfile "./gemfiles/Gemfile.base"

gem "rails", "~> 6.1.3"
gem "sinatra", "~> 2.1.0"

group :development do
  gem "pry"
  gem "pry-byebug"
  gem "rubocop", "~> 1.11.0"
  gem "yard", "~> 0.9.26"
end
