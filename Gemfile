ENV["MOPED_VERSION"] = "skip"
ENV["MONGOID_VERSION"] = "skip"
ENV["TILT_VERSION"] = "~> 2.0"

eval_gemfile File.expand_path("gemfiles/Gemfile.base", __dir__)

gem "rails", "~> 5.1.0"
gem "sinatra", "~> 2.0.0"

group :development do
  gem "pry"
  gem "pry-byebug"
  gem "yard", "~> 0.9.11"
end
