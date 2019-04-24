ENV['MONGOID_VERSION'] = 'skip'
ENV['SQLITE_VERSION'] = '~> 1.4'

eval_gemfile File.expand_path('../Gemfile.base', __FILE__)
eval_gemfile File.expand_path('../Gemfile.rails-common', __FILE__)

gem 'rails', '~> 6.0.0.rc1'
