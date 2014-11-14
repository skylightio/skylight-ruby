ENV["SKIP_MOPED"] = "true"

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)

gem 'rails', '~> 3.0.0'
