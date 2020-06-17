ENV["MONGOID_VERSION"] = "skip"
ENV["TILT_VERSION"] = "~> 2.0"

eval_gemfile File.expand_path("gemfiles/Gemfile.base", __dir__)

gem "rails", "~> 6.0.0"
gem "sinatra", "~> 2.0.0"

group :development do
  gem "pry"
  gem "yard", "~> 0.9.11"
  gem 'pry-byebug'
end
