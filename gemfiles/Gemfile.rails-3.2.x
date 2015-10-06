ENV["SKIP_MOPED"] = "true"

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)

gem 'rails', '~> 3.2.0'
gem 'rack-cache', '1.2' # 1.3 requires Ruby 2
gem 'i18n', '0.6.11'
