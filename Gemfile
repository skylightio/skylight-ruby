ENV["MONGOID_VERSION"] = "skip"
ENV["TILT_VERSION"] = "~> 2.0"

# Dependabot doesn't like interpolation here
eval_gemfile "./gemfiles/Gemfile.base"

gem "rails", "~> 6.0.0"
gem "sinatra", "~> 2.0.0"

group :development do
  gem "rubocop", "~> 0.90.0"
  gem "pry"
  gem "pry-byebug"
  gem "yard", "~> 0.9.11"
end
