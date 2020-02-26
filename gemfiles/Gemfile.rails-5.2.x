ENV['SQLITE_VERSION'] = '~> 1.3.13'

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)
eval_gemfile File.expand_path('../Gemfile.rails-common', __FILE__)

gem 'rails', '~> 5.2.0'
